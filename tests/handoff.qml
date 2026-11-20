import QtQuick
import QtQuick.Window
import ".."

Window {
    id: window
    readonly property var params: JSON.parse(Qt.application.arguments[Qt.application.arguments.length - 1])
    width: 1280; height: 800
    visible: true
    Item { id: destination; x: 200; y: 180; width: 340; height: 340 }
    Timer {
        interval: 30; running: true
        onTriggered: { destination.x = 260; destination.y = 210 }
    }
    BootHandoff {
        id: handoff
        anchors.fill: parent
        avatar: destination
        modelSize: 190
        frames: window.params.frames
        frameCount: window.params.count
        stateFile: window.params.state
    }
    Timer {
        interval: 1200
        running: true
        onTriggered: {
            const target = destination.mapToItem(handoff, destination.width / 2, destination.height / 2)
            if (handoff.hasState !== window.params.expected
                || (handoff.hasState && (handoff.progress !== 1 || handoff.elapsed < 1
                    || Math.abs(handoff.target.x - target.x) > 0.1
                    || Math.abs(handoff.target.y - target.y) > 0.1))) {
                console.error("handoff mismatch", handoff.hasState, handoff.progress, handoff.elapsed)
                Qt.exit(1)
            } else {
                Qt.quit()
            }
        }
    }
}
