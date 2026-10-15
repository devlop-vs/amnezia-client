import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import PageEnum 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Config"

PageType {
    id: root

    property bool isAppSplitTinnelingEnabled: Qt.platform.os === "windows" || Qt.platform.os === "android"

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

                headerText: qsTr("Connection")
            }
        }

        model: 1 // fake model to force the ListView to be created without a model

        delegate: ColumnLayout { // TODO(CyAn84): add DelegateChooser when have migrated to 6.9

            width: listView.width

            SwitcherType {
                id: amneziaDnsSwitch

                Layout.fillWidth: true
                Layout.margins: 16

                text: qsTr("Use AmneziaDNS")
                descriptionText: qsTr("If AmneziaDNS is installed on the server")

                checked: SettingsController.isAmneziaDnsEnabled()
                onToggled: function() {
                    if (checked !== SettingsController.isAmneziaDnsEnabled()) {
                        SettingsController.toggleAmneziaDns(checked)
                    }
                }
            }

            DividerType {}

            LabelWithButtonType {
                id: dnsServersButton

                Layout.fillWidth: true

                text: qsTr("DNS servers")
                descriptionText: qsTr("When AmneziaDNS is not used or installed")
                rightImageSource: "qrc:/images/controls/chevron-right.svg"

                clickedFunction: function() {
                    root.openPageCompatible(PageEnum.PageSettingsDns)
                }
            }

            DividerType {}

            LabelWithButtonType {
                id: splitTunnelingButton

                Layout.fillWidth: true

                text: qsTr("Site-based split tunneling")
                descriptionText: qsTr("Allows you to select which sites you want to access through the VPN")
                rightImageSource: "qrc:/images/controls/chevron-right.svg"

                clickedFunction: function() {
                    root.openPageCompatible(PageEnum.PageSettingsSplitTunneling)
                }
            }

            DividerType {}

        }

        footer: ColumnLayout { // TODO(CyAn84): move to delegate,add DelegateChooser when have migrated to 6.9

            width: listView.width

            LabelWithButtonType {
                id: splitTunnelingButton2

                visible: root.isAppSplitTinnelingEnabled

                Layout.fillWidth: true

                text: qsTr("App-based split tunneling")
                descriptionText: qsTr("Allows you to use the VPN only for certain Apps")
                rightImageSource: "qrc:/images/controls/chevron-right.svg"

                clickedFunction: function() {
                    root.openPageCompatible(PageEnum.PageSettingsAppSplitTunneling)
                }
            }

            DividerType {
                visible: root.isAppSplitTinnelingEnabled
            }

            LabelWithButtonType {
                id: killSwitchButton
                visible: !GC.isMobile()

                Layout.fillWidth: true

                text: qsTr("KillSwitch")
                descriptionText: qsTr("Blocks network connections without VPN")
                rightImageSource: "qrc:/images/controls/chevron-right.svg"

                clickedFunction: function() {
                    root.openPageCompatible(PageEnum.PageSettingsKillSwitch)
                }
            }

            DividerType {
                visible: GC.isDesktop()
            }
        }
    }
}
