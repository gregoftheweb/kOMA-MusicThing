# kOMA Music Thing

**A tiny MPD player for your panel, with [rmpc](https://github.com/mierak/rmpc) inside it.** Play and skip from a compact view; expand it and rmpc runs right in the popup to pick music and build the queue; collapse it and you're back to play and skip.

It's part of kOMA (KDE + Omarchy), a set of add-ons that make Plasma look and drive like Omarchy, and uses your Plasma theme throughout.

## Features

- **Panel icon** shows whether MPD is playing; hover for the song, middle-click to play/pause, scroll to skip.
- **Mini view**: title, artist, album, progress, play/pause, skip, expand.
- **rmpc inside the popup**: a real terminal (QMLTermWidget) in the expanded view. Collapsing hides it without stopping it, so rmpc keeps its place. Quit rmpc with `q` and the popup collapses.
- **Start rmpc**: if MPD isn't running, the widget shows one button that starts `mpd.service`, waits for MPD and opens rmpc. If the widget started MPD, quitting rmpc stops it again; an MPD you started yourself is left alone.

## Requirements

- KDE Plasma 6
- [MPD](https://www.musicpd.org) with a `mpd.service` systemd user unit, and [rmpc](https://github.com/mierak/rmpc)
- [QMLTermWidget](https://github.com/Swordfish90/qmltermwidget) 2.x for rmpc inside the popup (Arch: `qmltermwidget`). Without it, the expanded view opens rmpc in a terminal window instead.
- Python 3.11 or newer (standard library only)

kOMA Music Thing finds MPD the way rmpc does: `MPD_HOST` / `MPD_PORT` (`MPD_HOST` may be `password@host` or a socket path), then `address` in `~/.config/rmpc/config.ron`, then `localhost:6600`.

## Install

From the KDE Store: right-click the panel, **Add or Manage Widgets**, **Get New Widgets**, and search for "kOMA Music Thing".

From source:

```sh
git clone https://github.com/columbiafoundry/kOMA-MusicThing
cd kOMA-MusicThing
bin/install              # the widget, the komamusic command in ~/.local/bin, and places it on your panels
bin/install --no-place   # the same, without touching your panels
```

## Command line

```text
komamusic status [--json]        now playing
komamusic toggle | play | pause | next | prev
komamusic start-mpd              start mpd.service if MPD isn't answering, and wait for it
komamusic stop-mpd
```

## Development

```sh
make setup      # pytest + ruff in .venv, prettier + shellcheck in node_modules, git hook
make check      # ruff, qmllint, qmlformat, prettier, shellcheck, metadata, Python and QML tests
make format     # apply every formatter
make package    # dist/com.columbiafoundry.komamusicthing-<version>.plasmoid for the KDE Store
bin/dev-reload  # reinstall and restart plasmashell
```

`make check` needs QMLTermWidget installed, so `qmllint` can check `Terminal.qml`.

## License

MIT © 2026 Columbia Foundry. See [LICENSE](LICENSE).
