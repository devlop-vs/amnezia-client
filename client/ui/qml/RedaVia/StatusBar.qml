import QtQuick 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: 40
    implicitHeight: 40

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 26
        anchors.rightMargin: 26
        anchors.topMargin: 18

        Text {
            text: "9:41"
            font { family: Theme.fontFamily; pixelSize: 14; bold: true }
            color: Theme.textPrimary
        }

        Item { Layout.fillWidth: true }

        Text {
            text: "▮▮▮  ◉  ▰"
            font { family: Theme.fontFamily; pixelSize: 11; weight: Font.Medium }
            color: Theme.textPrimary
        }
    }
}
