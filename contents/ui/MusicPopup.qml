/*
    The kOMA Music Thing popup: a mini player, and an expanded view with rmpc
    running inside the popup. The terminal exists only while the full player
    is open; collapsing releases it without stopping MPD playback.
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import "Model.js" as Model

PlasmaExtras.Representation {
    id: popup

    // the PlasmoidItem from main.qml: info, error, full, send(), ...
    required property var host

    readonly property real miniHeight: mini.implicitHeight + Kirigami.Units.largeSpacing * 2
    readonly property real fullWidth: Kirigami.Units.gridUnit * 48
    readonly property real fullHeight: Kirigami.Units.gridUnit * 30

    // fixed sizes (min = max) so Plasma resizes the popup when switching views
    Layout.minimumWidth: host.setupVisible ? Kirigami.Units.gridUnit * 28 : host.full ? fullWidth : Kirigami.Units.gridUnit * 20
    Layout.maximumWidth: Layout.minimumWidth
    Layout.preferredWidth: Layout.minimumWidth
    Layout.minimumHeight: host.setupVisible ? Kirigami.Units.gridUnit * 34 : host.full ? fullHeight : miniHeight
    Layout.maximumHeight: Layout.minimumHeight
    Layout.preferredHeight: Layout.minimumHeight
    collapseMarginsHint: true

    Loader {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        active: popup.host.setupVisible
        sourceComponent: Component {
            MusicSetup {
                host: popup.host
            }
        }
    }
    ColumnLayout {
        visible: !popup.host.setupVisible
        anchors.fill: parent
        spacing: 0

        // ---------------------------------------------------------- mini view
        ColumnLayout {
            id: mini
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label {
                    text: "kOMA Music Thing"
                    Layout.fillWidth: true
                    opacity: 0.7
                }
                PlasmaComponents.ToolButton {
                    icon.name: "configure"
                    onClicked: {
                        popup.host.setupVisible = true
                        popup.host.refreshSetup()
                    }
                    PlasmaComponents.ToolTip {
                        text: "Set up MPD, rmpc, and cava"
                    }
                }
            }
            RowLayout {  // MPD down: one button gets everything going
                Layout.fillWidth: true
                visible: !popup.host.mpdUp
                spacing: Kirigami.Units.smallSpacing
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: popup.host.starting ? "Starting MPD…" : "MPD isn't running"
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: popup.host.error.indexOf("can't reach") === 0 ? "Start it to pick music and play" : popup.host.error
                        opacity: 0.7
                        font: Kirigami.Theme.smallFont
                        elide: Text.ElideRight
                    }
                }
                PlasmaComponents.BusyIndicator {
                    visible: popup.host.starting
                    running: visible
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                }
                PlasmaComponents.Button {
                    text: "Start MPD"
                    icon.name: "media-playback-start"
                    enabled: !popup.host.starting
                    onClicked: popup.host.startRmpc()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: popup.host.mpdUp
                spacing: Kirigami.Units.smallSpacing
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: Model.titleText(popup.host.info)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: Model.subtitleText(popup.host.info)
                        opacity: 0.7
                        font: Kirigami.Theme.smallFont
                        elide: Text.ElideRight
                    }
                }
                PlasmaComponents.ToolButton {
                    icon.name: Model.isPlaying(popup.host.info) ? "media-playback-pause" : "media-playback-start"
                    enabled: !popup.host.error
                    onClicked: popup.host.send("toggle")
                    PlasmaComponents.ToolTip {
                        text: Model.isPlaying(popup.host.info) ? "Pause" : "Play"
                    }
                }
                PlasmaComponents.ToolButton {
                    icon.name: "media-skip-forward"
                    enabled: !popup.host.error && Model.hasSong(popup.host.info)
                    onClicked: popup.host.send("next")
                    PlasmaComponents.ToolTip {
                        text: "Skip"
                    }
                }
                PlasmaComponents.ToolButton {
                    icon.name: popup.host.full ? "view-restore" : "view-fullscreen"
                    onClicked: popup.host.full ? popup.host.full = false : popup.host.openRmpc()
                    PlasmaComponents.ToolTip {
                        text: popup.host.full ? "Collapse" : "Expand: pick music in rmpc"
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: Model.hasSong(popup.host.info)
                PlasmaComponents.Label {
                    text: Model.formatTime(popup.host.info.elapsed)
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                }
                PlasmaComponents.ProgressBar {
                    Layout.fillWidth: true
                    from: 0
                    to: 1
                    value: Model.progress(popup.host.info)
                }
                PlasmaComponents.Label {
                    text: Model.formatTime(popup.host.info.duration)
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                }
            }
        }

        // ---------------------------------------------------------- rmpc view
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: popup.host.full

            BrowserView {
                id: browser
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                host: popup.host
            }

            // without QMLTermWidget: rmpc in a terminal window instead
            PlasmaExtras.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.gridUnit * 4
                visible: browser.unavailable
                iconName: "utilities-terminal"
                text: "rmpc can't run inside the panel here"
                explanation: "Install QMLTermWidget (Arch: qmltermwidget) to run rmpc right in this popup. Until then it opens in a terminal window."
                helpfulAction: Kirigami.Action {
                    icon.name: "utilities-terminal"
                    text: "Open rmpc"
                    onTriggered: popup.host.runDetached("konsole -e rmpc || xdg-terminal-exec rmpc")
                }
            }
        }
    }
}
