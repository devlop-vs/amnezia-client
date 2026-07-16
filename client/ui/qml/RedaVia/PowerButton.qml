import QtQuick 2.15

Item {
    id: root
    width: size
    height: size

    property int size: 168
    property bool connected: false
    signal clicked()

    Rectangle {
        id: glowOuter
        anchors.centerIn: parent
        width: root.size + 56
        height: width
        radius: width / 2
        color: Theme.primaryGreen
        opacity: root.connected ? 0.12 : 0
        visible: root.connected

        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
    }

    Rectangle {
        id: buttonBg
        anchors.fill: parent
        radius: width / 2
        color: root.connected ? Theme.connectedGlow : "#0a162a"
        border {
            width: root.connected ? 4 : 5
            color: root.connected ? Theme.primaryGreen : Theme.textPrimary
        }

        Behavior on color { ColorAnimation { duration: 400; easing.type: Easing.InOutQuad } }
        Behavior on border.color { ColorAnimation { duration: 400; easing.type: Easing.InOutQuad } }

        Rectangle {
            anchors.centerIn: parent
            width: root.size - 40
            height: width
            radius: width / 2
            color: root.connected ? Theme.connectedInner : "transparent"
            border {
                width: root.connected ? 3 : 0
                color: root.connected ? Theme.primaryGreen : "transparent"
            }
            visible: root.connected

            Behavior on color { ColorAnimation { duration: 400 } }
        }

        Text {
            anchors.centerIn: parent
            text: "⏻"
            font { family: Theme.fontFamily; pixelSize: 58 }
            color: Theme.textPrimary
        }
    }

    scale: mouseArea.pressed ? 0.93 : 1.0
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

    SequentialAnimation on rotation {
        id: connectAnim
        running: false
        NumberAnimation { from: 0; to: 5; duration: 80 }
        NumberAnimation { from: 5; to: -5; duration: 80 }
        NumberAnimation { from: -5; to: 0; duration: 80 }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        onClicked: {
            connectAnim.start()
            root.clicked()
        }
    }
}
