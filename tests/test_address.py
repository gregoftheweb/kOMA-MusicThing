"""Finding MPD: MPD_HOST / MPD_PORT, then rmpc's config, then localhost:6600."""


def test_defaults(music):
    assert music.server(env={}, rmpc_config="") == ("localhost", 6600, None)


def test_rmpc_config_address(music):
    cfg = '(\n    address: "127.0.0.1:6601",\n    password: None,\n)'
    assert music.server(env={}, rmpc_config=cfg) == ("127.0.0.1", 6601, None)


def test_mpd_host_wins_and_can_carry_a_password(music):
    env = {"MPD_HOST": "secret@music.lan", "MPD_PORT": "6602"}
    assert music.server(env=env, rmpc_config='address: "127.0.0.1:6601"') == ("music.lan", 6602, "secret")


def test_socket_paths(music):
    host, port, _ = music.parse_address("~/.local/run/mpd.sock")
    assert host.endswith("/.local/run/mpd.sock") and port is None


def test_host_without_port(music):
    assert music.parse_address("music.lan") == ("music.lan", 6600, None)
