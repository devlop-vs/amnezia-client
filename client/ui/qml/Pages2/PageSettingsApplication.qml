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

    function openPageCompatible(pageEnum, slide) {
        PageController.goToPage(pageEnum, slide === false ? false : true)
    }

    BackButtonType {
        id: backButton

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 20 + PageController.safeAreaTopMargin
        backButtonImageColor: RedaVia.Theme.textPrimary

        onActiveFocusChanged: {
            if(backButton.enabled && backButton.activeFocus) {
                listView.positionViewAtBeginning()
            }
        }
    }

    ListViewType {
        id: listView

        anchors.top: backButton.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        header: ColumnLayout {
            width: listView.width

            BaseHeaderType {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                fontFamily: RedaVia.Theme.fontFamily
                headerTextColor: RedaVia.Theme.textPrimary
                descriptionTextColor: RedaVia.Theme.textSecondary
                headerText: qsTr("Application")
            }
        }

        model: 1 // fake model to force the ListView to be created without a model

        delegate: ColumnLayout { // TODO(CyAn84): add DelegateChooser when have migrated to 6.9

            width: listView.width

            SwitcherType {
                fontFamily: RedaVia.Theme.fontFamily
                cardColor: RedaVia.Theme.cardBackground
                cardBorderColor: RedaVia.Theme.borderColor
                cardBorderWidth: 1
                cardRadius: RedaVia.Theme.buttonRadius
                contentLeftPadding: 16
                textColor: RedaVia.Theme.textPrimary
                descriptionTextColor: RedaVia.Theme.textSecondary
                checkedIndicatorColor: RedaVia.Theme.primaryGreen
                checkedIndicatorBorderColor: RedaVia.Theme.primaryGreen
                checkedInnerCircleColor: RedaVia.Theme.background
                defaultIndicatorBorderColor: RedaVia.Theme.borderColor
                defaultInnerCircleColor: RedaVia.Theme.textSecondary
                borderFocusedColor: RedaVia.Theme.primaryGreen
                id: switcherAllowScreenshots

                visible: GC.isMobile()

                Layout.fillWidth: true
                Layout.margins: 16

                text: qsTr("Allow application screenshots")

                checked: SettingsController.isScreenshotsEnabled()
                onToggled: function() {
                    if (checked !== SettingsController.isScreenshotsEnabled()) {
                        SettingsController.toggleScreenshotsEnabled(checked)
                    }
                }
            }

            DividerType {
                color: RedaVia.Theme.borderColor
                visible: GC.isMobile()
            }

            LabelWithButtonType {
                id: labelWithButtonNotification

                visible: Qt.platform.os === "android" && !SettingsController.isNotificationPermissionGranted

                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.topMargin: 6

                fontFamily: RedaVia.Theme.fontFamily
                cardColor: RedaVia.Theme.cardBackground
                cardBorderColor: RedaVia.Theme.borderColor
                cardBorderWidth: 1
                cardRadius: RedaVia.Theme.buttonRadius
                textColor: RedaVia.Theme.textPrimary
                descriptionColor: RedaVia.Theme.textSecondary
                rightImageColor: RedaVia.Theme.textPrimary
                leftImageColor: RedaVia.Theme.textPrimary

                text: qsTr("Enable notifications")
                descriptionText: qsTr("Enable notifications to show the VPN state in the status bar")
                rightImageSource: "qrc:/images/controls/chevron-right.svg"

                clickedFunction: function() {
                    SettingsController.requestNotificationPermission()
                }
            }

            DividerType {
                color: RedaVia.Theme.borderColor
                visible: Qt.platform.os === "android" && !SettingsController.isNotificationPermissionGranted
            }

            SwitcherType {
                fontFamily: RedaVia.Theme.fontFamily
                cardColor: RedaVia.Theme.cardBackground
                cardBorderColor: RedaVia.Theme.borderColor
                cardBorderWidth: 1
                cardRadius: RedaVia.Theme.buttonRadius
                contentLeftPadding: 16
                textColor: RedaVia.Theme.textPrimary
                descriptionTextColor: RedaVia.Theme.textSecondary
                checkedIndicatorColor: RedaVia.Theme.primaryGreen
                checkedIndicatorBorderColor: RedaVia.Theme.primaryGreen
                checkedInnerCircleColor: RedaVia.Theme.background
                defaultIndicatorBorderColor: RedaVia.Theme.borderColor
                defaultInnerCircleColor: RedaVia.Theme.textSecondary
                borderFocusedColor: RedaVia.Theme.primaryGreen
                id: switcherAutoStart

                visible: !GC.isMobile()

                Layout.fillWidth: true
                Layout.margins: 16

                text: qsTr("Auto start")
                descriptionText: qsTr("Launch the application every time the device is starts")

                checked: SettingsController.autoStartEnabled
                onToggled: function() {
                    if (checked !== SettingsController.autoStartEnabled) {
                        SettingsController.toggleAutoStart(checked)
                    }
                }
            }

            DividerType {
                color: RedaVia.Theme.borderColor
                visible: !GC.isMobile()
            }

            SwitcherType {
                fontFamily: RedaVia.Theme.fontFamily
                cardColor: RedaVia.Theme.cardBackground
                cardBorderColor: RedaVia.Theme.borderColor
                cardBorderWidth: 1
                cardRadius: RedaVia.Theme.buttonRadius
                contentLeftPadding: 16
                textColor: RedaVia.Theme.textPrimary
                descriptionTextColor: RedaVia.Theme.textSecondary
                checkedIndicatorColor: RedaVia.Theme.primaryGreen
                checkedIndicatorBorderColor: RedaVia.Theme.primaryGreen
                checkedInnerCircleColor: RedaVia.Theme.background
                defaultIndicatorBorderColor: RedaVia.Theme.borderColor
                defaultInnerCircleColor: RedaVia.Theme.textSecondary
                borderFocusedColor: RedaVia.Theme.primaryGreen
                id: switcherAutoConnect

                visible: !GC.isMobile()

                Layout.fillWidth: true
                Layout.margins: 16

                text: qsTr("Auto connect")
                descriptionText: qsTr("Connect to VPN on app start")

                checked: SettingsController.isAutoConnectEnabled()
                onToggled: function() {
                    if (checked !== SettingsController.isAutoConnectEnabled()) {
                        SettingsController.toggleAutoConnect(checked)
                    }
                }
            }

            DividerType {
                color: RedaVia.Theme.borderColor
                visible: !GC.isMobile() && !IsMacOsNeBuild
            }

            SwitcherType {
                fontFamily: RedaVia.Theme.fontFamily
                cardColor: RedaVia.Theme.cardBackground
                cardBorderColor: RedaVia.Theme.borderColor
                cardBorderWidth: 1
                cardRadius: RedaVia.Theme.buttonRadius
                contentLeftPadding: 16
                textColor: RedaVia.Theme.textPrimary
                descriptionTextColor: RedaVia.Theme.textSecondary
                checkedIndicatorColor: RedaVia.Theme.primaryGreen
                checkedIndicatorBorderColor: RedaVia.Theme.primaryGreen
                checkedInnerCircleColor: RedaVia.Theme.background
                defaultIndicatorBorderColor: RedaVia.Theme.borderColor
                defaultInnerCircleColor: RedaVia.Theme.textSecondary
                borderFocusedColor: RedaVia.Theme.primaryGreen
                id: switcherStartMinimized

                visible: !GC.isMobile()

                Layout.fillWidth: true
                Layout.margins: 16

                text: qsTr("Start minimized")
                descriptionText: qsTr("Launch application minimized (works with autostart option turned on)")

                enabled: SettingsController.autoStartEnabled
                opacity: enabled ? 1.0 : 0.5

                checked: SettingsController.autoStartEnabled && SettingsController.startMinimized
                onToggled: function() {
                    if (checked !== SettingsController.startMinimized) {
                        SettingsController.toggleStartMinimized(checked)
                    }
                }
            }

            DividerType {
                color: RedaVia.Theme.borderColor
                visible: !GC.isMobile() && ServersUiController.hasServersFromGatewayApi
            }

            SwitcherType {
                fontFamily: RedaVia.Theme.fontFamily
                cardColor: RedaVia.Theme.cardBackground
                cardBorderColor: RedaVia.Theme.borderColor
                cardBorderWidth: 1
                cardRadius: RedaVia.Theme.buttonRadius
                contentLeftPadding: 16
                textColor: RedaVia.Theme.textPrimary
                descriptionTextColor: RedaVia.Theme.textSecondary
                checkedIndicatorColor: RedaVia.Theme.primaryGreen
                checkedIndicatorBorderColor: RedaVia.Theme.primaryGreen
                checkedInnerCircleColor: RedaVia.Theme.background
                defaultIndicatorBorderColor: RedaVia.Theme.borderColor
                defaultInnerCircleColor: RedaVia.Theme.textSecondary
                borderFocusedColor: RedaVia.Theme.primaryGreen
                id: switcherNewsNotificationEnabled

                visible: ServersUiController.hasServersFromGatewayApi

                Layout.fillWidth: true
                Layout.margins: 16

                text: qsTr("News Notification")
                descriptionText: qsTr("Show a notification icon for unread news")

                checked: SettingsController.isNewsNotificationsEnabled()
                onToggled: function() {
                    if (checked !== SettingsController.isNewsNotificationsEnabled()) {
                        SettingsController.toggleNewsNotificationsEnabled(checked)
                    }
                }
            }

            DividerType {
                color: RedaVia.Theme.borderColor
                visible: !GC.isMobile()
            }
        }

        footer: ColumnLayout {

            width: listView.width

            LabelWithButtonType {
                id: labelWithButtonLanguage

                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.topMargin: 6

                fontFamily: RedaVia.Theme.fontFamily
                cardColor: RedaVia.Theme.cardBackground
                cardBorderColor: RedaVia.Theme.borderColor
                cardBorderWidth: 1
                cardRadius: RedaVia.Theme.buttonRadius
                textColor: RedaVia.Theme.textPrimary
                descriptionColor: RedaVia.Theme.textSecondary
                rightImageColor: RedaVia.Theme.textPrimary
                leftImageColor: RedaVia.Theme.textPrimary

                text: qsTr("Language")
                descriptionText: LanguageUiController.currentLanguageName
                rightImageSource: "qrc:/images/controls/chevron-right.svg"

                clickedFunction: function() {
                    selectLanguageDrawer.openTriggered()
                }
            }

            DividerType { visible: false }

            LabelWithButtonType {
                id: labelWithButtonLogging

                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.topMargin: 6

                fontFamily: RedaVia.Theme.fontFamily
                cardColor: RedaVia.Theme.cardBackground
                cardBorderColor: RedaVia.Theme.borderColor
                cardBorderWidth: 1
                cardRadius: RedaVia.Theme.buttonRadius
                textColor: RedaVia.Theme.textPrimary
                descriptionColor: RedaVia.Theme.textSecondary
                rightImageColor: RedaVia.Theme.textPrimary
                leftImageColor: RedaVia.Theme.textPrimary

                text: qsTr("Logging")
                descriptionText: SettingsController.isLoggingEnabled ? qsTr("Enabled") : qsTr("Disabled")
                rightImageSource: "qrc:/images/controls/chevron-right.svg"

                clickedFunction: function() {
                    root.openPageCompatible(PageEnum.PageSettingsLogging)
                }
            }

            DividerType { visible: false }

            LabelWithButtonType {
                id: labelWithButtonReset

                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.topMargin: 6
                Layout.bottomMargin: 16

                fontFamily: RedaVia.Theme.fontFamily
                cardColor: RedaVia.Theme.cardBackground
                cardBorderColor: RedaVia.Theme.borderColor
                cardBorderWidth: 1
                cardRadius: RedaVia.Theme.buttonRadius
                textColor: RedaVia.Theme.dangerRed
                descriptionColor: RedaVia.Theme.textSecondary
                rightImageColor: RedaVia.Theme.dangerRed
                leftImageColor: RedaVia.Theme.dangerRed

                text: qsTr("Reset settings and remove all data from the application")
                rightImageSource: "qrc:/images/controls/chevron-right.svg"

                clickedFunction: function() {
                    var headerText = qsTr("Reset settings and remove all data from the application?")
                    var descriptionText = qsTr("All settings will be reset to default. All installed RedaVPN services will still remain on the server.")
                    var yesButtonText = qsTr("Continue")
                    var noButtonText = qsTr("Cancel")

                    var yesButtonFunction = function() {
                        if (ServersUiController.isDefaultServerCurrentlyProcessed() && ConnectionController.isConnected) {
                            PageController.showNotificationMessage(qsTr("Cannot reset settings during active connection"))
                        } else
                        {
                            SettingsController.clearSettings()
                            PageController.goToPageHome()
                        }
                    }
                    var noButtonFunction = function() {
                    }

                    showQuestionDrawer(headerText, descriptionText, yesButtonText, noButtonText, yesButtonFunction, noButtonFunction)
                }
            }

            DividerType { visible: false }
        }
    }

    SelectLanguageDrawer {
        id: selectLanguageDrawer

        width: root.width
        height: root.height
    }
}
