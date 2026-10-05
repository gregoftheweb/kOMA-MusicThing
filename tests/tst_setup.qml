import QtQuick
import QtTest
import "../contents/ui" as UI

TestCase {
    id: test
    name: "MusicSetup"
    width: 520
    height: 680
    when: windowShown
    QtObject {
        id: fake
        property var setupInfo: ({
                dependencies: [
                    {
                        name: "mpd",
                        ok: true
                    },
                    {
                        name: "rmpc",
                        ok: true
                    },
                    {
                        name: "cava",
                        ok: false
                    }
                ],
                installSupported: true
            })
        property bool setupBusy: false
        property bool setupVisible: true
        property string setupMessage: ""
        property bool setupError: false
        function refreshSetup() {
        }
        function installSetup(component) {
        }
        function setupAction(args) {
        }
        function openRmpc() {
        }
    }
    UI.MusicSetup {
        id: page
        anchors.fill: parent
        host: fake
    }
    function test_detects_visualizer_missing() {
        compare(page.installed("mpd"), true)
        compare(page.installed("rmpc"), true)
        compare(page.installed("cava"), false)
    }
    function test_tracks_installation_status() {
        fake.setupInfo = {
            dependencies: [
                {
                    name: "cava",
                    ok: true
                }
            ],
            installSupported: true
        }
        compare(page.installed("cava"), true)
        compare(page.installed("mpd"), false)
    }
}
