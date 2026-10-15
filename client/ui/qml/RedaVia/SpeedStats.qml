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
            Layout.fillWidth: true
            text: "↓  Download"
            font { family: Theme.fontFamily; pixelSize: 12 }
            color: Theme.textLabel
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            Layout.fillWidth: true
            text: root.downloadSpeed
            font { family: Theme.fontFamily; pixelSize: 18; bold: true }
            color: Theme.textPrimary
            horizontalAlignment: Text.AlignHCenter
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
        spacing: 11
        Text {
            Layout.fillWidth: true
            text: "↑  Upload"
            font { family: Theme.fontFamily; pixelSize: 12 }
            color: Theme.textLabel
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            Layout.fillWidth: true
            text: root.uploadSpeed
            font { family: Theme.fontFamily; pixelSize: 18; bold: true }
            color: Theme.textPrimary
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
