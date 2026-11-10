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

    property bool isAppSplitTinnelingEnabled: Qt.platform.os === "windows" || Qt.platform.os === "android"

    function openPageCompatible(pageEnum, slide) {
        var pagePath = PageController.getPagePath(pageEnum)
        var attachedStackView = root.StackView.view
        var compatibleStackView = root.stackView
        var transition = slide === false ? StackView.Immediate : StackView.PushTransition

        console.info("[PageSettingsConnection] Navigation requested",
                     "pageEnum=", pageEnum,
                     "pagePath=", pagePath,
                     "slide=", slide,
                     "root.visible=", root.visible,
                     "root.stackView=", compatibleStackView,
                     "root.StackView.view=", attachedStackView)

        if (!pagePath) {
            console.error("[PageSettingsConnection] PageController returned an empty page path",
                          "pageEnum=", pageEnum)
            return
        }

        if (compatibleStackView) {
            try {
                console.info("[PageSettingsConnection] Pushing page on StackView",
                             "depthBefore=", compatibleStackView.depth,
                             "currentItem=", compatibleStackView.currentItem)
                var pushedItem = compatibleStackView.push(pagePath, { "objectName": pagePath }, transition)
                console.info("[PageSettingsConnection] StackView push completed",
                             "result=", pushedItem,
                             "depthAfter=", compatibleStackView.depth,
                             "currentItem=", compatibleStackView.currentItem)
            } catch (error) {
                console.error("[PageSettingsConnection] StackView push failed",
                              "pagePath=", pagePath,
                              "error=", error)
            }
            return
        }

        console.warn("[PageSettingsConnection] StackView is unavailable; using PageController.goToPage",
                     "pageEnum=", pageEnum)
        try {
            PageController.goToPage(pageEnum, slide === false ? false : true)
            console.info("[PageSettingsConnection] PageController.goToPage invoked",
                         "pageEnum=", pageEnum)
        } catch (error) {
            console.error("[PageSettingsConnection] PageController.goToPage failed",
                          "pageEnum=", pageEnum,
                          "error=", error)
        }
    }

    Component.onCompleted: {
        console.info("[PageSettingsConnection] Page created",
                     "objectName=", root.objectName,
                     "root.stackView=", root.stackView,
                     "root.StackView.view=", root.StackView.view,
                     "parent=", root.parent)
    }

    onStackViewChanged: {
        console.info("[PageSettingsConnection] stackView changed",
                     "root.stackView=", root.stackView,
                     "root.StackView.view=", root.StackView.view)
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
                headerText: qsTr("Connection")
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
                textColor: RedaVia.Theme.textPrimary
                descriptionTextColor: RedaVia.Theme.textSecondary
                checkedIndicatorColor: RedaVia.Theme.primaryGreen
                checkedIndicatorBorderColor: RedaVia.Theme.primaryGreen
                checkedInnerCircleColor: RedaVia.Theme.background
                defaultIndicatorBorderColor: RedaVia.Theme.borderColor
                defaultInnerCircleColor: RedaVia.Theme.textSecondary
                borderFocusedColor: RedaVia.Theme.primaryGreen
                contentLeftPadding: 16
                id: amneziaDnsSwitch

                Layout.fillWidth: true
                Layout.margins: 16

                text: qsTr("Use RedaDNS")
                descriptionText: qsTr("If RedaDNS is installed on the server")

                checked: SettingsController.isAmneziaDnsEnabled()
                onToggled: function() {
                    if (checked !== SettingsController.isAmneziaDnsEnabled()) {
                        SettingsController.toggleAmneziaDns(checked)
                    }
                }
            }

            DividerType { visible: false }

            LabelWithButtonType {
                id: dnsServersButton

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

                text: qsTr("DNS servers")
                descriptionText: qsTr("When RedaDNS is not used or installed")
                rightImageSource: "qrc:/images/controls/chevron-right.svg"

                clickedFunction: function() {
                    console.info("[PageSettingsConnection] DNS servers button clicked",
                                 "enabled=", dnsServersButton.enabled,
                                 "visible=", dnsServersButton.visible)
                    root.openPageCompatible(PageEnum.PageSettingsDns)
                }
            }

            DividerType { visible: false }

            SwitcherType {
                id: globalProxySwitch

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
                descriptionTextColor: RedaVia.Theme.textSecondary
                checkedIndicatorColor: RedaVia.Theme.primaryGreen
                checkedIndicatorBorderColor: RedaVia.Theme.primaryGreen
                checkedInnerCircleColor: RedaVia.Theme.background
                defaultIndicatorBorderColor: RedaVia.Theme.borderColor
                defaultInnerCircleColor: RedaVia.Theme.textSecondary
                borderFocusedColor: RedaVia.Theme.primaryGreen
                contentLeftPadding: 16

                text: qsTr("Global Proxy")
                descriptionText: qsTr("Route all network traffic through the VPN")
                checked: SettingsController.globalProxyEnabled

                onToggled: function() {
                    if (checked !== SettingsController.globalProxyEnabled) {
                        SettingsController.toggleGlobalProxy(checked)
                    }
                }
            }

            DividerType { visible: false }

            LabelWithButtonType {
                id: splitTunnelingButton

                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.topMargin: 6
                enabled: !globalProxySwitch.checked
                fontFamily: RedaVia.Theme.fontFamily
                cardColor: enabled ? RedaVia.Theme.cardBackground : RedaVia.Theme.cardBackgroundAlt
                cardBorderColor: enabled ? RedaVia.Theme.borderColor : RedaVia.Theme.cardBackgroundAlt
                cardBorderWidth: 1
                cardRadius: RedaVia.Theme.buttonRadius
                textColor: RedaVia.Theme.textPrimary
                textDisabledColor: RedaVia.Theme.textPlaceholder
                descriptionColor: RedaVia.Theme.textSecondary
                descriptionDisabledColor: RedaVia.Theme.textSubtle
                rightImageColor: enabled ? RedaVia.Theme.textPrimary : RedaVia.Theme.textPlaceholder
                leftImageColor: enabled ? RedaVia.Theme.textPrimary : RedaVia.Theme.textPlaceholder

                text: qsTr("Site-based split tunneling")
                descriptionText: qsTr("Allows you to select which sites you want to access through the VPN")
                rightImageSource: "qrc:/images/controls/chevron-right.svg"

                clickedFunction: function() {
                    console.info("[PageSettingsConnection] Site split tunneling button clicked",
                                 "enabled=", splitTunnelingButton.enabled,
                                 "visible=", splitTunnelingButton.visible)
                    root.openPageCompatible(PageEnum.PageSettingsSplitTunneling)
                }
            }

            DividerType { visible: false }

        }

        footer: ColumnLayout { // TODO(CyAn84): move to delegate,add DelegateChooser when have migrated to 6.9

            width: listView.width

            LabelWithButtonType {
                id: splitTunnelingButton2

                visible: root.isAppSplitTinnelingEnabled

                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.topMargin: 6
                enabled: !globalProxySwitch.checked
                fontFamily: RedaVia.Theme.fontFamily
                cardColor: enabled ? RedaVia.Theme.cardBackground : RedaVia.Theme.cardBackgroundAlt
                cardBorderColor: enabled ? RedaVia.Theme.borderColor : RedaVia.Theme.cardBackgroundAlt
                cardBorderWidth: 1
                cardRadius: RedaVia.Theme.buttonRadius
                textColor: RedaVia.Theme.textPrimary
                textDisabledColor: RedaVia.Theme.textPlaceholder
                descriptionColor: RedaVia.Theme.textSecondary
                descriptionDisabledColor: RedaVia.Theme.textSubtle
                rightImageColor: enabled ? RedaVia.Theme.textPrimary : RedaVia.Theme.textPlaceholder
                leftImageColor: enabled ? RedaVia.Theme.textPrimary : RedaVia.Theme.textPlaceholder

                text: qsTr("App-based split tunneling")
                descriptionText: qsTr("Allows you to use the VPN only for certain Apps")
                rightImageSource: "qrc:/images/controls/chevron-right.svg"

                clickedFunction: function() {
                    console.info("[PageSettingsConnection] App split tunneling button clicked",
                                 "enabled=", splitTunnelingButton2.enabled,
                                 "visible=", splitTunnelingButton2.visible)
                    root.openPageCompatible(PageEnum.PageSettingsAppSplitTunneling)
                }
            }

            DividerType {
                color: RedaVia.Theme.borderColor
                visible: root.isAppSplitTinnelingEnabled
            }

            LabelWithButtonType {
                id: killSwitchButton
                visible: !GC.isMobile()

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

                text: qsTr("KillSwitch")
                descriptionText: qsTr("Blocks network connections without VPN")
                rightImageSource: "qrc:/images/controls/chevron-right.svg"

                clickedFunction: function() {
                    console.info("[PageSettingsConnection] KillSwitch button clicked",
                                 "enabled=", killSwitchButton.enabled,
                                 "visible=", killSwitchButton.visible)
                    root.openPageCompatible(PageEnum.PageSettingsKillSwitch)
                }
            }

            DividerType {
                color: RedaVia.Theme.borderColor
                visible: GC.isDesktop()
            }
        }
    }
}
