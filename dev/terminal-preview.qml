// Dev preview: rmpc in QMLTermWidget outside the panel.
//   qml6 dev/terminal-preview.qml
import QtQuick
import QtQuick.Window
import "../contents/ui"

Window {
    width: 900
    height: 560
    visible: true
    title: "kOMA Music Thing — terminal preview"
    Terminal {
        anchors.fill: parent
        onRmpcExited: Qt.quit()
    }
}
