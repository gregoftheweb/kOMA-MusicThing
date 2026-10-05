"""Load komamusic as a module, and a fake MPD server speaking the real protocol.

FakeMPD listens on a free localhost port, answers the commands komamusic uses
from an in-memory player state, and records every command, so play/pause/next
are tested end to end without touching a real MPD (or your speakers).
"""

import importlib.machinery
import importlib.util
import socket
import threading
from pathlib import Path

import pytest

CLI = Path(__file__).resolve().parents[1] / "contents" / "code" / "komamusic"


class FakeMPD:
    def __init__(self, password=None):
        self.password = password
        self.commands = []
        self.state = "pause"
        self.song = 1
        self.queue = [
            {
                "file": "N/Neil Diamond/01 - Solitary Man.mp3",
                "Title": "Solitary Man",
                "Artist": "Neil Diamond",
                "Album": "50",
                "Time": "153",
            },
            {"file": "B/Beatles/Help.flac", "Title": "Help!", "Artist": "The Beatles", "Album": "Help!", "Time": "138"},
            {"file": "untagged/track 07.mp3", "Time": "200"},
        ]
        self.server = socket.socket()
        self.server.bind(("127.0.0.1", 0))
        self.server.listen()
        self.port = self.server.getsockname()[1]
        threading.Thread(target=self.serve, daemon=True).start()

    def serve(self):
        while True:
            try:
                conn, _ = self.server.accept()
            except OSError:
                return
            threading.Thread(target=self.handle, args=(conn,), daemon=True).start()

    def handle(self, conn):
        f = conn.makefile("rwb")
        f.write(b"OK MPD 0.24.0\n")
        f.flush()
        authed = self.password is None
        for raw in f:
            line = raw.decode().strip()
            self.commands.append(line)
            name, _, arg = line.partition(" ")
            arg = arg.strip('"')
            if name == "password":
                if arg == self.password:
                    authed = True
                    f.write(b"OK\n")
                else:
                    f.write(b"ACK [3@0] {password} incorrect password\n")
                f.flush()
                continue
            if not authed:
                f.write(b'ACK [4@0] {status} you don\'t have permission for "status"\n')
                f.flush()
                continue
            out = self.reply(name, arg)
            f.write(out.encode() + b"OK\n")
            f.flush()
        conn.close()

    def reply(self, name, arg):
        if name == "status":
            s = ["volume: 100", f"state: {self.state}", f"playlistlength: {len(self.queue)}"]
            if self.queue and self.state != "stop":
                s += [f"song: {self.song}", "elapsed: 44.870", f"duration: {self.queue[self.song]['Time']}.0"]
            return "".join(x + "\n" for x in s)
        if name == "currentsong":
            if not self.queue or self.state == "stop":
                return ""
            return "".join(f"{k}: {v}\n" for k, v in self.queue[self.song].items())
        if name == "play":
            self.state = "play"
        elif name == "pause":
            self.state = "pause" if arg == "1" else "play"
        elif name == "next":
            self.song = min(self.song + 1, len(self.queue) - 1)
        elif name == "previous":
            self.song = max(self.song - 1, 0)
        return ""

    def close(self):
        self.server.close()


@pytest.fixture
def mpd(monkeypatch):
    fake = FakeMPD()
    monkeypatch.setenv("MPD_HOST", "127.0.0.1")
    monkeypatch.setenv("MPD_PORT", str(fake.port))
    yield fake
    fake.close()


@pytest.fixture
def music():
    loader = importlib.machinery.SourceFileLoader("komamusic", str(CLI))
    spec = importlib.util.spec_from_loader("komamusic", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod
