"""New-user setup preserves existing settings and uses fixed package commands."""

import importlib.util
from pathlib import Path
from types import SimpleNamespace

import pytest

SPEC = importlib.util.spec_from_file_location("music_setup", Path(__file__).parents[1] / "contents/code/music_setup.py")
setup = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(setup)


@pytest.fixture
def fresh_setup(tmp_path, monkeypatch):
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path / "config"))
    monkeypatch.setenv("XDG_DATA_HOME", str(tmp_path / "data"))
    monkeypatch.delenv("MPD_HOST", raising=False)
    monkeypatch.delenv("MPD_PORT", raising=False)
    monkeypatch.setattr(Path, "home", lambda: tmp_path)

    class Failed(Exception):
        pass

    def down():
        raise Failed("not running")

    fake = SimpleNamespace(
        Failed=Failed, status=down, run=lambda args: (0, "Output plugins:\n pipewire pulse\nEncoder plugins:\n", "")
    )
    monkeypatch.setattr(setup, "backend", lambda: fake)
    return tmp_path, fake


def test_mpd_config_local_desktop_and_escaped_folder(fresh_setup):
    root, _ = fresh_setup
    music = root / 'my "music"'
    music.mkdir()
    setup.configure_mpd(str(music))
    config = root / "config/mpd/mpd.conf"
    text = config.read_text()
    assert 'bind_to_address "127.0.0.1"' in text
    assert 'type "pipewire"' in text
    assert r"my \"music\"" in text
    assert config.stat().st_mode & 0o777 == 0o600
    assert (root / "data/mpd/playlists").is_dir()


def test_existing_mpd_untouched(fresh_setup):
    root, _ = fresh_setup
    config = root / "config/mpd/mpd.conf"
    config.parent.mkdir(parents=True)
    config.write_text("existing settings")
    setup.configure_mpd("/invalid/folder")
    assert config.read_text() == "existing settings"


def test_old_mpd_config_untouched(fresh_setup):
    root, _ = fresh_setup
    (root / ".mpdconf").write_text("older configuration")
    setup.configure_mpd("/invalid/folder")
    assert not (root / "config/mpd/mpd.conf").exists()


def test_remote_override_not_replaced(fresh_setup, monkeypatch):
    root, _ = fresh_setup
    monkeypatch.setenv("MPD_HOST", "remote.example")
    with pytest.raises(ValueError, match="MPD_HOST"):
        setup.configure_mpd(str(root))
    assert not (root / "config/mpd/mpd.conf").exists()


def test_existing_server_not_duplicated(fresh_setup):
    root, fake = fresh_setup
    fake.status = lambda: {"state": "stop"}
    with pytest.raises(ValueError, match="already running"):
        setup.configure_mpd(str(root))


def test_missing_folder_rejected(fresh_setup):
    root, _ = fresh_setup
    with pytest.raises(ValueError, match="readable"):
        setup.configure_mpd(str(root / "missing"))


def test_rmpc_config_generated_and_preserved(fresh_setup, monkeypatch):
    root, fake = fresh_setup
    monkeypatch.setattr(setup.shutil, "which", lambda name: "/usr/bin/" + name)
    fake.run = lambda args: (0, '(address: "127.0.0.1:6600",)\n', "")
    setup.configure_rmpc()
    config = root / "config/rmpc/config.ron"
    old = config.read_text()
    fake.run = lambda args: (0, "new defaults", "")
    setup.configure_rmpc()
    assert config.read_text() == old


def test_failed_rmpc_generation_creates_nothing(fresh_setup, monkeypatch):
    root, fake = fresh_setup
    monkeypatch.setattr(setup.shutil, "which", lambda name: "/usr/bin/" + name)
    fake.run = lambda args: (1, "", "failed")
    with pytest.raises(ValueError, match="generate"):
        setup.configure_rmpc()
    assert not (root / "config/rmpc/config.ron").exists()


def test_installer_fixed_packages_includes_cava(monkeypatch):
    monkeypatch.setattr(setup, "arch_supported", lambda: True)
    calls = []
    monkeypatch.setattr(setup.subprocess, "run", lambda args, **kwargs: calls.append(args))
    setup.install("extras")
    assert calls == [["sudo", "pacman", "-S", "--needed", "--", "qmltermwidget", "cava"]]


def test_unsupported_distro_never_installs(monkeypatch):
    monkeypatch.setattr(setup, "arch_supported", lambda: False)
    with pytest.raises(ValueError, match="Arch"):
        setup.install("mpd")


def test_control_characters_cannot_inject_config():
    with pytest.raises(ValueError, match="control"):
        setup.mpd_quote('/music\nport "9999"')
