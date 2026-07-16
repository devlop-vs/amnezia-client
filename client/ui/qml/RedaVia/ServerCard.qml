import QtQuick 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: 84
    Layout.leftMargin: 28
    Layout.rightMargin: 28
    radius: Theme.cardRadius
    color: Theme.cardBackground

    property string flag: "🇬🇧"
    property string country: "Unknown"
    property string ipAddress: ""
    signal clicked()

    scale: cardMouse.pressed ? 0.98 : 1.0
    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 25
        anchors.rightMargin: 20
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: 20
            color: Theme.accentBlueDark
            Text {
                anchors.centerIn: parent
                text: root.flag
                font.pixelSize: 27
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                text: root.country
                font { family: Theme.fontFamily; pixelSize: 16; weight: Font.DemiBold }
                color: Theme.textPrimary
            }
            Text {
                text: root.ipAddress
                font { family: Theme.fontFamily; pixelSize: 12 }
                color: Theme.textSecondary
                visible: text.length > 0
            }
        }

        Text {
            text: "›"
            font { family: Theme.fontFamily; pixelSize: 28 }
            color: Theme.textPrimary
        }
    }

    MouseArea {
        id: cardMouse
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
