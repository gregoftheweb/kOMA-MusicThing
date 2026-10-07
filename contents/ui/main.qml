/*
    kOMA Music Thing — a compact MPD player for the Plasma 6 panel.

    The popup has two sizes: mini (now playing, play/pause, skip) and full,
    where rmpc runs inside the popup to pick music and build the queue.
    Playback controls go straight to MPD through the bundled `komamusic`
    client (contents/code/komamusic); rmpc does the browsing.
*/
pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "Model.js" as Model

PlasmoidItem {
    id: root

    readonly property string cli: decodeURIComponent(Qt.resolvedUrl("../code/komamusic").toString().replace("file://", ""))

    readonly property string setupCli: decodeURIComponent(Qt.resolvedUrl("../code/music_setup.py").toString().replace("file://", ""))
    property var setupInfo: ({})
    property bool setupVisible: false
    property bool setupBusy: false
    property bool setupChecked: false
    property bool setupRefreshing: false
    property string setupMessage: ""
    property bool setupError: false
    function refreshSetup() {
        if (setupRefreshing)
            return
        setupRefreshing = true
        call(["status"], function (code, out) {
            setupRefreshing = false
            var result = Model.parseJson(out)
            if (code !== 0 || !result || result.error)
                return
            setupInfo = result
            if (!setupChecked) {
                setupChecked = true
                if (!(result.dependencies || []).filter(d => d.name === "mpd" || d.name === "rmpc" || d.name === "cava").every(d => d.ok) || (!result.connected && !result.mpdConfigured))
                    setupVisible = true
            }
        }, setupCli)
    }
    function setupAction(args) {
        if (setupBusy)
            return
        setupBusy = true
        setupMessage = ""
        call(args, function (code, out, err) {
            setupBusy = false
            var result = Model.parseJson(out)
            setupError = code !== 0 || !result || !!result.error
            setupMessage = result ? (result.error || result.message || "Done") : (err.trim() || "Setup failed")
            if (result && result.started)
                startedMpd = true
            refreshSetup()
            refresh()
        }, setupCli)
    }
    function installSetup(component) {
        if (setupBusy)
            return
        setupBusy = true
        setupMessage = "Follow the package installer in the terminal, then return here."
        setupError = false
        commands.run("konsole --hold -e python3 " + shellQuote(setupCli) + " install " + shellQuote(component), function (code, out, err) {
            setupBusy = false
            setupError = code !== 0
            setupMessage = code === 0 ? "Installer closed. Package status refreshed." : (err.trim() || "Installer failed. Refresh setup and try again.")
            refreshSetup()
        })
    }
    Timer {
        interval: 5000
        running: root.expanded && root.setupVisible
        repeat: true
        onTriggered: root.refreshSetup()
    }
    Component.onCompleted: refreshSetup()

    property var info: ({})
    property string error: ""
    property bool full: false // mini view or rmpc view
    property string browserTab: "" // bookmark survives popup recreation
    property bool startedMpd: false // we started mpd.service, so we stop it when rmpc quits
    property bool starting: false
    readonly property bool mpdUp: error === "" && info.state !== undefined

    switchWidth: Kirigami.Units.gridUnit * 12
    switchHeight: Kirigami.Units.gridUnit * 4
    Plasmoid.icon: Model.stateIcon(info)
    toolTipMainText: mpdUp ? Model.tooltip(info) : "kOMA Music Thing"
    toolTipSubText: error || (!mpdUp ? "MPD is not running. Open kOMA Music Thing to set it up." : (Model.hasSong(info) ? Model.formatTime(info.elapsed) + " / " + Model.formatTime(info.duration) : ""))

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    // ---------------------------------------------------------------- CLI calls
    function call(args, callback, program = cli) {
        commands.run("python3 " + shellQuote(program) + " " + args.map(shellQuote).join(" "), callback)
    }

    CommandQueue {
        id: commands
    }

    // Start rmpc: like the rmpcs script, bring MPD up first if it isn't
    function startRmpc() {
        if (starting)
            return
        starting = true
        call(["start-mpd", "--json"], function (code, out, err) {
            starting = false
            var r = code === 0 ? Model.parseJson(out) : null
            if (!r) {
                error = err.trim().replace(/^komamusic: /, "") || "couldn't start MPD"
                return
            }
            if (r.started)
                startedMpd = true
            error = ""
            refresh()
        })
    }
    function openRmpc() {
        full = true
    }
    // rmpc quit (q): collapse and stop playback (as the user's rmpc shell
    // wrapper does with mpc stop), and stop MPD if we were the ones who started it
    function rmpcQuit() {
        full = false
        call(["stop"], function () {})
        if (startedMpd) {
            startedMpd = false
            call(["stop-mpd"], function () {
                root.refresh()
            })
        }
    }

    // a command whose output nobody needs (opening rmpc in a terminal window)
    function runDetached(command) {
        commands.run(command)
    }

    function handle(code, out, err) {
        var r = code === 0 ? Model.parseJson(out) : null
        if (r) {
            info = r
            error = ""
        } else {
            error = err.trim().replace(/^komamusic: /, "") || "MPD did not answer"
        }
    }

    function refresh() {
        playerRequests.refresh()
    }

    // play/pause, next, prev: apply and show the new state at once
    function send(action) {
        playerRequests.send(action)
    }

    PlayerRequests {
        id: playerRequests
        execute: (args, callback) => root.call(args, callback)
        onResponse: (code, output, error) => root.handle(code, output, error)
    }

    PopupState {
        host: root
    }

    // Open: every second, for the progress bar. Closed: the panel icon and tooltip
    // change only when MPD does, so wait for MPD to report a change instead of
    // polling. Without a reachable MPD, check every 5 s until one appears.
    property bool watching: false
    function watch() {
        if (watching || !mpdUp)
            return
        watching = true
        call(["wait", "--json"], function (code) {
            watching = false
            refresh()
            if (code === 0)
                watch()
        })
    }
    Timer {
        interval: root.expanded ? 1000 : 5000
        running: root.expanded || !root.watching
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.refresh()
            root.watch()
        }
    }
    onExpandedChanged: if (root.expanded)
        refresh()

    compactRepresentation: MouseArea {
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        // middle click: play/pause without opening
        onClicked: mouse => mouse.button === Qt.MiddleButton ? root.send("toggle") : root.expanded = !root.expanded
        onWheel: wheel => root.send(wheel.angleDelta.y < 0 ? "next" : "prev")
        // the tooltip shows elapsed time, which MPD doesn't announce
        onContainsMouseChanged: if (containsMouse)
            root.refresh()
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height, Kirigami.Units.iconSizes.smallMedium)
            height: width
            source: Plasmoid.icon
            active: parent.containsMouse
        }
    }

    fullRepresentation: MusicPopup {
        host: root
    }
}
