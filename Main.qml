import QtQuick
import QtQuick.Effects
import QtQuick.Window
import "config"
import "components"

// Экран входа SDDM — тот же бенто, что и экран блокировки в quickshell.
// Бенто из двух колонок, разбитых на разной высоте:
//   слева  — аватар с выбором пользователя и сессия под ним,
//   справа — часы и плитка пароля с раскладкой и Caps Lock.
// Пароль проверяет сам SDDM: sddm.login() → loginSucceeded/loginFailed.
// Настройки — в theme.conf.
Item {
    id: root

    width: 1280
    height: 800

    // ===== Настройки из theme.conf =====
    function conf(key, fallback) {
        const v = config[key]
        return v === undefined || v === "" ? fallback : v
    }
    // Относительные пути — от папки темы
    function path(p) {
        if (p === "" || p.includes(":"))
            return p
        return p.startsWith("/") ? "file://" + p : Qt.resolvedUrl(p)
    }

    readonly property string wallpaper: path(conf("background", ""))
    readonly property int wallpaperBlur: Number(conf("blur", 48))
    readonly property real wallpaperDim: Number(conf("dim", 0.45))
    readonly property string avatarModel: path(conf("avatarModel", ""))
    readonly property real modelSize: Number(conf("modelSize", 190))
    readonly property int spinMs: Number(conf("spinMs", 14000))
    readonly property string avatarAnimation: conf("avatarAnimation", "")
    readonly property real animationSpeed: Number(conf("animationSpeed", 1))
    readonly property var locale: Qt.locale(conf("locale", "ru_RU"))

    readonly property int gap: Number(conf("gap", 12))
    readonly property int colW: Number(conf("column", 340))
    readonly property int clockH: Number(conf("clockHeight", 200))
    readonly property int sessionH: Number(conf("sessionHeight", 100))
    // Обе колонки одной высоты: квадрат + сессия = часы + пароль
    readonly property int totalH: colW + gap + sessionH

    // ===== Состояние =====
    property string text: ""
    property bool busy: false
    property string error: ""
    property int fails: 0               // растёт на каждую ошибку — для тряски поля

    // Caps Lock: по набранным буквам (надёжно при любой раскладке), а пока
    // ничего не набрано — по тому, что знает SDDM. Его флаг бывает
    // мёртвым: под Wayland-грейтером он может не обновляться
    property var capsTyped: null        // null — ещё не понятно по вводу
    readonly property bool capsLed: keyboard.capsLock
    readonly property bool caps: capsTyped !== null ? capsTyped : capsLed
    onCapsLedChanged: capsTyped = null

    // Вызывается на каждое нажатие в поле пароля
    function noteKey(event) {
        if (event.key === Qt.Key_CapsLock) {
            if (capsTyped !== null)
                capsTyped = !capsTyped
            return
        }
        const t = event.text
        if (t.length !== 1 || t.toLowerCase() === t.toUpperCase())
            return      // не буква
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0
        capsTyped = (t === t.toUpperCase()) !== shift
    }

    // Пользователи и сессии: роли моделей SDDM читаем через Instantiator
    property int userIndex: Math.max(0, userModel.lastIndex)
    property int sessionIndex: Math.max(0, sessionModel.lastIndex)
    readonly property var user: users.count > 0 ? users.objectAt(userIndex) : null
    readonly property var session: sessions.count > 0 ? sessions.objectAt(sessionIndex) : null
    readonly property string userName: user?.name ?? userModel.lastUser ?? ""
    readonly property string userTitle: user?.realName || userName

    Instantiator {
        id: users
        model: userModel
        delegate: QtObject {
            required property string name
            required property string realName
            required property string icon
            required property bool needsPassword
        }
    }

    Instantiator {
        id: sessions
        model: sessionModel
        delegate: QtObject {
            required property string name
            required property string comment
        }
    }

    function cycle(n, i, d) {
        return n > 0 ? (i + d + n) % n : 0
    }
    function switchUser(d) {
        userIndex = cycle(users.count, userIndex, d)
        text = ""
        error = ""
        input.forceActiveFocus()
    }
    function switchSession(d) {
        sessionIndex = cycle(sessions.count, sessionIndex, d)
        input.forceActiveFocus()
    }

    function submit() {
        if (busy || userName === "")
            return
        if (text === "" && (user?.needsPassword ?? true))
            return
        busy = true
        error = ""
        sddm.login(userName, text, sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false
            root.text = ""
            root.error = "Неверный пароль"
            root.fails++
        }
        function onLoginSucceeded() {
            root.busy = false
            root.error = ""
        }
    }

    // Часы
    property date now: new Date()
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }

    component Tile: Rectangle {
        id: tile
        // Порядок появления: плитки выпрыгивают пружиной одна за другой
        property int order: 0
        radius: 22
        color: Theme.crust
        border.width: 1
        border.color: Theme.surface0
        clip: true

        scale: 0.92
        opacity: 0
        Component.onCompleted: appear.start()
        SequentialAnimation {
            id: appear
            PauseAnimation { duration: tile.order * 60 }
            ParallelAnimation {
                Spring { target: tile; property: "scale"; to: 1; epsilon: 0.002 }
                NumberAnimation { target: tile; property: "opacity"; to: 1; duration: 180 }
            }
        }
    }

    component Btn: Text {
        id: btn
        signal pressed()
        property color hoverColor: Theme.text
        width: 34; height: 34
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.font
        font.pixelSize: 20
        color: ma.containsMouse ? hoverColor : Theme.subtext0
        scale: ma.pressed ? 0.85 : 1
        Behavior on scale { Spring { epsilon: 0.002 } }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                btn.pressed()
                input.forceActiveFocus()
            }
        }
    }

    component Badge: Rectangle {
        id: badge
        property alias text: label.text
        property color fg: Theme.lavender
        signal clicked()
        width: label.implicitWidth + 22
        height: 28
        radius: 14
        color: Theme.alpha(fg, badgeMa.containsMouse ? 0.22 : 0.14)

        Text {
            id: label
            anchors.centerIn: parent
            font.family: Theme.font
            font.pixelSize: 12
            font.bold: true
            color: parent.fg
        }
        MouseArea {
            id: badgeMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                badge.clicked()
                input.forceActiveFocus()
            }
        }
    }

    // Фон: размытые обои из theme.conf, а без них — градиент темы.
    // Сверху лёгкое зерно
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.base }
            GradientStop { position: 1; color: Theme.crust }
        }
    }

    Image {
        id: wall
        anchors.fill: parent
        visible: false
        source: root.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        // Всё равно размываем — полное разрешение ни к чему
        sourceSize: Qt.size(Math.ceil(root.width / 2), Math.ceil(root.height / 2))
    }
    MultiEffect {
        anchors.fill: parent
        source: wall
        visible: wall.status === Image.Ready
        blurEnabled: root.wallpaperBlur > 0
        blur: 1
        blurMax: root.wallpaperBlur
    }
    Rectangle {
        anchors.fill: parent
        visible: wall.status === Image.Ready
        color: Theme.crust
        opacity: root.wallpaperDim
    }
    // Зерно против полос в размытии: одна точка шума — ровно один
    // физический пиксель, иначе при масштабе экрана оно мылится и крупнеет
    Image {
        readonly property real dpr: Screen.devicePixelRatio
        width: parent.width * dpr
        height: parent.height * dpr
        scale: 1 / dpr
        transformOrigin: Item.TopLeft
        source: "assets/noise.png"
        fillMode: Image.Tile
        smooth: false
        opacity: Dither.noise
    }

    // Клик мимо плиток возвращает фокус в поле пароля
    MouseArea {
        anchors.fill: parent
        onClicked: input.forceActiveFocus()
    }

    // Невидимый ввод пароля: точки рисуем сами
    TextInput {
        id: input
        width: 1; height: 1
        opacity: 0
        focus: true
        echoMode: TextInput.Password
        enabled: !root.busy
        onTextChanged: if (root.text !== text) root.text = text
        Keys.onReturnPressed: root.submit()
        Keys.onEnterPressed: root.submit()
        Keys.onEscapePressed: text = ""
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                root.switchUser(event.key === Qt.Key_Tab ? 1 : -1)
                event.accepted = true
                return
            }
            root.noteKey(event)
            event.accepted = false      // сам текст пусть вводит TextInput
        }

        Connections {
            target: root
            function onTextChanged() {
                if (input.text !== root.text)
                    input.text = root.text
            }
        }
    }
    Component.onCompleted: input.forceActiveFocus()

    Row {
        anchors.centerIn: parent
        spacing: root.gap

        // ===== Левая колонка =====
        Column {
            spacing: root.gap

            // --- Аватар и пользователь ---
            // avatarModel из theme.conf в 3D, если он есть и у грейтера есть
            // QtQuick3D; иначе иконка пользователя от SDDM; иначе инициал
            Tile {
                order: 0
                width: root.colW
                height: root.colW

                Loader {
                    id: model3d
                    anchors.fill: parent
                    readonly property bool shown: status === Loader.Ready && item.ready
                    active: root.avatarModel !== ""
                    visible: shown
                    source: "Avatar3D.qml"
                    onLoaded: {
                        // .qml — сцена от balsam, с анимациями; иначе сам файл модели
                        item.model = Qt.binding(() => root.avatarModel.toString().endsWith(".qml") ? "" : root.avatarModel)
                        item.scene = Qt.binding(() => root.avatarModel.toString().endsWith(".qml") ? root.avatarModel : "")
                        item.modelSize = Qt.binding(() => root.modelSize)
                        item.spinMs = Qt.binding(() => root.spinMs)
                        item.animation = Qt.binding(() => root.avatarAnimation)
                        item.animationSpeed = Qt.binding(() => root.animationSpeed)
                    }
                    onStatusChanged: {
                        if (status === Loader.Error)
                            console.warn("greeter: 3D-ава не загрузилась — у грейтера нет модуля QtQuick3D?")
                    }
                }

                // Круглая аватарка: картинка, вырезанная маской-кругом
                Rectangle {
                    id: face
                    anchors.centerIn: parent
                    width: 160; height: 160
                    radius: 80
                    color: Theme.surface0
                    visible: !model3d.shown

                    Image {
                        id: faceImg
                        anchors.fill: parent
                        visible: false
                        source: root.path(root.user?.icon ?? "")
                        sourceSize: Qt.size(320, 320)
                        fillMode: Image.PreserveAspectCrop
                    }
                    Rectangle {
                        id: faceMask
                        anchors.fill: parent
                        radius: width / 2
                        visible: false
                        layer.enabled: true
                        layer.smooth: true
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: faceImg
                        visible: faceImg.status === Image.Ready
                        maskEnabled: true
                        maskSource: faceMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1
                    }
                    GradientText {
                        anchors.centerIn: parent
                        visible: faceImg.status !== Image.Ready
                        display: true
                        pixelSize: 72
                        text: root.userName.charAt(0).toUpperCase()
                    }
                }

                // Пользователь сменился — аватар пружинит
                Connections {
                    target: root
                    function onUserIndexChanged() {
                        face.scale = 0.8
                        faceSpring.restart()
                    }
                }
                Spring { id: faceSpring; target: face; property: "scale"; to: 1; epsilon: 0.002 }

                // Хост — слева сверху, питание — справа сверху
                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 16
                    anchors.topMargin: 22
                    text: sddm.hostName
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: Theme.overlay1
                }
                Row {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10

                    Btn {
                        visible: sddm.canSuspend
                        text: "󰤄"
                        onPressed: sddm.suspend()
                    }
                    Btn {
                        visible: sddm.canReboot
                        text: "󰜉"
                        onPressed: sddm.reboot()
                    }
                    Btn {
                        visible: sddm.canPowerOff
                        text: "󰐥"
                        hoverColor: Theme.red
                        onPressed: sddm.powerOff()
                    }
                }

                // Выбор пользователя: стрелки по бокам (и Tab / Shift+Tab)
                Btn {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 10
                    visible: users.count > 1
                    text: "󰅁"
                    onPressed: root.switchUser(-1)
                }
                Btn {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 10
                    visible: users.count > 1
                    text: "󰅂"
                    onPressed: root.switchUser(1)
                }

                Text {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 16
                    text: root.userTitle
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: Theme.overlay1
                }
                Text {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 16
                    visible: users.count > 1
                    text: (root.userIndex + 1) + " / " + users.count
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: Theme.surface2
                }
            }

            // --- Сессия ---
            // Устроена как плитка музыки в локе: значок, название с
            // описанием и стрелки, как «предыдущий/следующий трек»
            Tile {
                order: 2
                width: root.colW
                height: root.sessionH

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    spacing: 12

                    Rectangle {
                        width: 64; height: 64
                        radius: 14
                        color: Theme.surface0
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "󰍹"
                            font.family: Theme.font
                            font.pixelSize: 26
                            color: Theme.mauve
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.colW - 16 - 64 - 12 - (sessionControls.visible ? sessionControls.width + 12 : 0) - 16
                        spacing: 3

                        // Длинное — колесом, как в попауте музыки
                        ScrollClip {
                            id: sessionTitle
                            maxWidth: parent.width
                            fadeColor: Theme.crust

                            GradientText {
                                pixelSize: 14
                                text: root.session?.name ?? "Сессия"
                                onTextChanged: sessionTitle.reset()
                            }
                        }
                        ScrollClip {
                            id: sessionComment
                            visible: (root.session?.comment ?? "") !== ""
                            maxWidth: parent.width
                            fadeColor: Theme.crust

                            Text {
                                text: root.session?.comment ?? ""
                                font.family: Theme.font
                                font.pixelSize: 11
                                color: Theme.subtext1
                                onTextChanged: sessionComment.reset()
                            }
                        }
                    }

                    Row {
                        id: sessionControls
                        visible: sessions.count > 1
                        anchors.verticalCenter: parent.verticalCenter

                        Btn {
                            text: "󰒮"
                            onPressed: root.switchSession(-1)
                        }
                        Btn {
                            text: "󰒭"
                            onPressed: root.switchSession(1)
                        }
                    }
                }
            }
        }

        // ===== Правая колонка =====
        Column {
            spacing: root.gap

            // --- Часы ---
            Tile {
                order: 1
                width: root.colW
                height: root.clockH

                Column {
                    anchors.centerIn: parent
                    spacing: 6

                    GradientText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        display: true
                        pixelSize: 96
                        outlineWidth: 4
                        outlineColor: Theme.base
                        text: root.now.toLocaleString(root.locale, "HH:mm")
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            const d = root.now.toLocaleString(root.locale, "dddd, d MMMM yyyy")
                            return d.charAt(0).toUpperCase() + d.slice(1)
                        }
                        font.family: Theme.font
                        font.pixelSize: 13
                        color: Theme.subtext0
                    }
                }
            }

            // --- Пароль ---
            Tile {
                order: 3
                width: root.colW
                height: root.totalH - root.clockH - root.gap

                // Раскладка — слева сверху, клик переключает. Смена — пинок:
                // значок подпрыгивает и пружинит обратно
                Badge {
                    id: langBadge
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 18
                    readonly property var layout: keyboard.layouts[keyboard.currentLayout]
                    text: "󰌌  " + (layout?.shortName?.toUpperCase() || "—")
                    fg: Theme.lavender
                    onClicked: {
                        const n = keyboard.layouts.length
                        if (n > 1)
                            keyboard.currentLayout = (keyboard.currentLayout + 1) % n
                    }

                    property real kick: 0
                    transform: Translate { y: -langBadge.kick }
                    scale: 1 + langBadge.kick / 40

                    SpringAnimation {
                        id: kickAnim
                        target: langBadge; property: "kick"; to: 0
                        spring: Motion.kickSpring; damping: Motion.kickDamping; epsilon: 0.05
                    }
                    Connections {
                        target: keyboard
                        function onCurrentLayoutChanged() {
                            langBadge.kick = 8
                            kickAnim.restart()
                        }
                    }
                }

                // Caps Lock — справа сверху, выпрыгивает пружиной
                Badge {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 18
                    text: "󰘲  CAPS"
                    fg: Theme.peach
                    scale: root.caps ? 1 : 0
                    visible: scale > 0.01
                    Behavior on scale { Spring { epsilon: 0.002 } }
                }

                Item {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 14
                    anchors.margins: 18
                    height: 50

                    Rectangle {
                        id: field
                        width: parent.width
                        height: parent.height
                        radius: 25
                        color: Theme.base
                        border.width: 2
                        border.color: root.error !== "" ? Theme.red
                                    : root.busy ? Theme.surface2 : Theme.mauve
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        // Тряска при ошибке: пинок вбок, пружина почти без затухания
                        property real shake: 0
                        x: shake
                        SpringAnimation {
                            id: shakeAnim
                            target: field; property: "shake"; to: 0
                            spring: Motion.shakeSpring; damping: Motion.shakeDamping; epsilon: 0.2
                        }
                        Connections {
                            target: root
                            function onFailsChanged() {
                                field.shake = Motion.shakeDistance
                                shakeAnim.restart()
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: root.text === "" && !root.busy
                            text: root.error !== "" ? root.error
                                : (root.user?.needsPassword ?? true) ? "Пароль" : "Без пароля — просто ⏎"
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.italic: true
                            color: root.error !== "" ? Theme.red : Theme.overlay0
                        }

                        // Точки: каждая выпрыгивает пружиной. Модель меняем по
                        // одной точке — целочисленная модель Repeater'а
                        // пересоздавала бы все точки на каждое нажатие
                        ListModel { id: dots }

                        function syncDots() {
                            const n = Math.min(root.text.length, 20)
                            while (dots.count < n) dots.append({})
                            while (dots.count > n) dots.remove(dots.count - 1)
                        }
                        Component.onCompleted: syncDots()
                        Connections {
                            target: root
                            function onTextChanged() { field.syncDots() }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 7
                            // Остальные точки плавно отъезжают, давая место новой
                            move: Transition { Spring { properties: "x"; bouncy: false } }

                            Repeater {
                                model: dots

                                Rectangle {
                                    id: dot
                                    required property int index
                                    width: 9; height: 9
                                    radius: 4.5
                                    color: Theme.mix(Theme.gradStart, Theme.gradEnd,
                                                     dots.count > 1 ? index / (dots.count - 1) : 0)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    scale: 0
                                    Component.onCompleted: scale = 1
                                    Behavior on scale { Spring { epsilon: 0.002 } }

                                    // Пока SDDM проверяет — точки волной пульсируют
                                    SequentialAnimation on opacity {
                                        running: root.busy
                                        loops: Animation.Infinite
                                        alwaysRunToEnd: true
                                        PauseAnimation { duration: Math.max(0, dot.index) * 40 }  // у удаляемой точки index = -1
                                        NumberAnimation { to: 0.3; duration: 300 }
                                        NumberAnimation { to: 1; duration: 300 }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 18
                    text: users.count > 1 ? "⏎ войти  ·  Esc очистить  ·  Tab другой"
                                          : "⏎ войти   ·   Esc очистить"
                    font.family: Theme.font
                    font.pixelSize: 11
                    color: Theme.overlay0
                }
            }
        }
    }
}
