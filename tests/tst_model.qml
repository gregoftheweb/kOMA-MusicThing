// Unit tests for Model.js (time formatting, progress, labels, icons).
import QtQuick
import QtTest
import "../contents/ui/Model.js" as M

TestCase {
    name: "Model"

    readonly property var playing: ({
            "state": "play",
            "title": "Solitary Man",
            "artist": "Neil Diamond",
            "album": "50",
            "file": "a.mp3",
            "elapsed": 44.87,
            "duration": 153.45,
            "queueLength": 34
        })

    function test_formatTime() {
        compare(M.formatTime(44.87), "0:44")
        compare(M.formatTime(153.45), "2:33")
        compare(M.formatTime(3725), "1:02:05")
        compare(M.formatTime(-3), "0:00")
        compare(M.formatTime(undefined), "0:00")
    }

    function test_progress() {
        fuzzyCompare(M.progress(playing), 0.2924, 0.001)
        compare(M.progress({
            "elapsed": 10,
            "duration": 0
        }), 0)
        compare(M.progress(null), 0)
        compare(M.progress({
            "elapsed": 99,
            "duration": 10
        }), 1)
    }

    function test_texts() {
        compare(M.titleText(playing), "Solitary Man")
        compare(M.subtitleText(playing), "Neil Diamond — 50")
        compare(M.titleText({
            "queueLength": 0
        }), "Nothing queued")
        compare(M.subtitleText({
            "queueLength": 0
        }), "Expand to pick music in rmpc")
        compare(M.titleText({
            "queueLength": 5
        }), "Ready to play")
        compare(M.subtitleText({
            "queueLength": 5
        }), "5 in the queue")
    }

    function test_icon_and_tooltip() {
        compare(M.stateIcon(playing), "media-playback-playing")
        compare(M.stateIcon({
            "state": "pause"
        }), "media-playback-paused")
        compare(M.stateIcon(null), "media-playback-stopped")
        compare(M.tooltip(playing), "Neil Diamond — Solitary Man")
        compare(M.tooltip({
            "state": "pause",
            "file": "x",
            "title": "T"
        }), "T (paused)")
        compare(M.tooltip({}), "Stopped")
    }

    function test_parseJson() {
        compare(M.parseJson('{"state":"play"}').state, "play")
        compare(M.parseJson("nope"), null)
    }
}
