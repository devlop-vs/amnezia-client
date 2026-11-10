import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import PageEnum 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Config"
import "../RedaVia" as RedaVia

PageType {
    id: root

    Rectangle {
        anchors.fill: parent
        color: RedaVia.Theme.background
        z: -1
    }

    function openPageCompatible(pageEnum, slide) {
        var pagePath = PageController.getPagePath(pageEnum)
        var stackView = root.StackView.view

        if (stackView) {
            stackView.push(pagePath, { "objectName": pagePath }, slide === false ? StackView.Immediate : StackView.PushTransition)
        } else {
            PageController.goToPage(pageEnum, slide === false ? false : true)
        }
    }

    BackButtonType {
        id: backButton
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 20 + PageController.safeAreaTopMargin
        backButtonImageColor: RedaVia.Theme.textPrimary
    }

    FlickableType {
        id: fl
        anchors.top: backButton.bottom
        anchors.bottom: parent.bottom
        contentHeight: content.height

        ColumnLayout {
            id: content
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right

            HeaderTypeWithSwitcher {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                headerText: qsTr("KillSwitch")
                descriptionText: qsTr("Enable to ensure network traffic goes through a secure VPN tunnel, preventing accidental exposure of your IP and DNS queries if the connection drops")
                fontFamily: RedaVia.Theme.fontFamily
                headerTextColor: RedaVia.Theme.textPrimary
                descriptionTextColor: RedaVia.Theme.textSecondary

                showSwitcher: true
                switcher {
                    checked: SettingsController.isKillSwitchEnabled
                    enabled: !ConnectionController.isConnected
                }
                switcherFunction: function(checked) {
                    if (!ConnectionController.isConnected) {
                        SettingsController.isKillSwitchEnabled = checked
                    } else {
                        PageController.showNotificationMessage(qsTr("KillSwitch settings cannot be changed during an active connection"))
                        switcher.checked = SettingsController.isKillSwitchEnabled
                    }
                }
            }

            VerticalRadioButton {
                id: softKillSwitch
                Layout.fillWidth: true
                Layout.topMargin: 32
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                enabled: SettingsController.isKillSwitchEnabled && !ConnectionController.isConnected
                checked: !SettingsController.strictKillSwitchEnabled

                text: qsTr("Soft KillSwitch")
                descriptionText: qsTr("Internet access is blocked if the VPN disconnects unexpectedly")
                defaultColor: RedaVia.Theme.cardBackground
                hoveredColor: RedaVia.Theme.cardBackgroundAlt
                selectedColor: RedaVia.Theme.cardBackgroundAlt
                textColor: RedaVia.Theme.textPrimary
                selectedTextColor: RedaVia.Theme.primaryGreen
                descriptionColor: RedaVia.Theme.textSecondary
                borderFocusedColor: RedaVia.Theme.primaryGreen
                cardRadius: RedaVia.Theme.buttonRadius
                fontFamily: RedaVia.Theme.fontFamily

                onClicked: function() {
                    SettingsController.strictKillSwitchEnabled = false
                }

                Keys.onEnterPressed: this.clicked()
                Keys.onReturnPressed: this.clicked()
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                height: 1
                color: RedaVia.Theme.borderColor
            }

            VerticalRadioButton {
                id: strictKillSwitch
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                visible: false
                enabled: false
                // enabled: SettingsController.isKillSwitchEnabled && !ConnectionController.isConnected
                checked: SettingsController.strictKillSwitchEnabled

                text: qsTr("Strict KillSwitch")
                descriptionText: qsTr("Internet connection is blocked even when VPN is turned off manually or hasn't started")
                defaultColor: RedaVia.Theme.cardBackground
                hoveredColor: RedaVia.Theme.cardBackgroundAlt
                selectedColor: RedaVia.Theme.cardBackgroundAlt
                textColor: RedaVia.Theme.textPrimary
                selectedTextColor: RedaVia.Theme.primaryGreen
                descriptionColor: RedaVia.Theme.textSecondary
                borderFocusedColor: RedaVia.Theme.primaryGreen
                cardRadius: RedaVia.Theme.buttonRadius
                fontFamily: RedaVia.Theme.fontFamily

                onClicked: function() {
                    var headerText = qsTr("Just a little heads-up")
                    var descriptionText = qsTr("If the VPN disconnects or drops while Strict KillSwitch is enabled, internet access will be blocked. To restore access, reconnect VPN or disable/change the KillSwitch.")
                    var yesButtonText = qsTr("Continue")
                    var noButtonText = qsTr("Cancel")

                    var yesButtonFunction = function() {
                        SettingsController.strictKillSwitchEnabled = true
                    }
                    var noButtonFunction = function() {
                    }

                    showQuestionDrawer(headerText, descriptionText, yesButtonText, noButtonText, yesButtonFunction, noButtonFunction)
                }

                Keys.onEnterPressed: this.clicked()
                Keys.onReturnPressed: this.clicked()
            }

            LabelWithButtonType {
                Layout.topMargin: 32
                Layout.fillWidth: true

                enabled: true
                text: qsTr("DNS Exceptions")
                descriptionText: qsTr("DNS servers listed here will remain accessible when KillSwitch is active.")
                rightImageSource: "qrc:/images/controls/chevron-right.svg"
                fontFamily: RedaVia.Theme.fontFamily
                cardColor: RedaVia.Theme.cardBackground
                cardBorderColor: RedaVia.Theme.borderColor
                cardBorderWidth: 1
                cardRadius: RedaVia.Theme.buttonRadius
                textColor: RedaVia.Theme.textPrimary
                descriptionColor: RedaVia.Theme.textSecondary
                rightImageColor: RedaVia.Theme.textPrimary

                clickedFunction: function() {
                    root.openPageCompatible(PageEnum.PageSettingsKillSwitchExceptions)
                }
            }
        }
    }
} 
