# Changelog

All notable changes to kOMA Music Thing. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-10-04

### Added

- Panel icon showing MPD's state (hover for what's playing; middle-click plays/pauses, scroll skips).
- Mini view: title, artist and album, progress, play/pause, skip, and an expand button.
- Full view: [rmpc](https://github.com/mierak/rmpc) running inside the popup in a real terminal (QMLTermWidget), to pick music and build the queue. Collapsing only hides it, so rmpc keeps its place; quitting rmpc (`q`) collapses the popup.
- Start rmpc: when MPD isn't running, one button starts `mpd.service`, waits for MPD, and opens rmpc. If the widget started MPD, quitting rmpc stops it again (the same lifecycle as the `rmpcs` script). An MPD started elsewhere is never stopped.
- Without QMLTermWidget, the full view offers rmpc in a terminal window instead.
- `komamusic` CLI: `status`, `toggle`, `play`, `pause`, `next`, `prev`, `start-mpd`, `stop-mpd`; a stdlib MPD protocol client (TCP or socket, optional password) that finds MPD like rmpc does.
- Tests (pytest against a fake MPD server speaking the real protocol, QML unit tests), linting and formatting gates (`make check`), pre-commit hook, `make package`.

[0.1.0]: https://github.com/columbiafoundry/kOMA-MusicThing/releases/tag/v0.1.0
