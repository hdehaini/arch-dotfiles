// arch-dotfiles SDDM theme (Qt 6).
// Blurred wallpaper, big clock, a login card in the middle, session picker
// bottom-left and Sleep / Restart / Shut down bottom-right.
// Settings come from theme.conf (written by sddm/install.sh).

import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: surface

    // --- settings (theme.conf) ----------------------------------------------
    readonly property color accent:   config.accent   ? config.accent   : "#c7bfff"
    readonly property color onAccent: config.onAccent ? config.onAccent : "#2f295f"
    readonly property color surface:  config.surface  ? config.surface  : "#131318"
    readonly property color textColor: config.text    ? config.text     : "#e5e1e9"
    readonly property color errorColor: config.error  ? config.error    : "#ffb4ab"
    readonly property string fontName: config.font   ? config.font     : "Inter"
    readonly property string iconFont: "Symbols Nerd Font"
    readonly property bool clock24: config.clock24 === "true"

    // --- users and sessions ---------------------------------------------------
    // Hidden repeaters give access to the models' fields by index.
    Repeater {
        id: users
        model: userModel
        delegate: Item {
            required property string name
            required property string realName
            required property string icon
        }
    }
    Repeater {
        id: sessions
        model: sessionModel
        delegate: Item {
            required property string name
        }
    }

    property int userIndex: 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0

    Component.onCompleted: {
        for (let i = 0; i < users.count; i++) {
            if (users.itemAt(i) && users.itemAt(i).name === userModel.lastUser) userIndex = i
        }
        password.forceActiveFocus()
    }

    readonly property var currentUser: users.count > 0 ? users.itemAt(userIndex) : null
    readonly property string userName: currentUser ? currentUser.name : userModel.lastUser
    readonly property string displayName: currentUser && currentUser.realName !== "" ? currentUser.realName : userName
    readonly property string sessionName: sessions.count > 0 && sessions.itemAt(sessionIndex) ? sessions.itemAt(sessionIndex).name : ""

    function login() {
        message.text = ""
        sddm.login(userName, password.text, sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            password.text = ""
            message.text = "Wrong password, try again"
            shake.start()
            password.forceActiveFocus()
        }
    }

    // --- background -----------------------------------------------------------
    Image {
        id: wallpaper
        anchors.fill: parent
        source: config.background ? config.background : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        visible: wallpaper.status === Image.Ready
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        saturation: 0.1
    }
    // Darken toward the bottom so text stays readable on any picture; with
    // no picture this is the whole background.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, wallpaper.status === Image.Ready ? 0.25 : 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, wallpaper.status === Image.Ready ? 0.60 : 0.35) }
        }
    }

    // --- clock ----------------------------------------------------------------
    property date now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.14
        spacing: 2
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            // Qt's "h" is 24-hour unless AM/PM is shown, so do 12-hour by hand.
            text: root.clock24 ? Qt.formatTime(root.now, "HH:mm")
                               : ((root.now.getHours() % 12) || 12) + Qt.formatTime(root.now, ":mm")
            font.family: root.fontName
            font.pixelSize: 128
            font.weight: Font.Light
            color: root.textColor
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.now, "dddd, MMMM d")
            font.family: root.fontName
            font.pixelSize: 26
            color: Qt.alpha(root.textColor, 0.85)
        }
    }

    // --- login card -----------------------------------------------------------
    Item {
        id: card
        width: 380
        height: cardColumn.height
        x: (root.width - width) / 2
        y: root.height * 0.50

        SequentialAnimation {
            id: shake
            loops: 1
            NumberAnimation { target: card; property: "x"; to: (root.width - card.width) / 2 - 14; duration: 50 }
            NumberAnimation { target: card; property: "x"; to: (root.width - card.width) / 2 + 14; duration: 70 }
            NumberAnimation { target: card; property: "x"; to: (root.width - card.width) / 2 - 8;  duration: 60 }
            NumberAnimation { target: card; property: "x"; to: (root.width - card.width) / 2;      duration: 50 }
        }

        Column {
            id: cardColumn
            width: parent.width
            spacing: 16

            // Avatar: the user's picture if SDDM has one, else their initial.
            Item {
                width: 104
                height: 104
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: root.accent
                    Text {
                        anchors.centerIn: parent
                        text: root.displayName.length > 0 ? root.displayName.charAt(0).toUpperCase() : "?"
                        font.family: root.fontName
                        font.pixelSize: 46
                        font.weight: Font.DemiBold
                        color: root.onAccent
                    }
                }
                Image {
                    id: face
                    anchors.fill: parent
                    source: root.currentUser && root.currentUser.icon ? "file://" + root.currentUser.icon : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                }
                Rectangle {
                    id: faceMask
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                    layer.enabled: true
                }
                MultiEffect {
                    anchors.fill: parent
                    source: face
                    visible: face.status === Image.Ready
                    maskEnabled: true
                    maskSource: faceMask
                }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.color: Qt.alpha(root.textColor, 0.35)
                    border.width: 2
                }
            }

            // Name; click to switch user when there's more than one.
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.displayName
                font.family: root.fontName
                font.pixelSize: 24
                font.weight: Font.Medium
                color: root.textColor
                MouseArea {
                    anchors.fill: parent
                    enabled: users.count > 1
                    cursorShape: users.count > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        root.userIndex = (root.userIndex + 1) % users.count
                        password.text = ""
                        password.forceActiveFocus()
                    }
                }
            }

            TextField {
                id: password
                width: 320
                height: 48
                anchors.horizontalCenter: parent.horizontalCenter
                echoMode: TextInput.Password
                passwordCharacter: "•"
                placeholderText: "Password"
                placeholderTextColor: Qt.alpha(root.textColor, 0.55)
                color: root.textColor
                font.family: root.fontName
                font.pixelSize: 16
                leftPadding: 22
                rightPadding: 52
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true
                focus: true
                background: Rectangle {
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.10)
                    border.width: 1
                    border.color: password.activeFocus ? root.accent : Qt.rgba(1, 1, 1, 0.20)
                }
                Keys.onReturnPressed: root.login()
                Keys.onEnterPressed: root.login()

                // Arrow button inside the field.
                Rectangle {
                    width: 38
                    height: 38
                    radius: 19
                    anchors.right: parent.right
                    anchors.rightMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    color: arrowArea.containsMouse ? Qt.lighter(root.accent, 1.1) : root.accent
                    Text {
                        anchors.centerIn: parent
                        text: "\u{f0054}"          // nf-md-arrow_right
                        font.family: root.iconFont
                        font.pixelSize: 18
                        color: root.onAccent
                    }
                    MouseArea {
                        id: arrowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.login()
                    }
                }
            }

            Text {
                id: message
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: ""
                font.family: root.fontName
                font.pixelSize: 14
                color: root.errorColor
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: keyboard.capsLock
                text: "Caps Lock is on"
                font.family: root.fontName
                font.pixelSize: 14
                color: Qt.alpha(root.textColor, 0.8)
            }
        }
    }

    // --- bottom left: machine and session ------------------------------------
    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 32
        spacing: 22

        Row {
            spacing: 8
            visible: sddm.hostName !== ""
            Text {
                text: "\u{f0322}"                    // nf-md-laptop
                font.family: root.iconFont
                font.pixelSize: 18
                color: Qt.alpha(root.textColor, 0.8)
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: sddm.hostName
                font.family: root.fontName
                font.pixelSize: 15
                color: Qt.alpha(root.textColor, 0.8)
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Click to cycle through installed sessions (Hyprland, ...).
        Rectangle {
            height: 34
            width: sessionRow.width + 28
            radius: 17
            color: sessionArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
            visible: sessions.count > 0
            Row {
                id: sessionRow
                anchors.centerIn: parent
                spacing: 8
                Text {
                    text: "\u{f0379}"                // nf-md-monitor
                    font.family: root.iconFont
                    font.pixelSize: 16
                    color: root.textColor
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: root.sessionName
                    font.family: root.fontName
                    font.pixelSize: 15
                    color: root.textColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MouseArea {
                id: sessionArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: sessions.count > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (sessions.count > 1) root.sessionIndex = (root.sessionIndex + 1) % sessions.count
            }
        }
    }

    // --- bottom right: Sleep / Restart / Shut down ---------------------------
    component PowerButton: Rectangle {
        id: button
        property string icon
        property string label
        signal activated
        width: 52
        height: 52
        radius: 26
        color: area.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
        Text {
            anchors.centerIn: parent
            text: button.icon
            font.family: root.iconFont
            font.pixelSize: 22
            color: root.textColor
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: 8
            text: button.label
            visible: area.containsMouse
            font.family: root.fontName
            font.pixelSize: 13
            color: root.textColor
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.activated()
        }
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 32
        spacing: 14

        PowerButton {
            icon: "\u{f0904}"                        // nf-md-power_sleep
            label: "Sleep"
            visible: sddm.canSuspend
            onActivated: sddm.suspend()
        }
        PowerButton {
            icon: "\u{f0709}"                        // nf-md-restart
            label: "Restart"
            visible: sddm.canReboot
            onActivated: sddm.reboot()
        }
        PowerButton {
            icon: "\u{f0425}"                        // nf-md-power
            label: "Shut down"
            visible: sddm.canPowerOff
            onActivated: sddm.powerOff()
        }
    }
}
