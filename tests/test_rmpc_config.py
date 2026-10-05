"""rmpc for the panel: the user's config with album art off."""

USER_CONFIG = """#![enable(implicit_some)]
(
    address: "127.0.0.1:6600",
    album_art: (
        method: Sixel,
        max_size_px: (width: 1200, height: 1200),
    ),
    keybinds: (global: {".": VolumeUp}),
)
"""


def test_album_art_method_becomes_none(music):
    out = music.without_album_art(USER_CONFIG)
    assert "method: None," in out
    assert "Sixel" not in out
    assert 'keybinds: (global: {".": VolumeUp})' in out  # everything else untouched
    assert "max_size_px: (width: 1200, height: 1200)" in out


def test_kitty_and_auto_too(music):
    for method in ("Kitty", "Auto", "Iterm2", "Block"):
        assert "method: None" in music.without_album_art(USER_CONFIG.replace("Sixel", method))


def test_config_without_album_art_gets_one(music):
    out = music.without_album_art('#![enable(implicit_some)]\n(\n    address: "x",\n)\n')
    assert out.startswith("#![enable(implicit_some)]\n(\n    album_art: (method: None),")


def test_panel_config_is_written_to_the_cache(music, tmp_path):
    (tmp_path / "cfg/rmpc").mkdir(parents=True)
    (tmp_path / "cfg/rmpc/config.ron").write_text(USER_CONFIG)
    env = {"XDG_CONFIG_HOME": str(tmp_path / "cfg"), "XDG_CACHE_HOME": str(tmp_path / "cache")}
    dest = music.panel_rmpc_config(env)
    assert dest == tmp_path / "cache/komamusicthing/rmpc.ron"
    assert "method: None" in dest.read_text()
    assert "Sixel" in (tmp_path / "cfg/rmpc/config.ron").read_text()  # the user's config is never changed


def test_no_user_config_starts_from_rmpcs_defaults(music, tmp_path, monkeypatch):
    monkeypatch.setattr(music, "run", lambda cmd, timeout=15: (0, "(\n    album_art: (method: Auto),\n)\n", ""))
    env = {"XDG_CONFIG_HOME": str(tmp_path / "none"), "XDG_CACHE_HOME": str(tmp_path / "cache")}
    assert "method: None" in music.panel_rmpc_config(env).read_text()


def test_stop(music, mpd):
    mpd.state = "play"
    assert music.control("stop") is not None
    assert "stop" in mpd.commands


LAYOUT = """(
    album_art: (method: Sixel),
    tabs: [(name: "Queue", pane: Split(panes: [
        (size: "100%", pane: Pane(AlbumArt)),
        (size: "7", pane: Pane(Lyrics)),
    ]))],
)
"""


def test_cava_takes_album_arts_place(music):
    out = music.panel_layout(LAYOUT, has_cava=True)
    assert "Pane(Cava)" in out
    assert "Pane(AlbumArt)" not in out
    assert "Pane(Lyrics)" in out
    assert "method: None" in out


def test_without_cava_the_space_is_left_empty(music):
    out = music.panel_layout(LAYOUT, has_cava=False)
    assert "Pane(Empty())" in out
    assert "Cava" not in out
