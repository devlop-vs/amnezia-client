import QtQuick 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root

    property alias text: label.text
    signal clicked()

    Layout.fillWidth: true
    Layout.preferredHeight: 58
    radius: Theme.buttonRadius
    color: Theme.primaryGreen

    scale: mouseArea.pressed ? 0.97 : 1.0
    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

    Text {
        id: label
        anchors.centerIn: parent
        font { family: Theme.fontFamily; pixelSize: 16; bold: true }
        color: Theme.background
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
