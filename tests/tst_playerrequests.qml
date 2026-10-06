import QtQuick
import QtTest
import "../contents/ui" as UI

TestCase {
    id: test
    name: "PlayerRequests"
    property var pending: []
    UI.PlayerRequests {
        id: requests
        execute: function (args, callback) {
            test.pending.push({
                args: args,
                callback: callback
            })
        }
    }
    SignalSpy {
        id: responses
        target: requests
        signalName: "response"
    }
    function init() {
        pending = []
        requests.refreshing = false
        requests.controlsInFlight = 0
        requests.generation = 0
        responses.clear()
    }
    function test_slowStatusDoesNotAccumulatePolls() {
        for (let i = 0; i < 1000; ++i)
            requests.refresh()
        compare(pending.length, 1)
        pending[0].callback(0, "status", "")
        compare(responses.count, 1)
        requests.refresh()
        compare(pending.length, 2)
    }
    function test_failureReleasesGuard() {
        requests.refresh()
        pending[0].callback(1, "", "MPD unavailable")
        compare(requests.refreshing, false)
        requests.refresh()
        compare(pending.length, 2)
    }
    function test_oldPollCannotReplaceActionState() {
        requests.refresh()
        requests.send("pause")
        pending[1].callback(0, "paused", "")
        compare(responses.count, 1)
        pending[0].callback(0, "playing", "")
        compare(responses.count, 1)
        compare(pending.length, 3)
        pending[2].callback(0, "paused", "")
        compare(responses.signalArguments[1][1], "paused")
    }
    function test_pollingWaitsForControlsAndReadsFinalState() {
        requests.send("next")
        requests.send("next")
        requests.refresh()
        compare(pending.length, 2)
        pending[1].callback(0, "newer", "")
        pending[0].callback(0, "older", "")
        compare(responses.count, 1)
        compare(pending.length, 3)
        pending[2].callback(0, "final", "")
        compare(responses.signalArguments[1][1], "final")
        compare(requests.controlsInFlight, 0)
    }
}
