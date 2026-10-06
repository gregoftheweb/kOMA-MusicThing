import QtQuick

Item {
    objectName: "mockTerminal"
    property var execute
    property string rememberedTab: ""
    property string activeTab: "Albums"
    property var pendingCapture
    property bool delayCapture: false
    function captureTab(callback) {
        if (delayCapture) {
            pendingCapture = callback
            return
        }
        callback(activeTab)
    }
    signal rmpcExited
    // Simulate a session emitting finished during terminal destruction.
    Component.onDestruction: rmpcExited()
}
