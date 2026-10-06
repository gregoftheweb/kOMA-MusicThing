"""Bookmarks target one client and never send playback commands."""

import subprocess
from types import SimpleNamespace

import pytest


def test_capture_targets_pid_and_returns_only_tab(music, monkeypatch):
    calls = []

    def remote(args, **kwargs):
        calls.append((args, kwargs))
        return SimpleNamespace(returncode=0, stdout='{"activetab":"Artists"}')

    monkeypatch.setattr(music.subprocess, "run", remote)
    assert music.browser_tab(123) == {"activetab": "Artists"}
    assert calls == [
        (
            ["rmpc", "remote", "--pid", "123", "query", "activetab"],
            {"capture_output": True, "text": True, "timeout": 0.4, "check": False},
        )
    ]


def test_restore_retries_startup_then_switches_only_tab(music, monkeypatch):
    calls = []
    monkeypatch.setattr(music.time, "sleep", lambda _: None)

    def remote(args, **kwargs):
        calls.append(args)
        return SimpleNamespace(returncode=1 if len(calls) == 1 else 0, stdout="")

    monkeypatch.setattr(music.subprocess, "run", remote)
    assert music.browser_tab(456, "Albums") == {}
    assert calls == [["rmpc", "remote", "--pid", "456", "switchtab", "Albums"]] * 2


@pytest.mark.parametrize("output", ["invalid json", "{}", "[]", '{"activetab":42}'])
def test_bad_query_is_a_bounded_failure(music, monkeypatch, output):
    monkeypatch.setattr(music.subprocess, "run", lambda *a, **k: SimpleNamespace(returncode=0, stdout=output))
    with pytest.raises(music.Failed):
        music.browser_tab(123)


def test_capture_timeout_does_not_retry(music, monkeypatch):
    calls = []

    def remote(args, **kwargs):
        calls.append(args)
        raise subprocess.TimeoutExpired(args, kwargs["timeout"])

    monkeypatch.setattr(music.subprocess, "run", remote)
    with pytest.raises(music.Failed):
        music.browser_tab(123)
    assert len(calls) == 1


def test_restore_deadline_stops_retrying(music, monkeypatch):
    times = iter([0, 3])
    monkeypatch.setattr(music.time, "monotonic", lambda: next(times))
    monkeypatch.setattr(music.subprocess, "run", lambda *a, **k: SimpleNamespace(returncode=1, stdout=""))
    with pytest.raises(music.Failed):
        music.browser_tab(123, "Queue")


def test_invalid_pid_never_targets_other_clients(music):
    with pytest.raises(music.Failed):
        music.browser_tab(0)
