pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtTest
import org.kde.plasma.core as PlasmaCore
import "../contents/ui" as UI

TestCase {
    id: test
    name: "PopupSizing"
    when: windowShown
    width: 1000
    height: 800

    QtObject {
        id: host
        property bool expanded: false
        property bool full: false
        property bool setupVisible: false
        property bool mpdUp: true
        property bool starting: false
        property string error: ""
        property string browserTab: ""
        property var info: ({})
    }

    UI.MusicPopup {
        id: popup
        host: host
    }

    Component {
        id: shellPopup
        PlasmaCore.AppletPopup {
            mainItem: Item {
                implicitWidth: player.Layout.preferredWidth
                implicitHeight: player.Layout.preferredHeight + 1
                Layout.minimumWidth: player.Layout.minimumWidth
                Layout.maximumWidth: player.Layout.maximumWidth
                Layout.minimumHeight: player.Layout.minimumHeight + 1
                Layout.maximumHeight: player.Layout.maximumHeight + 1
                UI.MusicPopup {
                    id: player
                    anchors.fill: parent
                    anchors.bottomMargin: 1
                    host: host
                }
            }
        }
    }

    function test_shellContainersRestoreSizeIndependently() {
        var first = createTemporaryObject(shellPopup, test)
        var second = createTemporaryObject(shellPopup, test)
        verify(first !== null)
        verify(second !== null)
        wait(0)
        var miniWidth = first.width
        var miniHeight = first.height
        host.full = true
        tryVerify(() => first.width > miniWidth && first.height > miniHeight)
        tryVerify(() => second.width > miniWidth && second.height > miniHeight)
        host.full = false
        tryCompare(first, "width", miniWidth)
        tryCompare(first, "height", miniHeight)
        tryCompare(second, "width", miniWidth)
        tryCompare(second, "height", miniHeight)
    }

    function test_collapseRestoresActualMiniDimensions() {
        var miniWidth = popup.width
        var miniHeight = popup.height
        verify(miniWidth > 0)
        verify(miniHeight > 0)
        for (var i = 0; i < 3; ++i) {
            host.full = true
            tryCompare(popup, "width", popup.fullWidth)
            tryCompare(popup, "height", popup.fullHeight)
            host.full = false
            tryCompare(popup, "width", miniWidth)
            tryCompare(popup, "height", miniHeight)
            compare(popup.Layout.preferredWidth, miniWidth)
            compare(popup.Layout.preferredHeight, miniHeight)
        }
    }
}
