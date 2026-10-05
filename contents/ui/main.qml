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
import org.kde.plasma.plasma5support as P5Support
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
        var command = "konsole --hold -e python3 " + shellQuote(setupCli) + " install " + shellQuote(component) + " # setup-" + Date.now()
        var cbs = callbacks
        cbs[command] = function (code, out, err) {
            setupBusy = false
            setupError = code !== 0
            setupMessage = code === 0 ? "Installer closed. Package status refreshed." : (err.trim() || "Installer failed. Refresh setup and try again.")
            refreshSetup()
        }
        callbacks = cbs
        runner.connectSource(command)
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
    property bool rmpcRunning: false // rmpc's terminal exists (kept while collapsed)
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
    property var callbacks: ({})
    function call(args, callback, program = cli) {
        var source = "python3 " + shellQuote(program) + " " + args.map(shellQuote).join(" ") + " # " + Date.now() + Math.random()
        var cbs = callbacks
        cbs[source] = callback
        callbacks = cbs
        runner.connectSource(source)
    }

    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: function (source, data) {
            disconnectSource(source)
            var cb = root.callbacks[source]
            var cbs = root.callbacks
            delete cbs[source]
            root.callbacks = cbs
            if (cb)
                cb(data["exit code"], String(data.stdout || ""), String(data.stderr || ""))
        }
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
            openRmpc()
            refresh()
        })
    }
    function openRmpc() {
        rmpcRunning = true
        full = true
    }
    // rmpc quit (q): collapse and stop playback (as the user's rmpc shell
    // wrapper does with mpc stop), and stop MPD if we were the ones who started it
    function rmpcQuit() {
        full = false
        rmpcRunning = false
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
        runner.connectSource(command + " # " + Date.now())
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
        call(["status", "--json"], handle)
    }

    // play/pause, next, prev: apply and show the new state at once
    function send(action) {
        call([action, "--json"], handle)
    }

    // MPD is local: every second while open, every 5 s for the panel icon
    Timer {
        interval: root.expanded ? 1000 : 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    onExpandedChanged: if (root.expanded)
        refresh()

    compactRepresentation: MouseArea {
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        // middle click: play/pause without opening
        onClicked: mouse => mouse.button === Qt.MiddleButton ? root.send("toggle") : root.expanded = !root.expanded
        onWheel: wheel => root.send(wheel.angleDelta.y < 0 ? "next" : "prev")
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
