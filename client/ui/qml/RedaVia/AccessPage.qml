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

    signal loginCompleted(string email)
    signal backClicked()

    property bool isLoading: false
    property string errorMessage: ""

    Connections {
        target: AuthController

        function onLoginSuccess(email) {
            root.isLoading = false
            root.loginCompleted(email)
            var sv = root.StackView.view
            if (sv && sv.depth > 1) {
                sv.pop()
            }
        }

        function onLoginFailed(error) {
            root.isLoading = false
            root.errorMessage = error
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Top bar with back button
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 50
            Layout.leftMargin: 16
            Layout.rightMargin: 16

            Rectangle {
                width: 40; height: 40; radius: 20
                color: backMouse.containsMouse ? Qt.lighter(Theme.cardBackground, 1.15) : Theme.cardBackground

                Text {
                    anchors.centerIn: parent
                    text: "\u2039"
                    font { family: Theme.fontFamily; pixelSize: 24 }
                    color: Theme.textPrimary
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        var sv = root.StackView.view
                        if (sv && sv.depth > 1) {
                            sv.pop()
                        } else {
                            root.backClicked()
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }

        Item { Layout.preferredHeight: 60 }

        // Logo / Title
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
            text: "Sign in to your account"
            font { family: Theme.fontFamily; pixelSize: 14 }
            color: Theme.textSecondary
            horizontalAlignment: Text.AlignHCenter
        }

        Item { Layout.preferredHeight: 50 }

        // Sign in with browser button
        PrimaryButton {
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            text: root.isLoading ? "Signing in..." : "Sign in with Browser"
            enabled: !root.isLoading
            onClicked: {
                root.isLoading = true
                root.errorMessage = ""
                var loginUrl = AuthController.getLoginUrl()
                Qt.openUrlExternally(loginUrl)
            }
        }

        // Status text
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 20
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            text: root.isLoading ? "Waiting for authorization...\nComplete sign-in in your browser." : ""
            font { family: Theme.fontFamily; pixelSize: 13 }
            color: Theme.textSecondary
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: root.isLoading
        }

        // Error message
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 16
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            text: root.errorMessage
            font { family: Theme.fontFamily; pixelSize: 13 }
            color: "#FF4444"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: root.errorMessage.length > 0
        }

        // Loading indicator
        BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 20
            running: root.isLoading
            visible: root.isLoading
        }

        Item { Layout.fillHeight: true }

        // Already logged in info
        Text {
            Layout.fillWidth: true
            Layout.bottomMargin: 40
            text: AuthController.isLoggedIn ? "Logged in as: " + AuthController.userEmail : ""
            font { family: Theme.fontFamily; pixelSize: 12 }
            color: Theme.textMuted
            horizontalAlignment: Text.AlignHCenter
            visible: AuthController.isLoggedIn
        }
    }
}
