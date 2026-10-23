import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import SortFilterProxyModel 0.2

import PageEnum 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"
import "../Components"
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

    property list<QtObject> labelsModel: [
        statusObject,
        endDateObject,
        deviceCountObject
    ]

    QtObject {
        id: statusObject

        readonly property string title: qsTr("Subscription Status")
        readonly property string contentKey: "subscriptionStatus"
        readonly property string objectImageSource: "qrc:/images/controls/info.svg"
        readonly property bool isRichText: true
    }

    QtObject {
        id: endDateObject

        readonly property string title: qsTr("Valid Until")
        readonly property string contentKey: "endDate"
        readonly property string objectImageSource: "qrc:/images/controls/history.svg"
        readonly property bool isRichText: false
    }

    QtObject {
        id: deviceCountObject

        readonly property string title: qsTr("Active Connections")
        readonly property string contentKey: "connectedDevices"
        readonly property string objectImageSource: "qrc:/images/controls/monitor.svg"
        readonly property bool isRichText: false
    }

    property var processedServer

    property bool isSubscriptionExpired: false
    property bool isSubscriptionExpiringSoon: false
    property bool isSubscriptionRenewalAvailable: false
    property bool isInAppPurchase: false

    function updateSubscriptionState() {
        root.isSubscriptionExpired = ApiAccountInfoModel.data("isSubscriptionExpired")
        root.isSubscriptionExpiringSoon = ApiAccountInfoModel.data("isSubscriptionExpiringSoon")
        root.isSubscriptionRenewalAvailable = ApiAccountInfoModel.data("isSubscriptionRenewalAvailable")
        root.isInAppPurchase = ApiAccountInfoModel.data("isInAppPurchase")
    }

    Component.onCompleted: {
        root.updateSubscriptionState()
    }

    Connections {
        target: ApiAccountInfoModel

        function onModelReset() {
            root.updateSubscriptionState()
        }
    }

    Connections {
        target: ServersUiController

        function onProcessedServerIdChanged() {
            root.processedServer = proxyServersModel.get(0)
        }
    }

    Connections {
        target: ServersModel

        function onModelReset() {
            root.processedServer = proxyServersModel.get(0)
        }
    }

    SortFilterProxyModel {
        id: proxyServersModel
        objectName: "proxyServersModel"

        sourceModel: ServersModel
        filters: [
            ValueFilter {
                roleName: "serverId"
                value: ServersUiController.processedServerId
            }
        ]

        Component.onCompleted: {
            root.processedServer = proxyServersModel.get(0)
        }
    }

    ListViewType {
        id: listView

        anchors.fill: parent
        palette.base: RedaVia.Theme.background
        palette.window: RedaVia.Theme.background

        model: labelsModel

        header: ColumnLayout {
            width: listView.width

            spacing: 4

            BackButtonType {
                id: backButton
                objectName: "backButton"

                Layout.topMargin: 20 + PageController.safeAreaTopMargin
            }

            HeaderTypeWithButton {
                id: headerContent
                objectName: "headerContent"

                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.bottomMargin: root.isSubscriptionExpired || root.isSubscriptionExpiringSoon ? 0 : 10

                actionButtonImage: "qrc:/images/controls/edit-3.svg"
                fontFamily: RedaVia.Theme.fontFamily

                headerText: root.processedServer != null ? root.processedServer.name : ""

                actionButtonFunction: function() {
                    serverNameEditDrawer.openTriggered()
                }
            }

            ParagraphTextType {
                visible: root.isSubscriptionExpired || root.isSubscriptionExpiringSoon

                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.topMargin: 12

                text: root.isSubscriptionExpired
                    ? qsTr("Subscription expired")
                    : qsTr("Subscription expiring soon")
                font.family: RedaVia.Theme.fontFamily

                color: root.isSubscriptionExpired
                    ? RedaVia.Theme.dangerRed
                    : RedaVia.Theme.accentYellow
            }

            ParagraphTextType {
                visible: ApiAccountInfoModel.data("serviceDescription") !== ""

                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.topMargin: 16
                Layout.bottomMargin: root.isSubscriptionExpired || root.isSubscriptionExpiringSoon ? 0 : 10

                text: ApiAccountInfoModel.data("serviceDescription")
                color: RedaVia.Theme.textSecondary
                font.family: RedaVia.Theme.fontFamily
            }

            BasicButtonType {
                visible: (root.isSubscriptionExpired || root.isSubscriptionExpiringSoon)
                    && root.isSubscriptionRenewalAvailable && !root.isInAppPurchase

                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.topMargin: 8
                Layout.bottomMargin: 8

                text: qsTr("Renew subscription")

                defaultColor: RedaVia.Theme.primaryGreen
                hoveredColor: "#57ed86"
                pressedColor: "#24c95a"
                textColor: RedaVia.Theme.background
                fontFamily: RedaVia.Theme.fontFamily

                clickedFunc: function() {
                    SubscriptionUiController.getRenewalLink(ServersUiController.processedServerId)
                }
            }
        }

        delegate: ColumnLayout {
            width: listView.width
            spacing: 0

            Connections {
                target: ApiAccountInfoModel

                function onModelReset() {
                    delegateItem.rightText = ApiAccountInfoModel.data(contentKey)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.topMargin: 6
                Layout.bottomMargin: 6

                implicitHeight: 64
                color: RedaVia.Theme.cardBackground
                border.color: RedaVia.Theme.borderColor
                border.width: 1
                radius: RedaVia.Theme.buttonRadius
                visible: delegateItem.rightText !== ""

                LabelWithImageType {
                    id: delegateItem

                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16

                    imageSource: objectImageSource
                    leftText: title
                    rightText: ApiAccountInfoModel.data(contentKey)
                    rightTextFormat: isRichText ? Text.RichText : Text.PlainText
                    fontFamily: RedaVia.Theme.fontFamily
                    leftTextColor: RedaVia.Theme.textPrimary
                    rightTextColor: RedaVia.Theme.textSecondary
                }
            }
        }

        footer: ColumnLayout {
            id: footer

            width: listView.width
            spacing: 0

            readonly property bool isVisibleForAmneziaFree: ApiAccountInfoModel.data("isComponentVisible")

            BasicButtonType {
                visible: !root.isSubscriptionExpired && !root.isSubscriptionExpiringSoon
                    && root.isSubscriptionRenewalAvailable && !root.isInAppPurchase

                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 16
                Layout.bottomMargin: 16

                implicitHeight: 25

                defaultColor: "transparent"
                hoveredColor: RedaVia.Theme.cardBackgroundAlt
                pressedColor: RedaVia.Theme.cardBackground
                textColor: RedaVia.Theme.primaryGreen
                fontFamily: RedaVia.Theme.fontFamily
                leftImageSource: "qrc:/images/controls/refresh-cw.svg"
                leftImageColor: RedaVia.Theme.primaryGreen

                text: qsTr("Renew subscription")

                clickedFunc: function() {
                    SubscriptionUiController.getRenewalLink(ServersUiController.processedServerId)
                }
            }

            DividerType {
                visible: !root.isSubscriptionExpired && !root.isSubscriptionExpiringSoon
                    && root.isSubscriptionRenewalAvailable && !root.isInAppPurchase
                color: RedaVia.Theme.borderColor
            }

            SwitcherType {
                id: switcher

                readonly property bool isVlessProtocol: SubscriptionUiController.isVlessProtocol(ServersUiController.processedServerId)
                readonly property bool isProtocolSwitchBlocked: ServersUiController.isDefaultServerCurrentlyProcessed() && ConnectionController.isConnected

                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.rightMargin: 16
                Layout.leftMargin: 16
                Layout.bottomMargin: 16

                leftPadding: 16
                rightPadding: 16
                implicitHeight: 72

                visible: ApiAccountInfoModel.data("isProtocolSelectionSupported")
                enabled: !switcher.isProtocolSwitchBlocked

                text: qsTr("Use VLESS protocol")
                fontFamily: RedaVia.Theme.fontFamily
                textColor: RedaVia.Theme.textPrimary
                descriptionTextColor: RedaVia.Theme.textSecondary
                checkedIndicatorColor: RedaVia.Theme.connectedInner
                checkedIndicatorBorderColor: RedaVia.Theme.primaryGreen
                checkedInnerCircleColor: RedaVia.Theme.primaryGreen
                defaultIndicatorBorderColor: RedaVia.Theme.borderColor
                defaultInnerCircleColor: RedaVia.Theme.textSecondary
                cardColor: RedaVia.Theme.cardBackground
                cardBorderColor: RedaVia.Theme.borderColor
                cardBorderWidth: 1
                cardRadius: RedaVia.Theme.buttonRadius
                checked: switcher.isVlessProtocol
                onToggled: function() {
                    if (ServersUiController.isDefaultServerCurrentlyProcessed() && ConnectionController.isConnected) {
                        PageController.showNotificationMessage(qsTr("Cannot change protocol during active connection"))
                    } else {
                        PageController.showBusyIndicator(true)
                        SubscriptionUiController.setCurrentProtocol(ServersUiController.processedServerId, switcher.isVlessProtocol ? "awg" : "vless")
                        SubscriptionUiController.updateServiceFromGateway(ServersUiController.processedServerId, "", "", true)
                        PageController.showBusyIndicator(false)
                    }
                }
            }

            WarningType {
                id: warning

                Layout.topMargin: 24
                Layout.rightMargin: 16
                Layout.leftMargin: 16
                Layout.fillWidth: true

                backGroundColor: RedaVia.Theme.cardBackgroundAlt
                borderColor: RedaVia.Theme.borderColor
                borderWidth: 1
                cardRadius: RedaVia.Theme.buttonRadius
                textColor: RedaVia.Theme.textBody
                imageColor: RedaVia.Theme.accentYellow
                fontFamily: RedaVia.Theme.fontFamily

                textString: qsTr("Configurations have been updated for some countries. Download and install the updated configuration files")

                iconPath: "qrc:/images/controls/alert-circle.svg"

                visible: {
                    for (let i = 0; i < ApiCountryModel.count; ++i) {
                        if (ApiCountryModel.get(i).isWorkerExpired)
                            return true;
                    }
                    return false;
                }
            }

            LabelWithButtonType {
                id: vpnKey

                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.topMargin: warning.visible ? 16 : 8
                Layout.bottomMargin: 8

                visible: footer.isVisibleForAmneziaFree

                text: qsTr("Subscription Key")
                fontFamily: RedaVia.Theme.fontFamily
                textColor: RedaVia.Theme.textPrimary
                descriptionColor: RedaVia.Theme.textSecondary
                rightImageColor: RedaVia.Theme.textSecondary
                rightImageSource: "qrc:/images/controls/chevron-right.svg"
                cardColor: RedaVia.Theme.cardBackground
                cardBorderColor: RedaVia.Theme.borderColor
                cardBorderWidth: 1
                cardRadius: RedaVia.Theme.buttonRadius

                clickedFunction: function() {
                    root.openPageCompatible(PageEnum.PageSettingsApiSubscriptionKey)
                    PageController.showBusyIndicator(true)

                    SubscriptionUiController.prepareVpnKeyExport(ServersUiController.processedServerId)

                    PageController.showBusyIndicator(false)
                }
            }

            LabelWithButtonType {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.bottomMargin: 8

                visible: footer.isVisibleForAmneziaFree

                text: qsTr("Configuration Files")
                fontFamily: RedaVia.Theme.fontFamily
                textColor: RedaVia.Theme.textPrimary
                descriptionColor: RedaVia.Theme.textSecondary
                rightImageColor: RedaVia.Theme.textSecondary

                descriptionText: qsTr("Manage configuration files")
                rightImageSource: "qrc:/images/controls/chevron-right.svg"
                cardColor: RedaVia.Theme.cardBackground
                cardBorderColor: RedaVia.Theme.borderColor
                cardBorderWidth: 1
                cardRadius: RedaVia.Theme.buttonRadius

                clickedFunction: function() {
                    SubscriptionUiController.updateApiCountryModel()
                    root.openPageCompatible(PageEnum.PageSettingsApiNativeConfigs)
                }
            }

            LabelWithButtonType {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.bottomMargin: 8

                visible: footer.isVisibleForAmneziaFree

                text: qsTr("Active Devices")
                fontFamily: RedaVia.Theme.fontFamily
                textColor: RedaVia.Theme.textPrimary
                descriptionColor: RedaVia.Theme.textSecondary
                rightImageColor: RedaVia.Theme.textSecondary

                descriptionText: qsTr("Manage currently connected devices")
                rightImageSource: "qrc:/images/controls/chevron-right.svg"
                cardColor: RedaVia.Theme.cardBackground
                cardBorderColor: RedaVia.Theme.borderColor
                cardBorderWidth: 1
                cardRadius: RedaVia.Theme.buttonRadius

                clickedFunction: function() {
                    SubscriptionUiController.updateApiDevicesModel()
                    root.openPageCompatible(PageEnum.PageSettingsApiDevices)
                }
            }

            LabelWithButtonType {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.topMargin: footer.isVisibleForAmneziaFree ? 0 : 16
                Layout.bottomMargin: 8

                text: qsTr("Support")
                fontFamily: RedaVia.Theme.fontFamily
                textColor: RedaVia.Theme.textPrimary
                descriptionColor: RedaVia.Theme.textSecondary
                rightImageColor: RedaVia.Theme.textSecondary
                rightImageSource: "qrc:/images/controls/chevron-right.svg"
                cardColor: RedaVia.Theme.cardBackground
                cardBorderColor: RedaVia.Theme.borderColor
                cardBorderWidth: 1
                cardRadius: RedaVia.Theme.buttonRadius

                clickedFunction: function() {
                    root.openPageCompatible(PageEnum.PageSettingsApiSupport)
                }
            }

            LabelWithButtonType {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.bottomMargin: 8

                visible: footer.isVisibleForAmneziaFree

                text: qsTr("How to connect on another device")
                fontFamily: RedaVia.Theme.fontFamily
                textColor: RedaVia.Theme.textPrimary
                descriptionColor: RedaVia.Theme.textSecondary
                rightImageColor: RedaVia.Theme.textSecondary
                rightImageSource: "qrc:/images/controls/chevron-right.svg"
                cardColor: RedaVia.Theme.cardBackground
                cardBorderColor: RedaVia.Theme.borderColor
                cardBorderWidth: 1
                cardRadius: RedaVia.Theme.buttonRadius

                clickedFunction: function() {
                    root.openPageCompatible(PageEnum.PageSettingsApiInstructions)
                }
            }

            BasicButtonType {
                id: resetButton
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 24
                Layout.bottomMargin: 16
                Layout.leftMargin: 8
                implicitHeight: 32

                defaultColor: "transparent"
                hoveredColor: RedaVia.Theme.cardBackgroundAlt
                pressedColor: RedaVia.Theme.cardBackground
                textColor: RedaVia.Theme.dangerRed
                fontFamily: RedaVia.Theme.fontFamily

                text: qsTr("Reload API config")

                clickedFunc: function() {
                    var headerText = qsTr("Reload API config?")
                    var yesButtonText = qsTr("Continue")
                    var noButtonText = qsTr("Cancel")

                    var yesButtonFunction = function() {
                        if (ServersUiController.isDefaultServerCurrentlyProcessed() && ConnectionController.isConnected) {
                            PageController.showNotificationMessage(qsTr("Cannot reload API config during active connection"))
                        } else {
                            PageController.showBusyIndicator(true)
                            SubscriptionUiController.updateServiceFromGateway(ServersUiController.processedServerId, "", "", true)
                            PageController.showBusyIndicator(false)
                        }
                    }
                    var noButtonFunction = function() {
                    }

                    showQuestionDrawer(headerText, "", yesButtonText, noButtonText, yesButtonFunction, noButtonFunction)
                }
            }

            BasicButtonType {
                id: revokeButton
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 16
                Layout.leftMargin: 8
                implicitHeight: 32

                visible: footer.isVisibleForAmneziaFree

                defaultColor: "transparent"
                hoveredColor: RedaVia.Theme.cardBackgroundAlt
                pressedColor: RedaVia.Theme.cardBackground
                textColor: RedaVia.Theme.dangerRed
                fontFamily: RedaVia.Theme.fontFamily

                text: qsTr("Unlink this device")

                clickedFunc: function() {
                    var headerText = qsTr("Are you sure you want to unlink this device?")
                    var descriptionText = qsTr("This will unlink the device from your subscription. You can reconnect it anytime by pressing \"Reload API config\" in subscription settings on device.")
                    var yesButtonText = qsTr("Continue")
                    var noButtonText = qsTr("Cancel")

                    var yesButtonFunction = function() {
                        if (ServersUiController.isDefaultServerCurrentlyProcessed() && ConnectionController.isConnected) {
                            PageController.showNotificationMessage(qsTr("Cannot unlink device during active connection"))
                        } else {
                            PageController.showBusyIndicator(true)
                            if (SubscriptionUiController.deactivateDevice(ServersUiController.processedServerId)) {
                                SubscriptionUiController.getAccountInfo(ServersUiController.processedServerId, true)
                            }
                            PageController.showBusyIndicator(false)
                        }
                    }
                    var noButtonFunction = function() {
                    }

                    showQuestionDrawer(headerText, descriptionText, yesButtonText, noButtonText, yesButtonFunction, noButtonFunction)
                }
            }

            BasicButtonType {
                id: removeButton
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 16
                Layout.leftMargin: 8
                implicitHeight: 32

                defaultColor: "transparent"
                hoveredColor: RedaVia.Theme.cardBackgroundAlt
                pressedColor: RedaVia.Theme.cardBackground
                textColor: RedaVia.Theme.dangerRed
                fontFamily: RedaVia.Theme.fontFamily

                text: qsTr("Remove from application")

                clickedFunc: function() {
                    var headerText = qsTr("Remove from application?")
                    var yesButtonText = qsTr("Continue")
                    var noButtonText = qsTr("Cancel")

                    var yesButtonFunction = function() {
                        if (ServersUiController.isDefaultServerCurrentlyProcessed() && ConnectionController.isConnected) {
                            PageController.showNotificationMessage(qsTr("Cannot remove server during active connection"))
                        } else {
                            PageController.showBusyIndicator(true)
                            SubscriptionUiController.removeServer(ServersUiController.processedServerId)
                            PageController.showBusyIndicator(false)
                        }
                    }
                    var noButtonFunction = function() {
                    }

                    showQuestionDrawer(headerText, "", yesButtonText, noButtonText, yesButtonFunction, noButtonFunction)
                }
            }
        }
    }

    RenameServerDrawer {
        id: serverNameEditDrawer

        anchors.fill: parent
        expandedHeight: parent.height * 0.35

        serverNameText: root.processedServer != null ? root.processedServer.name : ""
    }
}
