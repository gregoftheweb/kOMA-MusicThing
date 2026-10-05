"""Starting and stopping MPD, the way the rmpcs script does."""

import pytest


class Calls:
    def __init__(self, rc=0, err=""):
        self.cmds, self.rc, self.err = [], rc, err

    def __call__(self, cmd, timeout=15):
        self.cmds.append(tuple(cmd))
        return self.rc, "", self.err


def test_already_running_is_left_alone(music, mpd, monkeypatch):
    calls = Calls()
    monkeypatch.setattr(music, "run", calls)
    assert music.start_mpd() == {"started": False}
    assert calls.cmds == []


def test_starts_the_service_and_waits_for_it(music, monkeypatch):
    from conftest import FakeMPD

    calls = Calls()
    monkeypatch.setattr(music, "run", calls)
    monkeypatch.setenv("MPD_HOST", "127.0.0.1")
    monkeypatch.setenv("MPD_PORT", "1")  # down until the service "starts"
    started = {}

    def fake_sleep(_):
        if "mpd" not in started:  # MPD comes up a moment after systemctl returns
            started["mpd"] = FakeMPD()
            monkeypatch.setenv("MPD_PORT", str(started["mpd"].port))

    assert music.start_mpd(sleep=fake_sleep) == {"started": True}
    assert calls.cmds == [("systemctl", "--user", "start", "mpd.service")]
    started["mpd"].close()


def test_gives_up_when_mpd_never_answers(music, monkeypatch):
    monkeypatch.setattr(music, "run", Calls())
    monkeypatch.setenv("MPD_HOST", "127.0.0.1")
    monkeypatch.setenv("MPD_PORT", "1")
    t = [0.0]

    def clock():
        return t[0]

    def sleep(s):
        t[0] += s

    with pytest.raises(music.Failed, match="isn't answering"):
        music.start_mpd(sleep=sleep, clock=clock)


def test_reports_a_failing_service(music, monkeypatch):
    monkeypatch.setattr(music, "run", Calls(rc=5, err="Unit mpd.service not found."))
    monkeypatch.setenv("MPD_HOST", "127.0.0.1")
    monkeypatch.setenv("MPD_PORT", "1")
    with pytest.raises(music.Failed, match="Unit mpd.service not found"):
        music.start_mpd()


def test_stop(music, monkeypatch):
    calls = Calls()
    monkeypatch.setattr(music, "run", calls)
    assert music.stop_mpd() == {"stopped": True}
    assert calls.cmds == [("systemctl", "--user", "stop", "mpd.service")]
