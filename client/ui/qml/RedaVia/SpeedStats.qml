import QtQuick 2.15
import QtQuick.Layouts 1.15

RowLayout {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: 70
    Layout.leftMargin: 28
    Layout.rightMargin: 28

    property string downloadSpeed: "0 Mbps"
    property string uploadSpeed: "0 Mbps"

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 11
        Text {
            text: "↓  Download"
            font { family: Theme.fontFamily; pixelSize: 12 }
            color: Theme.textLabel
        }
        Text {
            text: root.downloadSpeed
            font { family: Theme.fontFamily; pixelSize: 18; bold: true }
            color: Theme.textPrimary
        }
    }

    Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: 54
        Layout.alignment: Qt.AlignVCenter
        color: Theme.borderColor
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 24
        spacing: 11
        Text {
            text: "↑  Upload"
            font { family: Theme.fontFamily; pixelSize: 12 }
            color: Theme.textLabel
        }
        Text {
            text: root.uploadSpeed
            font { family: Theme.fontFamily; pixelSize: 18; bold: true }
            color: Theme.textPrimary
        }
    }
}
