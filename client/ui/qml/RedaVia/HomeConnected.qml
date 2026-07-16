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

    signal disconnectPressed()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        StatusBar { Layout.fillWidth: true }

        TopBar {
            Layout.topMargin: 10
        }

        // Country flag + name
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 20
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 20
                color: Theme.accentBlueDark
                Text {
                    anchors.centerIn: parent
                    text: "🇬🇧"
                    font.pixelSize: 27
                }
            }

            Text {
                text: "United Kingdom"
                font { family: Theme.fontFamily; pixelSize: 17; weight: Font.DemiBold }
                color: Theme.textPrimary
            }
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

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 4
            text: "212.369.56.87"
            font { family: Theme.fontFamily; pixelSize: 14 }
            color: Theme.textSecondary
            horizontalAlignment: Text.AlignHCenter
        }

        // Power button
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 224
            Layout.topMargin: 8

            PowerButton {
                anchors.horizontalCenter: parent.horizontalCenter
                size: 164
                connected: true
                onClicked: root.disconnectPressed()
            }
        }

        // Connected status card
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 58
            Layout.leftMargin: 28
            Layout.rightMargin: 28
            radius: 20
            color: Theme.cardBackground

            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutQuad } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20

                Row {
                    spacing: 8
                    Rectangle {
                        width: 10; height: 10; radius: 5
                        color: Theme.primaryGreen
                        anchors.verticalCenter: parent.verticalCenter

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: 1000; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
                        }
                    }
                    Text {
                        text: "Connected"
                        font { family: Theme.fontFamily; pixelSize: 15; weight: Font.DemiBold }
                        color: Theme.primaryGreen
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "WireGuard"
                    font { family: Theme.fontFamily; pixelSize: 14 }
                    color: Theme.textMuted
                }
            }
        }

        SpeedStats {
            Layout.topMargin: 16
            downloadSpeed: "147.67 Mbps"
            uploadSpeed: "348.3 Mbps"
        }

        // Stats cards
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 28
            Layout.rightMargin: 28
            Layout.topMargin: 20
            spacing: 14

            Repeater {
                model: [
                    { label: "Ping", value: "16 ms" },
                    { label: "Protocol", value: "WG" },
                    { label: "Duration", value: "00:25:57" }
                ]

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 82
                    radius: Theme.buttonRadius
                    color: Theme.cardBackground

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.topMargin: 21
                        spacing: 15

                        Text {
                            text: modelData.label
                            font { family: Theme.fontFamily; pixelSize: 12 }
                            color: Theme.textMuted
                        }
                        Text {
                            text: modelData.value
                            font { family: Theme.fontFamily; pixelSize: 18; bold: true }
                            color: Theme.primaryGreen
                        }
                    }
                }
            }
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
