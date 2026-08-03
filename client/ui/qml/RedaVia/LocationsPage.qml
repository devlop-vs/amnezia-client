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

    property int activeFilter: 0
    signal serverSelected(string country)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        //StatusBar { Layout.fillWidth: true }

        // Title row
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.topMargin: 10

            Item { Layout.fillWidth: true }
            Text {
                text: "Locations"
                font { family: Theme.fontFamily; pixelSize: 20; bold: true }
                color: Theme.textPrimary
                Layout.alignment: Qt.AlignHCenter
            }
            Item { Layout.fillWidth: true }
            Text {
                text: "⌕"
                font { family: Theme.fontFamily; pixelSize: 25 }
                color: Theme.textPrimary
            }
        }

        // Search bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.topMargin: 16
            radius: 17
            color: "#0e1a2f"
            border { width: 1; color: Theme.borderColor }

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                verticalAlignment: Text.AlignVCenter
                font { family: Theme.fontFamily; pixelSize: 13 }
                color: Theme.textPrimary

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "⌕   Search for country or city"
                    font: parent.font
                    color: Theme.textSubtle
                    visible: !parent.text && !parent.activeFocus
                }
            }
        }

        // Filter tabs
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.topMargin: 20
            spacing: 10

            Repeater {
                model: ["All", "Streaming", "Gaming", "Favorites"]

                Rectangle {
                    Layout.preferredHeight: 36
                    Layout.preferredWidth: filterLabel.implicitWidth + 32
                    radius: 18
                    color: root.activeFilter === index ? Theme.primaryGreen : Theme.cardBackground

                    Behavior on color { ColorAnimation { duration: 200 } }

                    scale: filterMouse.pressed ? 0.93 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    Text {
                        id: filterLabel
                        anchors.centerIn: parent
                        text: modelData
                        font { family: Theme.fontFamily; pixelSize: 12; weight: Font.Medium }
                        color: root.activeFilter === index ? Theme.background : Theme.textPrimary
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    MouseArea {
                        id: filterMouse
                        anchors.fill: parent
                        onClicked: root.activeFilter = index
                    }
                }
            }
        }

        // Server list
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.topMargin: 16
            Layout.bottomMargin: root.height - Theme.tabBarY
            spacing: 10
            clip: true

            model: ListModel {
                ListElement { flag: "🇬🇧"; country: "United Kingdom"; locations: "16 Locations"; ping: "16 ms"; pingColor: "#35e76f" }
                ListElement { flag: "🇺🇸"; country: "United States"; locations: "16 Locations"; ping: "167 ms"; pingColor: "#ff5353" }
                ListElement { flag: "🇫🇷"; country: "France"; locations: "19 Locations"; ping: "67 ms"; pingColor: "#35e76f" }
                ListElement { flag: "🇩🇪"; country: "Germany"; locations: "19 Locations"; ping: "67 ms"; pingColor: "#35e76f" }
                ListElement { flag: "🇨🇦"; country: "Canada"; locations: "16 Locations"; ping: "89 ms"; pingColor: "#ffd21e" }
                ListElement { flag: "🇸🇬"; country: "Singapore"; locations: "12 Locations"; ping: "38 ms"; pingColor: "#35e76f" }
                ListElement { flag: "🇯🇵"; country: "Japan"; locations: "11 Locations"; ping: "65 ms"; pingColor: "#35e76f" }
            }

            delegate: Rectangle {
                width: ListView.view.width
                height: 62
                radius: Theme.buttonRadius
                color: Theme.cardBackground

                scale: delegateMouse.pressed ? 0.97 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }

                // Fade-in on creation
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    Text {
                        text: model.flag
                        font.pixelSize: 27
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: model.country
                            font { family: Theme.fontFamily; pixelSize: 15; weight: Font.DemiBold }
                            color: Theme.textPrimary
                        }
                        Text {
                            text: model.locations
                            font { family: Theme.fontFamily; pixelSize: 11 }
                            color: Theme.textSecondary
                        }
                    }

                    Text {
                        text: model.ping
                        font { family: Theme.fontFamily; pixelSize: 12; weight: Font.Medium }
                        color: model.pingColor
                    }

                    Text {
                        text: "▥"
                        font { family: Theme.fontFamily; pixelSize: 16 }
                        color: Theme.primaryGreen
                    }

                    Text {
                        text: "☆"
                        font { family: Theme.fontFamily; pixelSize: 18 }
                        color: Theme.textSecondary
                    }
                }

                MouseArea {
                    id: delegateMouse
                    anchors.fill: parent
                    onClicked: root.serverSelected(model.country)
                }
            }
        }
    }

    BottomTabBar { currentIndex: 1 }
}
