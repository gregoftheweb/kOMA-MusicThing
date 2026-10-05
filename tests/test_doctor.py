"""komamusic doctor: what's installed, what's missing, which packages."""


def test_everything_present(music, tmp_path, monkeypatch):
    (tmp_path / "QMLTermWidget").mkdir()
    (tmp_path / "QMLTermWidget/qmldir").write_text("module QMLTermWidget\n")
    monkeypatch.setattr(music, "run", lambda cmd, timeout=15: (0, "", ""))
    report = music.doctor(which=lambda name: f"/usr/bin/{name}", env={"QML_IMPORT_PATH": str(tmp_path)})
    assert all(d["ok"] for d in report)
    assert music.missing_packages(report) == []


def test_reports_missing_packages_once(music, tmp_path, monkeypatch):
    monkeypatch.setattr(music, "run", lambda cmd, timeout=15: (1, "", "No files found for mpd.service."))
    monkeypatch.setattr(music, "qml_module_dirs", lambda env=None: [tmp_path])
    report = music.doctor(which=lambda name: None)
    assert music.missing_packages(report) == ["cava", "mpd", "qmltermwidget", "rmpc"]  # mpd counted once
    required = {d["name"] for d in report if d["required"]}
    assert required == {"rmpc", "mpd", "mpd.service"}  # terminal and visualizer are optional


def test_optional_only_missing(music, tmp_path, monkeypatch):
    monkeypatch.setattr(music, "run", lambda cmd, timeout=15: (0, "", ""))
    monkeypatch.setattr(music, "qml_module_dirs", lambda env=None: [tmp_path])
    report = music.doctor(which=lambda name: None if name == "cava" else f"/usr/bin/{name}")
    assert music.missing_packages(report) == ["cava", "qmltermwidget"]
    assert all(d["ok"] for d in report if d["required"])
