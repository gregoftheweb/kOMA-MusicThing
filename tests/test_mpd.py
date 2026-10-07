"""Status and transport controls against a fake MPD server."""

import threading

import pytest


def test_status_reports_now_playing(music, mpd):
    s = music.status()
    assert (s["state"], s["title"], s["artist"]) == ("pause", "Help!", "The Beatles")
    assert (s["position"], s["queueLength"]) == (2, 3)
    assert s["elapsed"] == pytest.approx(44.87)
    assert s["duration"] == 138.0


def test_untagged_files_show_their_name(music, mpd):
    mpd.song = 2
    assert music.status()["title"] == "track 07"


def test_toggle_resumes_then_pauses(music, mpd):
    assert music.control("toggle")["state"] == "play"
    assert 'pause "0"' in mpd.commands
    assert music.control("toggle")["state"] == "pause"
    assert 'pause "1"' in mpd.commands


def test_toggle_from_stop_plays(music, mpd):
    mpd.state = "stop"
    assert music.control("toggle")["state"] == "play"
    assert "play" in mpd.commands


def test_toggle_with_an_empty_queue_explains(music, mpd):
    mpd.queue, mpd.state = [], "stop"
    with pytest.raises(music.Failed, match="queue is empty"):
        music.control("toggle")


def test_next_and_prev(music, mpd):
    mpd.song = 0
    assert music.control("next")["title"] == "Help!"
    assert music.control("prev")["title"] == "Solitary Man"


def test_unreachable_mpd_is_a_clear_error(music, monkeypatch):
    monkeypatch.setenv("MPD_HOST", "127.0.0.1")
    monkeypatch.setenv("MPD_PORT", "1")  # nothing listens there
    with pytest.raises(music.Failed, match="can't reach MPD at 127.0.0.1:1"):
        music.status()


def test_password_is_sent_and_checked(music, monkeypatch):
    from conftest import FakeMPD

    fake = FakeMPD(password="hunter2")
    monkeypatch.setenv("MPD_PORT", str(fake.port))
    monkeypatch.setenv("MPD_HOST", "hunter2@127.0.0.1")
    assert music.status()["title"] == "Help!"
    monkeypatch.setenv("MPD_HOST", "wrong@127.0.0.1")
    with pytest.raises(music.Failed, match="incorrect password"):
        music.status()
    fake.close()


def test_arguments_are_quoted(music, mpd):
    m = music.connect()
    m.command("find", 'title "quoted"', "back\\slash")
    m.close()
    assert mpd.commands[-1] == 'find "title \\"quoted\\"" "back\\\\slash"'


def test_wait_returns_when_playback_changes(music, mpd):
    waiting = threading.Timer(0.2, music.control, args=("next",))
    waiting.start()
    assert music.wait(timeout=3) == "player"
    assert 'idle "player" "mixer" "playlist" "options"' in mpd.commands


def test_wait_times_out_quietly(music, mpd):
    assert music.wait(timeout=0.2) is None
