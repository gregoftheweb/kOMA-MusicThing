/*
    rmpc running inside the kOMA Music Thing popup, in a real terminal
    emulator (QMLTermWidget, the terminal of cool-retro-term). This is the only
    file that needs QMLTermWidget: without it, the Loader in MusicPopup.qml
    fails cleanly and the popup offers rmpc in a terminal window instead.
*/
pragma ComponentBehavior: Bound

import QtQuick
import QMLTermWidget
import org.kde.kirigami as Kirigami

QMLTermWidget {
    id: terminal

    // rmpc quit (q): the popup collapses (and stops MPD if it started it)
    signal rmpcExited

    font.family: Kirigami.Theme.fixedWidthFont.family
    font.pointSize: Kirigami.Theme.fixedWidthFont.pointSize
    colorScheme: "BreezeModified"

    session: QMLTermSession {
        id: session
        initialWorkingDirectory: "$HOME"
        // rmpc with the user's config minus album art, which this terminal can't draw
        shellProgram: "python3"
        shellProgramArgs: [decodeURIComponent(Qt.resolvedUrl("../code/komamusic").toString().replace("file://", "")), "rmpc"]
        onFinished: terminal.rmpcExited()
    }

    Component.onCompleted: session.startShellProgram()
}
