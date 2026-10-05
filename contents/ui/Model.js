.pragma library

// kOMA Music Thing: pure helpers for the panel (no I/O), unit-tested in
// tests/tst_model.qml.

function formatTime(seconds) {
    var s = Math.max(0, Math.floor(Number(seconds) || 0))
    var h = Math.floor(s / 3600)
    var m = Math.floor((s % 3600) / 60)
    var r = s % 60
    var mm = h > 0 && m < 10 ? "0" + m : String(m)
    return (h > 0 ? h + ":" : "") + mm + ":" + (r < 10 ? "0" : "") + r
}

// 0..1 through the current song.
function progress(info) {
    if (!info || !(info.duration > 0))
        return 0
    return Math.min(1, Math.max(0, info.elapsed / info.duration))
}

function isPlaying(info) {
    return !!info && info.state === "play"
}

function hasSong(info) {
    return !!info && !!info.file
}

// Title line and secondary line for the mini view.
function titleText(info) {
    if (!hasSong(info))
        return info && info.queueLength ? "Ready to play" : "Nothing queued"
    return info.title || "Unknown title"
}

function subtitleText(info) {
    if (!hasSong(info))
        return info && info.queueLength ? info.queueLength + " in the queue" : "Expand to pick music in rmpc"
    var parts = []
    if (info.artist)
        parts.push(info.artist)
    if (info.album)
        parts.push(info.album)
    return parts.join(" — ")
}

// Panel icon by playback state.
function stateIcon(info) {
    if (isPlaying(info))
        return "media-playback-playing"
    if (info && info.state === "pause")
        return "media-playback-paused"
    return "media-playback-stopped"
}

// Tooltip: "Neil Diamond — Solitary Man" / "Paused" / "Stopped".
function tooltip(info) {
    if (!hasSong(info))
        return "Stopped"
    var who = info.artist ? info.artist + " — " : ""
    return who + (info.title || "") + (info.state === "pause" ? " (paused)" : "")
}

// JSON.parse that returns null instead of throwing.
function parseJson(text) {
    try {
        return JSON.parse(text)
    } catch (e) {
        return null
    }
}
