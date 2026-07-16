import QtQuick 2.15
import QtQuick.Layouts 1.15

RowLayout {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: 38
    Layout.leftMargin: 26
    Layout.rightMargin: 20

    Text {
        text: "⌘"
        font { family: Theme.fontFamily; pixelSize: 28 }
        color: Theme.textPrimary
        Layout.alignment: Qt.AlignVCenter
    }

    Item { Layout.fillWidth: true }

    Rectangle {
        Layout.preferredWidth: 94
        Layout.preferredHeight: 38
        radius: 19
        color: Theme.cardBackgroundAlt

        Row {
            anchors.centerIn: parent
            spacing: 8
            Text {
                text: "♛"
                font { family: Theme.fontFamily; pixelSize: 14; bold: true }
                color: Theme.accentYellow
            }
            Text {
                text: "Premium"
                font { family: Theme.fontFamily; pixelSize: 13; weight: Font.Medium }
                color: Theme.textPrimary
            }
        }

        scale: premiumMouse.pressed ? 0.95 : 1.0
        Behavior on scale { NumberAnimation { duration: 100 } }

        MouseArea {
            id: premiumMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
        }
    }
}
