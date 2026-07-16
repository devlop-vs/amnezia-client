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

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        StatusBar { Layout.fillWidth: true }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 14
            text: "Traffic"
            font { family: Theme.fontFamily; pixelSize: 24; bold: true }
            color: Theme.textPrimary
            horizontalAlignment: Text.AlignHCenter
        }

        // Chart card
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 260
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.topMargin: 24
            radius: Theme.cardRadius
            color: Theme.cardBackground

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 0

                Text {
                    text: "Realtime speed"
                    font { family: Theme.fontFamily; pixelSize: 15; weight: Font.DemiBold }
                    color: Theme.textPrimary
                }

                Item { Layout.preferredHeight: 24 }

                // Chart grid lines
                Repeater {
                    model: 5
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Theme.chartLine
                        }
                        Item { Layout.preferredHeight: 35 }
                    }
                }
            }
        }

        // Stats row
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.topMargin: 24
            spacing: 10

            Repeater {
                model: [
                    { label: "Today", value: "1.42 GB" },
                    { label: "This month", value: "36.8 GB" },
                    { label: "Duration", value: "12h 42m" }
                ]

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 96
                    radius: Theme.buttonRadius
                    color: Theme.cardBackground

                    // Staggered fade-in
                    opacity: 0
                    Component.onCompleted: opacity = 1
                    Behavior on opacity { NumberAnimation { duration: 400 + index * 150; easing.type: Easing.OutQuad } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.topMargin: 24
                        spacing: 17

                        Text {
                            text: modelData.label
                            font { family: Theme.fontFamily; pixelSize: 12 }
                            color: Theme.textSecondary
                        }
                        Text {
                            text: modelData.value
                            font { family: Theme.fontFamily; pixelSize: 17; bold: true }
                            color: Theme.textPrimary
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    BottomTabBar { currentIndex: 0 }
}
