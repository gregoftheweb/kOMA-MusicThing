pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras

ColumnLayout {
    id: page
    required property var host
    spacing: Kirigami.Units.largeSpacing
    function installed(name) {
        return (host.setupInfo.dependencies || []).some(d => d.name === name && d.ok)
    }
    RowLayout {
        Layout.fillWidth: true
        PlasmaExtras.Heading {
            text: "Set up Music Thing"
            level: 2
            Layout.fillWidth: true
        }
        PC3.ToolButton {
            icon.name: "view-refresh"
            enabled: !page.host.setupBusy
            onClicked: page.host.refreshSetup()
        }
        PC3.ToolButton {
            icon.name: "window-close"
            onClicked: page.host.setupVisible = false
        }
    }
    PC3.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: availableWidth
        ColumnLayout {
            width: parent.width
            spacing: Kirigami.Units.largeSpacing
            PC3.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "Install the player and visualizer, choose your music folder, then start listening. Existing settings are kept."
            }
            PlasmaExtras.Heading {
                text: "1 · Install"
                level: 3
            }
            Repeater {
                model: [
                    {
                        name: "mpd",
                        label: "MPD · Music playback",
                        component: "mpd"
                    },
                    {
                        name: "rmpc",
                        label: "rmpc · Music browser",
                        component: "rmpc"
                    },
                    {
                        name: "cava",
                        label: "cava · Live sound graph",
                        component: "extras"
                    }
                ]
                RowLayout {
                    id: dependency
                    required property var modelData
                    Layout.fillWidth: true
                    PC3.Label {
                        text: dependency.modelData.label
                        Layout.fillWidth: true
                    }
                    PC3.Button {
                        text: page.installed(dependency.modelData.name) ? "Installed" : "Install"
                        icon.name: page.installed(dependency.modelData.name) ? "dialog-ok-apply" : "download"
                        enabled: !page.host.setupBusy && !page.installed(dependency.modelData.name) && !!page.host.setupInfo.installSupported
                        onClicked: page.host.installSetup(dependency.modelData.component)
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                PC3.Label {
                    text: "Embedded terminal"
                    Layout.fillWidth: true
                }
                PC3.Button {
                    text: page.installed("QMLTermWidget") ? "Installed" : "Install"
                    enabled: !page.host.setupBusy && !page.installed("QMLTermWidget") && !!page.host.setupInfo.installSupported
                    onClicked: page.host.installSetup("extras")
                }
            }
            PC3.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                opacity: 0.7
                text: page.host.setupInfo.installSupported ? "Installation opens a terminal for your password and package progress. Return here when it finishes. The visualizer installer also includes the embedded terminal." : "Automatic installation supports Arch-based systems. On other systems, install MPD, rmpc, cava, and the Qt 6 QMLTermWidget package, then refresh. Configuration below works with installed dependencies."
            }
            Kirigami.Separator {
                Layout.fillWidth: true
            }
            PlasmaExtras.Heading {
                text: "2 · Configure"
                level: 3
            }
            PC3.Label {
                text: "Music folder"
            }
            RowLayout {
                Layout.fillWidth: true
                PC3.TextField {
                    id: musicFolder
                    Layout.fillWidth: true
                    placeholderText: page.host.setupInfo.musicFolder || "Choose your music folder"
                    enabled: !page.host.setupBusy
                }
                PC3.Button {
                    text: "Browse…"
                    enabled: !page.host.setupBusy
                    onClicked: folder.open()
                }
            }
            FolderDialog {
                id: folder
                title: "Choose your music folder"
                onAccepted: musicFolder.text = decodeURIComponent(selectedFolder.toString().replace(/^file:\/\//, ""))
            }
            PC3.Button {
                Layout.fillWidth: true
                text: page.host.setupInfo.mpdConfigured ? "MPD settings already present" : "Configure MPD"
                enabled: !page.host.setupBusy && page.installed("mpd") && !page.host.setupInfo.mpdConfigured
                onClicked: page.host.setupAction(["configure-mpd", musicFolder.text || page.host.setupInfo.musicFolder])
            }
            PC3.Button {
                Layout.fillWidth: true
                text: page.host.setupInfo.rmpcConfigured ? "rmpc settings already present" : "Configure rmpc"
                enabled: !page.host.setupBusy && page.installed("rmpc") && !page.host.setupInfo.rmpcConfigured
                onClicked: page.host.setupAction(["configure-rmpc"])
            }
            PC3.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                opacity: 0.7
                text: "New MPD setups use desktop audio and stay local to this machine. cava is configured automatically when rmpc opens inside the panel."
            }
            Kirigami.Separator {
                Layout.fillWidth: true
            }
            PlasmaExtras.Heading {
                text: "3 · Start listening"
                level: 3
            }
            PC3.Button {
                Layout.fillWidth: true
                text: "Start MPD and scan music"
                icon.name: "media-playback-start"
                enabled: !page.host.setupBusy && page.installed("mpd") && page.installed("rmpc") && page.installed("cava")
                onClicked: page.host.setupAction(["verify"])
            }
            PC3.Button {
                Layout.fillWidth: true
                text: "Open music browser"
                enabled: !page.host.setupBusy && !!page.host.setupInfo.connected && page.installed("rmpc") && page.installed("cava")
                onClicked: {
                    page.host.setupVisible = false
                    page.host.openRmpc()
                }
            }
            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: page.host.setupMessage.length > 0
                text: page.host.setupMessage
                type: page.host.setupError ? Kirigami.MessageType.Error : Kirigami.MessageType.Information
            }
            PC3.BusyIndicator {
                visible: page.host.setupBusy
                running: visible
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
