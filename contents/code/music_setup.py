"""Guided dependency installation and non-destructive local MPD setup."""

import argparse
import functools
import importlib.machinery
import importlib.util
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


@functools.lru_cache(maxsize=1)
def backend():
    loader = importlib.machinery.SourceFileLoader("komamusic_setup_backend", str(Path(__file__).with_name("komamusic")))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


def config_home():
    return Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")


def arch_supported():
    release = Path("/etc/os-release").read_text()
    values = dict(line.split("=", 1) for line in release.splitlines() if "=" in line)
    ids = (values.get("ID", "") + " " + values.get("ID_LIKE", "")).replace('"', "").split()
    return "arch" in ids and shutil.which("pacman") is not None


def inspect_setup():
    mod = backend()
    conf = config_home()
    report = mod.doctor()
    connected = False
    try:
        mod.status()
        connected = True
    except mod.Failed:
        pass
    music = Path.home() / "Music"
    rc, out, _ = mod.run(["xdg-user-dir", "MUSIC"])
    if rc == 0 and out.strip():
        music = Path(out.strip())
    return {
        "dependencies": report,
        "installSupported": arch_supported(),
        "mpdConfigured": (conf / "mpd/mpd.conf").is_file() or (Path.home() / ".mpdconf").is_file(),
        "rmpcConfigured": (conf / "rmpc/config.ron").is_file(),
        "connected": connected,
        "musicFolder": str(music),
        "environmentOverride": bool(os.environ.get("MPD_HOST") or os.environ.get("MPD_PORT")),
    }


def mpd_quote(value):
    if any(ord(c) < 32 for c in str(value)):
        raise ValueError("Folder names must not contain control characters.")
    return '"' + str(value).replace("\\", "\\\\").replace('"', '\\"') + '"'


def create_file(path, text):
    """Create a new private config; never truncate an existing one."""
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except FileExistsError:
        return False
    with os.fdopen(fd, "w") as dest:
        dest.write(text)
    return True


def configure_mpd(music_folder):
    conf = config_home()
    path = conf / "mpd/mpd.conf"
    if path.exists() or (Path.home() / ".mpdconf").exists():
        return {"message": "Existing MPD configuration kept. Use Check connection to verify it."}
    if os.environ.get("MPD_HOST") or os.environ.get("MPD_PORT"):
        raise ValueError(
            "MPD_HOST or MPD_PORT selects an existing server. Clear that override before setting up local MPD."
        )
    folder = Path(music_folder).expanduser().resolve()
    if not folder.is_dir() or not os.access(folder, os.R_OK | os.X_OK):
        raise ValueError("Choose an existing, readable music folder.")
    # Do not create a competing local server when MPD is already reachable.
    try:
        backend().status()
    except backend().Failed:
        pass
    else:
        raise ValueError(
            "An MPD server is already running. Its setup has been kept; configure rmpc or check the connection."
        )
    mod = backend()
    rc, version, err = mod.run(["mpd", "--version"])
    if rc:
        raise ValueError("Install MPD first: " + err.strip())
    plugins = version.split("Output plugins:", 1)[-1].split("Encoder plugins:", 1)[0].split()
    output = "pipewire" if "pipewire" in plugins else "pulse" if "pulse" in plugins else None
    if not output:
        raise ValueError("This MPD build needs a PipeWire or PulseAudio output plugin for desktop playback.")
    data = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share") / "mpd"
    data.mkdir(parents=True, exist_ok=True)
    (data / "playlists").mkdir(exist_ok=True)
    text = "# Created by kOMA Music Thing guided setup\n"
    for key, value in [
        ("music_directory", folder),
        ("playlist_directory", data / "playlists"),
        ("db_file", data / "database"),
        ("state_file", data / "state"),
        ("sticker_file", data / "stickers"),
        ("bind_to_address", "127.0.0.1"),
    ]:
        text += f"{key} {mpd_quote(value)}\n"
    text += f'port "6600"\nauto_update "yes"\naudio_output {{\n    type "{output}"\n    name "Desktop audio"\n}}\n'
    created = create_file(path, text)
    return {"message": "MPD configured for " + str(folder) if created else "Existing MPD configuration kept."}


def configure_rmpc():
    path = config_home() / "rmpc/config.ron"
    if path.exists():
        return {"message": "Existing rmpc configuration kept."}
    mod = backend()
    if not shutil.which("rmpc"):
        raise ValueError("Install rmpc first.")
    rc, text, err = mod.run(["rmpc", "config"])
    if rc or not text.strip():
        raise ValueError("Could not generate rmpc configuration: " + err.strip())
    # Start with rmpc's own version-matched defaults. Environment overrides still take precedence.
    created = create_file(path, text)
    return {
        "message": "rmpc configured using its installed defaults." if created else "Existing rmpc configuration kept."
    }


def install(component):
    if not arch_supported():
        raise ValueError(
            "Automatic installation supports Arch-based systems. "
            "Install dependencies through your distribution, then return here."
        )
    packages = {"mpd": ["mpd"], "rmpc": ["rmpc"], "extras": ["qmltermwidget", "cava"]}[component]
    subprocess.run(["sudo", "pacman", "-S", "--needed", "--", *packages], check=True)
    return {"message": "Installation finished. Return to Music Thing and refresh setup."}


def verify():
    mod = backend()
    if not shutil.which("rmpc"):
        raise ValueError("Install rmpc before completing setup.")
    result = mod.start_mpd()
    client = mod.connect()
    try:
        client.command("update")
        stats = client.command("stats")
    finally:
        client.close()
    return {
        "started": result["started"],
        "message": "MPD connected. Library scan requested; "
        + stats.get("songs", "0")
        + " songs currently indexed. Open rmpc to choose music.",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    sub.add_parser("status")
    cmd = sub.add_parser("install")
    cmd.add_argument("component", choices=["mpd", "rmpc", "extras"])
    cmd = sub.add_parser("configure-mpd")
    cmd.add_argument("folder")
    sub.add_parser("configure-rmpc")
    sub.add_parser("verify")
    args = parser.parse_args()
    try:
        if args.action == "status":
            result = inspect_setup()
        elif args.action == "install":
            result = install(args.component)
        elif args.action == "configure-mpd":
            result = configure_mpd(args.folder)
        elif args.action == "configure-rmpc":
            result = configure_rmpc()
        else:
            result = verify()
        print(json.dumps(result))
    except (ValueError, OSError, subprocess.SubprocessError, backend().Failed) as exc:
        print(json.dumps({"error": str(exc)}))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
