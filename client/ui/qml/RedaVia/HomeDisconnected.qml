import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects

Rectangle {
    id: root
    width: Theme.screenWidth
    height: Theme.screenHeight
    radius: Theme.screenRadius
    color: Theme.background
    clip: true

    signal connectPressed()
    signal serverChangeRequested()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        StatusBar { Layout.fillWidth: true }

        TopBar {
            Layout.topMargin: 10
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 20
            text: "Connecting Time"
            font { family: Theme.fontFamily; pixelSize: 14 }
            color: Theme.textBody
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 8
            text: "00:25:57"
            font { family: Theme.fontFamily; pixelSize: 48; bold: true }
            color: Theme.textPrimary
            horizontalAlignment: Text.AlignHCenter

            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutQuad } }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 224
            Layout.topMargin: 20

            PowerButton {
                anchors.horizontalCenter: parent.horizontalCenter
                connected: false
                onClicked: root.connectPressed()
            }
        }

        ServerCard {
            Layout.topMargin: 16
            flag: "🇬🇧"
            country: "United Kingdom"
            ipAddress: "212.369.56.87"
            onClicked: root.serverChangeRequested()
        }

        SpeedStats {
            Layout.topMargin: 20
            downloadSpeed: "147.67 Mbps"
            uploadSpeed: "348.3 Mbps"
        }

        Item { Layout.fillHeight: true }

        // Planet earth
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 335
            Layout.leftMargin: 5

            Image {
                id: earthImage
                anchors.fill: parent
                source: "assets/earth-background.png"
                fillMode: Image.PreserveAspectCrop
                visible: false
                smooth: true
            }

            Rectangle {
                id: earthMask
                anchors.fill: parent
                visible: false
            }

            OpacityMask {
                anchors.fill: earthImage
                source: earthImage
                maskSource: earthMask
            }
        }
    }

    BottomTabBar { currentIndex: 0 }
}
