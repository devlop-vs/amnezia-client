import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import SortFilterProxyModel 0.2

import PageEnum 1.0

import "../Controls2"
import "../Controls2/TextTypes"


ListViewType {
    id: root

    anchors.fill: parent

    function openPageCompatible(pageEnum, slide) {
        var pagePath = PageController.getPagePath(pageEnum)
        var stackView = root.StackView.view
        if (stackView) {
            stackView.push(pagePath, { "objectName": pagePath }, slide === false ? StackView.Immediate : StackView.PushTransition)
        } else {
            PageController.goToPage(pageEnum, slide === false ? false : true)
        }
    }

    delegate: ColumnLayout {
        width: root.width

        LabelWithButtonType {
            Layout.fillWidth: true

            text: name
            descriptionText: description
            rightImageSource: isInstalled ? "qrc:/images/controls/chevron-right.svg" : "qrc:/images/controls/download.svg"

            clickedFunction: function() {
                if (isInstalled) {
                    var containerIndex = root.model.mapToSource(index)
                    ServersUiController.processedContainerIndex = containerIndex

                    if (isVpnContainer) {
                        // var isThirdPartyConfig = root.model.data(index, ContainersModel.IsThirdPartyConfigRole)
                        if (isThirdPartyConfig) {
                            InstallController.updateProtocols(ServersUiController.processedServerId, containerIndex)
                            root.openPageCompatible(PageEnum.PageProtocolRaw)
                            return
                        }
                    }

                    if (isIpsec) {
                        InstallController.updateProtocols(ServersUiController.processedServerId, containerIndex)
                        root.openPageCompatible(PageEnum.PageProtocolRaw)
                    } else if (isDns) {
                        root.openPageCompatible(PageEnum.PageServiceDnsSettings)
                    } else if (isMtProxy) {
                        MtProxyConfigModel.updateModel(config)
                        root.openPageCompatible(PageEnum.PageServiceMtProxySettings, false)
                    } else if (isTelemt) {
                        TelemtConfigModel.updateModel(config)
                        root.openPageCompatible(PageEnum.PageServiceTelemtSettings, false)
                    } else {
                        InstallController.updateProtocols(ServersUiController.processedServerId, containerIndex)
                        root.openPageCompatible(PageEnum.PageSettingsServerProtocol)
                    }

                } else {
                    var containerIndex = root.model.mapToSource(index)
                    ServersUiController.processedContainerIndex = containerIndex
                    root.openPageCompatible(PageEnum.PageSetupWizardProtocolSettings)
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: false
            }
        }

        DividerType {}
    }
}
