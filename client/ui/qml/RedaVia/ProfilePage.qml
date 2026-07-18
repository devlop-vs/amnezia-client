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

    signal menuItemClicked(string item)

    onMenuItemClicked: function(item) {
        if (item === "Account") {
            var sv = root.StackView.view
            if (sv) {
                sv.push("qrc:/ui/qml/RedaVia/AccessPage.qml")
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        StatusBar { Layout.fillWidth: true }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 14
            text: "Profile"
            font { family: Theme.fontFamily; pixelSize: 24; bold: true }
            color: Theme.textPrimary
            horizontalAlignment: Text.AlignHCenter
        }

        // Avatar
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            Layout.topMargin: 20

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 100; height: 100; radius: 50
                color: Theme.accentBlue

                Text {
                    anchors.centerIn: parent
                    text: AuthController.isLoggedIn ? AuthController.userEmail.charAt(0).toUpperCase() : "?"
                    font { family: Theme.fontFamily; pixelSize: 27; bold: true }
                    color: Theme.textPrimary
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 16
            text: AuthController.isLoggedIn ? AuthController.userEmail.split("@")[0] : "Guest"
            font { family: Theme.fontFamily; pixelSize: 21; weight: Font.DemiBold }
            color: Theme.textPrimary
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 6
            text: AuthController.isLoggedIn ? AuthController.userEmail : "Sign in to your account"
            font { family: Theme.fontFamily; pixelSize: 13 }
            color: Theme.textSecondary
            horizontalAlignment: Text.AlignHCenter
        }

        // Menu items
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.topMargin: 24
            Layout.bottomMargin: root.height - Theme.tabBarY
            spacing: 8
            clip: true
            interactive: false

            model: ["Account", "Devices", "Protocol", "Auto Connect", "Kill Switch", "Language", "Appearance", "Help & About"]

            delegate: Rectangle {
                width: ListView.view.width
                height: 43
                radius: Theme.smallRadius
                color: menuMouse.containsMouse ? Qt.lighter(Theme.cardBackground, 1.15) : Theme.cardBackground

                Behavior on color { ColorAnimation { duration: 150 } }

                scale: menuMouse.pressed ? 0.97 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20

                    Text {
                        text: modelData
                        font { family: Theme.fontFamily; pixelSize: 14; weight: Font.Medium }
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "›"
                        font { family: Theme.fontFamily; pixelSize: 22 }
                        color: Theme.textSecondary
                    }
                }

                MouseArea {
                    id: menuMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.menuItemClicked(modelData)
                }
            }
        }
    }

    BottomTabBar { currentIndex: 3 }
}
