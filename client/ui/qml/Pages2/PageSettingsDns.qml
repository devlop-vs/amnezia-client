import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import PageEnum 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Config"
import "../RedaVia" as RedaVia
import "../Controls2/TextTypes"
import "../Components"

PageType {
    id: root

    Rectangle {
        anchors.fill: parent
        color: RedaVia.Theme.background
        z: -1
    }

    BackButtonType {
        id: backButton

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 20 + PageController.safeAreaTopMargin
        backButtonImageColor: RedaVia.Theme.textPrimary

        onFocusChanged: {
            if (this.activeFocus) {
                listView.positionViewAtBeginning()
            }
        }
    }

    ListViewType {
        id: listView

        anchors.top: backButton.bottom
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.left: parent.left

        property var isServerFromApi: ServersUiController.isDefaultServerFromApi

        enabled: !isServerFromApi

        Component.onCompleted: {
            if (isServerFromApi) {
                PageController.showNotificationMessage(qsTr("Default server does not support custom DNS"))
            }
        }

        header: ColumnLayout {
            width: listView.width
            spacing: 16

            BaseHeaderType {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                fontFamily: RedaVia.Theme.fontFamily
                headerTextColor: RedaVia.Theme.textPrimary
                descriptionTextColor: RedaVia.Theme.textSecondary
                headerText: qsTr("DNS servers")
            }

            ParagraphTextType {
                font.family: RedaVia.Theme.fontFamily
                color: RedaVia.Theme.textSecondary
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                
                text: qsTr("If AmneziaDNS is not used or installed")
            }
        }

        model: 1 // fake model to force the ListView to be created without a model

        delegate: ColumnLayout {
            width: listView.width
            spacing: 16

            TextFieldWithHeaderType {
                fontFamily: RedaVia.Theme.fontFamily
                headerTextColor: RedaVia.Theme.textPrimary
                textFieldTextColor: RedaVia.Theme.textPrimary
                textFieldPlaceholderTextColor: RedaVia.Theme.textPlaceholder
                borderColor: RedaVia.Theme.borderColor
                borderFocusedColor: RedaVia.Theme.primaryGreen
                backgroundColor: RedaVia.Theme.cardBackground
                backgroundDisabledColor: RedaVia.Theme.cardBackground
                bgBorderHoveredColor: RedaVia.Theme.cardBackgroundAlt
                backgroundRadius: RedaVia.Theme.inputRadius
                id: primaryDns

                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                headerText: qsTr("Primary DNS")

                textField.text: SettingsController.primaryDns
                textField.validator: RegularExpressionValidator {
                    regularExpression: InstallController.ipAddressRegExp()
                }
            }

            TextFieldWithHeaderType {
                fontFamily: RedaVia.Theme.fontFamily
                headerTextColor: RedaVia.Theme.textPrimary
                textFieldTextColor: RedaVia.Theme.textPrimary
                textFieldPlaceholderTextColor: RedaVia.Theme.textPlaceholder
                borderColor: RedaVia.Theme.borderColor
                borderFocusedColor: RedaVia.Theme.primaryGreen
                backgroundColor: RedaVia.Theme.cardBackground
                backgroundDisabledColor: RedaVia.Theme.cardBackground
                bgBorderHoveredColor: RedaVia.Theme.cardBackgroundAlt
                backgroundRadius: RedaVia.Theme.inputRadius
                id: secondaryDns

                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                headerText: qsTr("Secondary DNS")

                textField.text: SettingsController.secondaryDns
                textField.validator: RegularExpressionValidator {
                    regularExpression: InstallController.ipAddressRegExp()
                }
            }

            BasicButtonType {
                fontFamily: RedaVia.Theme.fontFamily
                borderColor: RedaVia.Theme.primaryGreen
                borderFocusedColor: RedaVia.Theme.primaryGreen
                buttonRadius: RedaVia.Theme.buttonRadius
                id: restoreDefaultButton

                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                defaultColor: RedaVia.Theme.cardBackground
                hoveredColor: RedaVia.Theme.cardBackgroundAlt
                pressedColor: RedaVia.Theme.connectedInner
                disabledColor: RedaVia.Theme.cardBackgroundAlt
                textColor: RedaVia.Theme.textPrimary
                borderWidth: 1

                text: qsTr("Restore default")

                clickedFunc: function() {
                    var headerText = qsTr("Restore default DNS settings?")
                    var yesButtonText = qsTr("Continue")
                    var noButtonText = qsTr("Cancel")

                    var yesButtonFunction = function() {
                        SettingsController.primaryDns = "1.1.1.1"
                        primaryDns.textField.text = SettingsController.primaryDns
                        SettingsController.secondaryDns = "1.0.0.1"
                        secondaryDns.textField.text = SettingsController.secondaryDns
                        PageController.showNotificationMessage(qsTr("Settings have been reset"))
                    }
                    var noButtonFunction = function() {
                    }

                    showQuestionDrawer(headerText, "", yesButtonText, noButtonText, yesButtonFunction, noButtonFunction)
                }
            }

            BasicButtonType {
                fontFamily: RedaVia.Theme.fontFamily
                defaultColor: RedaVia.Theme.primaryGreen
                hoveredColor: RedaVia.Theme.primaryGreen
                pressedColor: RedaVia.Theme.connectedInner
                disabledColor: RedaVia.Theme.cardBackgroundAlt
                textColor: RedaVia.Theme.background
                borderColor: RedaVia.Theme.primaryGreen
                borderFocusedColor: RedaVia.Theme.primaryGreen
                buttonRadius: RedaVia.Theme.buttonRadius
                id: saveButton

                Layout.fillWidth: true
                Layout.margins: 16

                text: qsTr("Save")

                clickedFunc: function() {
                    if (primaryDns.textField.text === "") {
                        primaryDns.errorText = qsTr("Primary DNS cannot be empty")
                        return
                    }
                    primaryDns.errorText = ""
                    secondaryDns.errorText = ""

                    if (primaryDns.textField.text !== SettingsController.primaryDns) {
                        SettingsController.primaryDns = primaryDns.textField.text
                    }
                    if (secondaryDns.textField.text !== SettingsController.secondaryDns) {
                        SettingsController.secondaryDns = secondaryDns.textField.text
                    }
                    PageController.showNotificationMessage(qsTr("Settings saved"))
                }
            }
        }
    }
}
