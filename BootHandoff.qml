import QtQuick

// Shared, precoloured frames keep the pose, spin and palette identical
// across Slint and Qt. Only public visual state is read from /run.
Item {
    id: root
    required property Item avatar
    required property real modelSize
    property bool hasState: false
    property var handoffState: null
    property real progress: 0
    property real elapsed: 0
    property url frames
    property url stateFile: "file:///run/bento-boot-handoff.json"
    property int frameCount: 0
    property real fps: 30
    property real modelRatio: 0.875
    property color base: "#11111b"
    // mapToItem does not track layout/ancestor transforms as binding
    // dependencies. Refresh after layout and while tiles animate.
    property point target: Qt.point(0, 0)
    readonly property real targetSize: modelSize / Math.max(modelRatio, 0.01)
    readonly property real initialX: handoffState ? handoffState.x * width : 0
    readonly property real initialY: handoffState ? handoffState.y * height : 0
    readonly property real initialSize: handoffState ? handoffState.size * height : 0

    visible: hasState

    function readState() {
        if (frameCount <= 0 || frames.toString() === "" || fps <= 0)
            return
        try {
            const request = new XMLHttpRequest()
            request.open("GET", root.stateFile, false)
            request.send()
            const s = JSON.parse(request.responseText)
            const age = Date.now() - s.savedAt
            if (s.version !== 1 || age < 0 || age > 20000
                || !Number.isInteger(s.frame) || s.frame < 0 || s.frame >= frameCount
                || !Number.isFinite(s.x) || !Number.isFinite(s.y) || !Number.isFinite(s.size)
                || s.x < 0 || s.x > 1 || s.y < 0 || s.y > 1 || s.size <= 0 || s.size > 2)
                return
            elapsed = age / 1000
            target = avatar.mapToItem(root, avatar.width / 2, avatar.height / 2)
            hasState = true
            // Assigning the source can synchronously report Image.Error.
            // Do not overwrite the fallback chosen by that handler.
            handoffState = s
            if (hasState)
                clock.start()
        } catch (_) {
            // Starting the greeter by hand or after a crash needs no handoff.
        }
    }
    Component.onCompleted: readState()

    // Start the transition when the first matching image is ready. The
    // first pose is held until then, rather than skipping ahead unseen.
    NumberAnimation {
        id: transition
        target: root
        property: "progress"
        from: 0; to: 1
        duration: 700
        easing.type: Easing.InOutCubic
    }
    Timer {
        id: clock
        interval: 1000 / root.fps
        repeat: true
        onTriggered: {
            root.target = root.avatar.mapToItem(root, root.avatar.width / 2, root.avatar.height / 2)
            if (transition.running || root.progress === 1)
                root.elapsed = Math.max(0, Date.now() - root.handoffState.savedAt) / 1000
        }
    }
    Rectangle {
        anchors.fill: parent
        color: root.base
        opacity: 1 - root.progress
    }
    Image {
        x: root.initialX + (root.target.x - root.initialX) * root.progress - width / 2
        y: root.initialY + (root.target.y - root.initialY) * root.progress - height / 2
        width: root.initialSize + (root.targetSize - root.initialSize) * root.progress
        height: width
        smooth: false
        cache: true
        source: root.handoffState ? root.frames.toString().replace(/\/$/, "") + "/frame-"
            + ((root.handoffState.frame + Math.floor(root.elapsed * root.fps)) % root.frameCount) + ".png" : ""
        onStatusChanged: {
            if (status === Image.Ready && root.progress === 0 && !transition.running)
                transition.start()
            if (status === Image.Error) {
                clock.stop()
                root.hasState = false
            }
        }
    }
}
