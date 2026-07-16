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

    signal signInClicked(string email, string password)
    signal forgotPasswordClicked()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item { Layout.preferredHeight: 100 }

        Text {
            Layout.fillWidth: true
            text: "Reda VPN"
            font { family: Theme.fontFamily; pixelSize: 30; bold: true }
            color: Theme.textPrimary
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 12
            text: "Welcome back"
            font { family: Theme.fontFamily; pixelSize: 14 }
            color: Theme.textSecondary
            horizontalAlignment: Text.AlignHCenter
        }

        // Email label
        Text {
            Layout.leftMargin: 24
            Layout.topMargin: 50
            text: "EMAIL"
            font { family: Theme.fontFamily; pixelSize: 12; weight: Font.Medium }
            color: Theme.textMuted
        }

        // Email input
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 58
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.topMargin: 8
            radius: Theme.inputRadius
            color: Theme.cardBackground
            border {
                width: emailInput.activeFocus ? 2 : 1
                color: emailInput.activeFocus ? Theme.primaryGreen : Theme.borderColor
            }
            Behavior on border.color { ColorAnimation { duration: 200 } }
            Behavior on border.width { NumberAnimation { duration: 200 } }

            TextInput {
                id: emailInput
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                verticalAlignment: Text.AlignVCenter
                font { family: Theme.fontFamily; pixelSize: 14 }
                color: Theme.textPrimary

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "name@example.com"
                    font: parent.font
                    color: Theme.textPlaceholder
                    visible: !parent.text && !parent.activeFocus
                }
            }
        }

        // Password label
        Text {
            Layout.leftMargin: 24
            Layout.topMargin: 24
            text: "PASSWORD"
            font { family: Theme.fontFamily; pixelSize: 12; weight: Font.Medium }
            color: Theme.textMuted
        }

        // Password input
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 58
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.topMargin: 8
            radius: Theme.inputRadius
            color: Theme.cardBackground
            border {
                width: passwordInput.activeFocus ? 2 : 1
                color: passwordInput.activeFocus ? Theme.primaryGreen : Theme.borderColor
            }
            Behavior on border.color { ColorAnimation { duration: 200 } }
            Behavior on border.width { NumberAnimation { duration: 200 } }

            TextInput {
                id: passwordInput
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                verticalAlignment: Text.AlignVCenter
                font { family: Theme.fontFamily; pixelSize: 14 }
                color: Theme.textPrimary
                echoMode: TextInput.Password

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "••••••••"
                    font: parent.font
                    color: Theme.textPlaceholder
                    visible: !parent.text && !parent.activeFocus
                }
            }
        }

        // Forgot password
        Text {
            Layout.alignment: Qt.AlignRight
            Layout.rightMargin: 20
            Layout.topMargin: 16
            text: "Forgot password?"
            font { family: Theme.fontFamily; pixelSize: 13; weight: Font.Medium }
            color: Theme.primaryGreen

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.forgotPasswordClicked()
            }
        }

        // Sign in button
        PrimaryButton {
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.topMargin: 24
            text: "Sign in"
            onClicked: root.signInClicked(emailInput.text, passwordInput.text)
        }

        Item { Layout.fillHeight: true }
    }
}
