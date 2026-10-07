# Changelog

All notable changes to kOMA Music Thing. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org/).

## [0.3.0] - 2026-10-07

### Changed

- While the popup is closed, the widget waits for MPD to report a change (`komamusic wait`, MPD's `idle`) instead of asking for status every 5 seconds. Hovering the icon refreshes the tooltip's elapsed time.

### Added

- `komamusic wait [--timeout SECONDS] [--json]`: block until playback, volume, the queue, or playback options change.

### Fixed

- plasmashell no longer slows down the longer it runs. Commands ran under a new name every time (`cmd # Date.now()`), and Plasma's command engine never forgets a name: every widget's command runner on the engine rebuilds a property for each name ever used on every removal, so CPU and memory grew all day until plasmashell pinned a core. Commands now keep one fixed name and run through the shared `CommandQueue`, which serializes repeat runs of the same command.

## [0.2.1] - 2026-10-06

### Changed

- Every panel opening starts in the mini player. Only expanding starts the embedded browser.
- Closing, collapsing, or entering setup releases the browser and visualizer without stopping MPD playback.
- Remember the last browser tab for the next expansion using bounded, PID-targeted rmpc remote commands; no background bookmark polling.

### Fixed

- Allow only one recurring MPD status request at a time, so a slow server cannot accumulate polling processes and callbacks.
- Ignore status responses made stale by playback controls and refresh the final server state after controls finish.
- Add QML regression tests for slow polling, failures, and responses completing out of order.

## [0.2.0] - 2026-10-05

### Added

- Guided Setup panel with installation buttons for MPD, rmpc, cava, and the embedded terminal on Arch-based systems.
- Music-folder picker, non-destructive MPD and rmpc configuration, desktop audio selection, and a start-and-scan step.
- Existing and remote MPD setups are preserved. New configuration files are private and never replace existing files.
- Setup tests covering configuration preservation, missing dependencies, fixed package commands, and the QML setup panel.

## [0.1.0] - 2026-10-04

### Added

- Panel icon showing MPD's state (hover for what's playing; middle-click plays/pauses, scroll skips).
- Mini view: title, artist and album, progress, play/pause, skip, and an expand button.
- Full view: [rmpc](https://github.com/mierak/rmpc) running inside the popup in a real terminal (QMLTermWidget), to pick music and build the queue. Collapsing only hides it, so rmpc keeps its place; quitting rmpc (`q`) collapses the popup.
- Start rmpc: when MPD isn't running, one button starts `mpd.service`, waits for MPD, and opens rmpc. If the widget started MPD, quitting rmpc stops it again (the same lifecycle as the `rmpcs` script). An MPD started elsewhere is never stopped.
- Without QMLTermWidget, the full view offers rmpc in a terminal window instead.
- rmpc in the popup runs with a copy of the user's config, regenerated on every start: album art off (the terminal can't draw Sixel/Kitty images) and the Cava visualizer in its place, capturing PipeWire's (or PulseAudio's) default output: rmpc's default cava input is PulseAudio with an empty source, which cava rejects. A `cava` section in the user's config is left as is. The user's own config and standalone rmpc are untouched.
- `komamusic doctor` reports the dependencies (rmpc, mpd and mpd.service, QMLTermWidget, cava); `bin/install` offers to install missing ones with pacman.
- `komamusic` CLI: `status`, `toggle`, `play`, `pause`, `next`, `prev`, `start-mpd`, `stop-mpd`; a stdlib MPD protocol client (TCP or socket, optional password) that finds MPD like rmpc does.
- Tests (pytest against a fake MPD server speaking the real protocol, QML unit tests), linting and formatting gates (`make check`), pre-commit hook, `make package`.

[0.1.0]: https://github.com/gregoftheweb/kOMA-MusicThing/releases/tag/v0.1.0
