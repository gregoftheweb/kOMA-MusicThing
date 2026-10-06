// MIT — Copyright 2026 Columbia Foundry
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root

    required property var execute
    property bool refreshing: false
    property int controlsInFlight: 0
    property int generation: 0
    signal response(int code, string output, string error)

    function refresh() {
        if (refreshing || controlsInFlight > 0)
            return
        refreshing = true
        const run = generation
        execute(["status", "--json"], function (code, out, err) {
            root.refreshing = false
            if (run === root.generation)
                root.response(code, out, err)
            else if (root.controlsInFlight === 0)
                root.refresh()
        })
    }

    function send(action) {
        const run = ++generation
        controlsInFlight++
        execute([action, "--json"], function (code, out, err) {
            root.controlsInFlight--
            if (run === root.generation)
                root.response(code, out, err);
            // Read the final server state after overlapping user controls.
            // An older status response can never overwrite a newer action.
            if (root.controlsInFlight === 0)
                root.refresh()
        })
    }
}
