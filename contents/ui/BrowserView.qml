// MIT — Copyright 2026 Columbia Foundry
pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root
    required property var host
    property url terminalSource: Qt.resolvedUrl("Terminal.qml")
    readonly property bool sessionActive: host.expanded && host.full && !host.setupVisible
    readonly property bool unavailable: terminal.status === Loader.Error

    readonly property string rememberedTab: host.browserTab
    property bool saving: false
    property bool loaded: false
    property bool exiting: false
    readonly property var browserItem: terminal.item

    onSessionActiveChanged: syncSession()
    function syncSession() {
        if (sessionActive) {
            exiting = false
            loaded = true
        } else if (terminal.item && !saving) {
            saving = true
            browserItem.captureTab(function (tab) {
                if (tab)
                    root.host.browserTab = tab
                root.saving = false
                root.loaded = root.sessionActive
            })
        } else if (!saving) {
            loaded = false
        }
    }

    Loader {
        id: terminal
        anchors.fill: parent
        active: root.loaded
        source: root.terminalSource
        onLoaded: {
            item.execute = function (args, callback) {
                root.host.call(args, callback)
            }
            item.rememberedTab = root.rememberedTab
            var view = item as Item
            view?.forceActiveFocus()
        }
    }
    Connections {
        target: terminal.item
        ignoreUnknownSignals: true
        function onRmpcExited() {
            // Loader destruction on collapse is not an explicit rmpc quit.
            // Only q/normal exit from an active browser invokes stop behavior.
            if (root.sessionActive && !root.exiting) {
                // A finished process cannot answer a tab query.
                root.exiting = true
                root.loaded = false
                root.host.rmpcQuit()
            }
        }
    }
}
