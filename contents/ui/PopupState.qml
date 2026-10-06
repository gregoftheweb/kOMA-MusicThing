// MIT — Copyright 2026 Columbia Foundry
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root
    required property var host

    property Connections visibility: Connections {
        target: root.host
        function onExpandedChanged() {
            // Every panel opening starts in mini view, even after browsing.
            root.host.full = false
            if (root.host.expanded)
                root.host.setupVisible = false
        }
    }
}
