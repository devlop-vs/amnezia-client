import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    width: Theme.screenWidth
    height: Theme.screenHeight
    radius: Theme.screenRadius
    color: Theme.background
    clip: true

    signal getStartedClicked()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item { Layout.preferredHeight: 95 }

        // Logo circle
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 263

            Rectangle {
                id: outerCircle
                anchors.horizontalCenter: parent.horizontalCenter
                width: 263; height: 263; radius: 132
                color: Theme.accentBlue

                // Pulse animation
                SequentialAnimation on scale {
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.04; duration: 2000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 2000; easing.type: Easing.InOutSine }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 177; height: 177; radius: 89
                    color: Theme.cardBackgroundAlt

                    Text {
                        anchors.centerIn: parent
                        text: "◈"
                        font { family: Theme.fontFamily; pixelSize: 88 }
                        color: Theme.primaryGreen
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 30
            Layout.rightMargin: 30
            text: "Private by default"
            font { family: Theme.fontFamily; pixelSize: 30; bold: true }
            color: Theme.textPrimary
            horizontalAlignment: Text.AlignHCenter

            opacity: 0; y: 20
            Component.onCompleted: { opacity = 1; y = 0 }
            Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutQuad } }
            Behavior on y { NumberAnimation { duration: 600; easing.type: Easing.OutQuad } }
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 45
            Layout.rightMargin: 45
            Layout.topMargin: 16
            text: "Secure your connection with one tap and browse without limits."
            font { family: Theme.fontFamily; pixelSize: 15 }
            color: Theme.textSecondary
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap

            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.OutQuad } }
        }

        Item { Layout.fillHeight: true }

        PrimaryButton {
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.bottomMargin: 120
            text: "Get started"
            onClicked: root.getStartedClicked()
        }
    }
}
