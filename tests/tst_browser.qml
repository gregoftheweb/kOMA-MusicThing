import QtQuick
import QtTest
import "../contents/ui" as UI

TestCase {
    id: test
    name: "BrowserLifecycle"
    width: 500
    height: 300
    when: windowShown

    QtObject {
        id: host
        property string browserTab: ""
        property bool expanded: false
        property bool full: false
        property bool setupVisible: false
        property int quits: 0
        function rmpcQuit() {
            quits++
            full = false
        }
    }
    UI.PopupState {
        host: host
    }
    UI.BrowserView {
        id: browser
        anchors.fill: parent
        host: host
        terminalSource: Qt.resolvedUrl("MockTerminal.qml")
    }
    function terminal() {
        return findChild(browser, "mockTerminal")
    }
    function init() {
        host.full = false
        host.expanded = false
        host.setupVisible = false
        wait(0)
        host.quits = 0
    }
    function test_openAlwaysStartsSmallAndExpandCreatesBrowser() {
        host.expanded = true
        compare(host.full, false)
        compare(terminal(), null)
        host.full = true
        tryVerify(() => terminal() !== null)
        host.expanded = false
        tryVerify(() => terminal() === null)
        compare(host.quits, 0)
        host.expanded = true
        compare(host.full, false)
        compare(terminal(), null)
    }
    function test_collapseAndSetupReleaseBrowserWithoutQuit() {
        host.expanded = true
        host.full = true
        tryVerify(() => terminal() !== null)
        host.full = false
        tryVerify(() => terminal() === null)
        host.full = true
        tryVerify(() => terminal() !== null)
        host.setupVisible = true
        tryVerify(() => terminal() === null)
        compare(host.quits, 0)
    }
    function test_explicitQuitStillInvokesExistingStopBehavior() {
        host.expanded = true
        host.full = true
        tryVerify(() => terminal() !== null)
        terminal().rmpcExited()
        compare(host.quits, 1)
        tryVerify(() => terminal() === null)
        compare(host.quits, 1)
    }
    function test_remembersTabAcrossRecreation() {
        host.expanded = true
        host.full = true
        tryVerify(() => terminal() !== null)
        terminal().activeTab = "Artists"
        host.expanded = false
        tryVerify(() => terminal() === null)
        compare(browser.rememberedTab, "Artists")
        host.expanded = true
        compare(terminal(), null)
        host.full = true
        tryVerify(() => terminal() !== null)
        compare(terminal().rememberedTab, "Artists")
        compare(host.quits, 0)
    }
    function test_closeQueryFinishesAfterReopen() {
        host.expanded = true
        host.full = true
        tryVerify(() => terminal() !== null)
        var oldTerminal = terminal()
        oldTerminal.delayCapture = true
        host.expanded = false
        compare(browser.saving, true)
        host.expanded = true
        compare(host.full, false)
        oldTerminal.pendingCapture("Playlists")
        tryVerify(() => terminal() === null)
        compare(browser.rememberedTab, "Playlists")
        compare(host.quits, 0)
    }
    function test_failedQueryKeepsPreviousBookmark() {
        host.browserTab = "Artists"
        host.expanded = true
        host.full = true
        tryVerify(() => terminal() !== null)
        terminal().activeTab = ""
        host.full = false
        tryVerify(() => terminal() === null)
        compare(browser.rememberedTab, "Artists")
        compare(host.quits, 0)
    }
    function test_reopenClearsSetupAndFullView() {
        host.setupVisible = true
        host.full = true
        host.expanded = true
        compare(host.setupVisible, false)
        compare(host.full, false)
        compare(terminal(), null)
    }
}
