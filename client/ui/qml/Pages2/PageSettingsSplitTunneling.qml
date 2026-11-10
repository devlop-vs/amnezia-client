import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QtCore

import SortFilterProxyModel 0.2

import PageEnum 1.0
import ContainerProps 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"
import "../RedaVia" as RedaVia
import "../Components"

PageType {
    id: root

    Rectangle {
        anchors.fill: parent
        color: RedaVia.Theme.background
        z: -1
    }

    property var isServerFromTelegramApi: ServersUiController.isServerFromApi(ServersUiController.defaultServerId)
    
    property bool pageEnabled

    Component.onCompleted: {
        if (ConnectionController.isConnected) {
            PageController.showNotificationMessage(qsTr("Cannot change split tunneling settings during active connection"))
            root.pageEnabled = false
        } else if (ServersUiController.isDefaultServerDefaultContainerHasSplitTunneling) {
            PageController.showNotificationMessage(qsTr("Default server does not support split tunneling function"))
            root.pageEnabled = false
        } else {
            root.pageEnabled = true
        }
    }

    Connections {
        target: IpSplitTunnelingController

        function onFinished(message) {
            PageController.showNotificationMessage(message)
        }

        function onErrorOccurred(errorMessage) {
            PageController.showErrorMessage(errorMessage)
        }
    }

    QtObject {
        id: routeMode
        property int allSites: 0
        property int onlyForwardSites: 1
        property int allExceptSites: 2
    }

    property list<QtObject> routeModesModel: [
        onlyForwardSites,
        allExceptSites
    ]

    QtObject {
        id: onlyForwardSites
        property string name: qsTr("Only the sites listed here will be accessed through the VPN")
        property int type: routeMode.onlyForwardSites
    }
    QtObject {
        id: allExceptSites
        property string name: qsTr("Addresses from the list should not be accessed via VPN")
        property int type: routeMode.allExceptSites
    }

    function getRouteModesModelIndex() {
        var currentRouteMode = IpSplitTunnelingController.routeMode
        if ((routeMode.onlyForwardSites === currentRouteMode) || (routeMode.allSites === currentRouteMode)) {
            return 0
        } else if (routeMode.allExceptSites === currentRouteMode) {
            return 1
        }
    }

    ColumnLayout {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        anchors.topMargin: 20 + PageController.safeAreaTopMargin

        BackButtonType {
            id: backButton
            backButtonImageColor: RedaVia.Theme.textPrimary
        }

        HeaderTypeWithSwitcher {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16

            fontFamily: RedaVia.Theme.fontFamily
            headerTextColor: RedaVia.Theme.textPrimary
            descriptionTextColor: RedaVia.Theme.textSecondary

            headerText: qsTr("Split tunneling")

            enabled: root.pageEnabled
            showSwitcher: true
            switcher {
                checked: IpSplitTunnelingController.isSplitTunnelingEnabled
                enabled: root.pageEnabled
            }
            switcherFunction: function(checked) {
                IpSplitTunnelingController.toggleSplitTunneling(checked)
                selector.text = root.routeModesModel[getRouteModesModelIndex()].name
            }
        }

        DropDownType {
            id: selector
            fontFamily: RedaVia.Theme.fontFamily
            headerTextColor: RedaVia.Theme.textPrimary
            drawerBackgroundColor: RedaVia.Theme.background
            drawerBorderColor: RedaVia.Theme.borderColor
            backButtonImageColor: RedaVia.Theme.textPrimary
            textColor: RedaVia.Theme.textPrimary
            textDisabledColor: RedaVia.Theme.textSecondary
            descriptionTextColor: RedaVia.Theme.textSecondary
            rootButtonImageColor: RedaVia.Theme.textPrimary
            rootButtonBackgroundColor: RedaVia.Theme.cardBackground
            rootButtonBackgroundHoveredColor: RedaVia.Theme.cardBackgroundAlt
            rootButtonBackgroundPressedColor: RedaVia.Theme.cardBackgroundAlt
            rootButtonDefaultBorderColor: RedaVia.Theme.borderColor
            rootButtonHoveredBorderColor: RedaVia.Theme.primaryGreen
            rootButtonPressedBorderColor: RedaVia.Theme.primaryGreen
            borderFocusedColor: RedaVia.Theme.primaryGreen

            Layout.fillWidth: true
            Layout.topMargin: 32
            Layout.leftMargin: 16
            Layout.rightMargin: 16

            drawerHeight: 0.4375
            drawerParent: root

            enabled: root.pageEnabled
            headerText: qsTr("Mode")

            listView: ListViewWithRadioButtonType {
                rootWidth: root.width
                fontFamily: RedaVia.Theme.fontFamily
                textColor: RedaVia.Theme.textPrimary
                defaultColor: RedaVia.Theme.background
                hoveredColor: RedaVia.Theme.cardBackgroundAlt
                focusedBorderColor: RedaVia.Theme.primaryGreen

                model: root.routeModesModel

                selectedIndex: getRouteModesModelIndex()

                clickedFunction: function() {
                    selector.text = selectedText
                    selector.closeTriggered()
                    if (IpSplitTunnelingController.routeMode !== root.routeModesModel[selectedIndex].type) {
                        IpSplitTunnelingController.routeMode = root.routeModesModel[selectedIndex].type
                    }
                }

                Component.onCompleted: {
                    if (root.routeModesModel[selectedIndex].type === IpSplitTunnelingController.routeMode) {
                        selector.text = selectedText
                    } else {
                        selector.text = root.routeModesModel[0].name
                    }
                }

                Connections {
                    target: IpSplitTunnelingController
                    function onRouteModeChanged() {
                        selectedIndex = getRouteModesModelIndex()
                    }
                }
            }
        }
    }

    ListViewType {
        id: listView

        ScrollBar.vertical: ScrollBarType { policy: ScrollBar.AlwaysOn }

        anchors.top: header.bottom
        anchors.topMargin: 16
        anchors.bottom: parent.bottom
        anchors.bottomMargin: addSiteButton.implicitHeight + 48 + (searchField.textField.activeFocus ? 0 : PageController.imeHeight)

        width: parent.width

        enabled: root.pageEnabled
        clip: true

        model: SortFilterProxyModel {
            id: proxyIpSplitTunnelingModel
            sourceModel: IpSplitTunnelingModel
            filters: [
                AnyOf {
                    RegExpFilter {
                        roleName: "url"
                        pattern: ".*" + searchField.textField.text + ".*"
                        caseSensitivity: Qt.CaseInsensitive
                    }
                    RegExpFilter {
                        roleName: "ip"
                        pattern: ".*" + searchField.textField.text + ".*"
                        caseSensitivity: Qt.CaseInsensitive
                    }
                }
            ]
        }

        delegate: ColumnLayout {
            width: listView.width

            LabelWithButtonType {
                id: site
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                fontFamily: RedaVia.Theme.fontFamily
                cardColor: RedaVia.Theme.cardBackground
                cardBorderColor: RedaVia.Theme.borderColor
                cardBorderWidth: 1
                cardRadius: RedaVia.Theme.buttonRadius
                textColor: RedaVia.Theme.textPrimary
                descriptionColor: RedaVia.Theme.textSecondary
                rightImageColor: RedaVia.Theme.textPrimary
                leftImageColor: RedaVia.Theme.textPrimary

                text: url
                descriptionText: ip
                rightImageSource: "qrc:/images/controls/trash.svg"

                clickedFunction: function() {
                    var headerText = qsTr("Remove ") + url + "?"
                    var yesButtonText = qsTr("Continue")
                    var noButtonText = qsTr("Cancel")

                    var yesButtonFunction = function() {
                        IpSplitTunnelingController.removeSite(proxyIpSplitTunnelingModel.mapToSource(index))
                        if (!GC.isMobile()) {
                            site.rightButton.forceActiveFocus()
                        }
                    }
                    var noButtonFunction = function() {
                        if (!GC.isMobile()) {
                            site.rightButton.forceActiveFocus()
                        }
                    }

                    showQuestionDrawer(headerText, "", yesButtonText, noButtonText, yesButtonFunction, noButtonFunction)
                }
            }

            DividerType { visible: false }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        
        height: addSiteButton.implicitHeight + 48
        
        color: RedaVia.Theme.background
        
        RowLayout {
            id: addSiteButton

            enabled: root.pageEnabled

            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 24
            anchors.rightMargin: 16
            anchors.leftMargin: 16
            anchors.bottomMargin: 24

            TextFieldWithHeaderType {
                fontFamily: RedaVia.Theme.fontFamily
                headerTextColor: RedaVia.Theme.textSecondary
                textFieldTextColor: RedaVia.Theme.textPrimary
                textFieldPlaceholderTextColor: RedaVia.Theme.textPlaceholder
                borderColor: RedaVia.Theme.borderColor
                borderFocusedColor: RedaVia.Theme.primaryGreen
                backgroundColor: RedaVia.Theme.cardBackground
                backgroundDisabledColor: RedaVia.Theme.cardBackground
                bgBorderHoveredColor: RedaVia.Theme.cardBackgroundAlt
                backgroundRadius: RedaVia.Theme.inputRadius
                id: searchField

                Layout.fillWidth: true
                rightButtonClickedOnEnter: true

                textField.placeholderText: qsTr("website or IP")
                buttonImageSource: "qrc:/images/controls/plus.svg"

                clickedFunc: function() {
                    PageController.showBusyIndicator(true)
                    IpSplitTunnelingController.addSite(textField.text)
                    textField.text = ""
                    PageController.showBusyIndicator(false)
                }
            }

            ImageButtonType {
                id: addSiteButtonImage
                implicitWidth: 56
                implicitHeight: 56

                image: "qrc:/images/controls/more-vertical.svg"
                imageColor: RedaVia.Theme.textPrimary

                onClicked: function () {
                    moreActionsDrawer.openTriggered()
                }

                Keys.onReturnPressed: addSiteButtonImage.clicked()
                Keys.onEnterPressed: addSiteButtonImage.clicked()
            }
        }
    }

    DrawerType2 {
        id: moreActionsDrawer

        anchors.fill: parent
        expandedHeight: parent.height * 0.4375
        defaultColor: RedaVia.Theme.background
        borderColor: RedaVia.Theme.borderColor

        expandedStateContent: ColumnLayout {
            id: moreActionsDrawerContent

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right

            Header2Type {
                Layout.fillWidth: true
                Layout.margins: 16

                fontFamily: RedaVia.Theme.fontFamily
                headerTextColor: RedaVia.Theme.textPrimary
                descriptionTextColor: RedaVia.Theme.textSecondary
                headerText: qsTr("Additional options")
            }

            LabelWithButtonType {
                id: importSitesButton
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                fontFamily: RedaVia.Theme.fontFamily
                cardColor: RedaVia.Theme.cardBackground
                cardBorderColor: RedaVia.Theme.borderColor
                cardBorderWidth: 1
                cardRadius: RedaVia.Theme.buttonRadius
                textColor: RedaVia.Theme.textPrimary
                rightImageColor: RedaVia.Theme.textPrimary

                text: qsTr("Import")
                rightImageSource: "qrc:/images/controls/chevron-right.svg"

                clickedFunction: function() {
                    importSitesDrawer.openTriggered()
                }
            }

            DividerType { visible: false }

            LabelWithButtonType {
                id: exportSitesButton
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                fontFamily: RedaVia.Theme.fontFamily
                cardColor: RedaVia.Theme.cardBackground
                cardBorderColor: RedaVia.Theme.borderColor
                cardBorderWidth: 1
                cardRadius: RedaVia.Theme.buttonRadius
                textColor: RedaVia.Theme.textPrimary

                text: qsTr("Save site list")

                clickedFunction: function() {
                    var fileName = ""
                    if (GC.isMobile()) {
                        fileName = "amnezia_sites.json"
                    } else {
                        fileName = SystemController.getFileName(qsTr("Save sites"),
                                                                qsTr("Sites files (*.json)"),
                                                                StandardPaths.standardLocations(StandardPaths.DocumentsLocation) + "/amnezia_sites",
                                                                true,
                                                                ".json")
                    }
                    if (fileName !== "") {
                        PageController.showBusyIndicator(true)
                        IpSplitTunnelingController.exportSites(fileName)
                        moreActionsDrawer.closeTriggered()
                        PageController.showBusyIndicator(false)
                    }
                }
            }

            DividerType { visible: false }
            
            LabelWithButtonType {
                id: clearSitesButton
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                fontFamily: RedaVia.Theme.fontFamily
                cardColor: RedaVia.Theme.cardBackground
                cardBorderColor: RedaVia.Theme.borderColor
                cardBorderWidth: 1
                cardRadius: RedaVia.Theme.buttonRadius
                textColor: RedaVia.Theme.textPrimary

                text: qsTr("Clear site list")

                clickedFunction: function() {
                    var headerText = qsTr("Clear site list?")
                    var descriptionText = qsTr("All sites will be removed from list.")
                    var yesButtonText = qsTr("Continue")
                    var noButtonText = qsTr("Cancel")

                    var yesButtonFunction = function() {
                        PageController.showBusyIndicator(true)
                        IpSplitTunnelingController.removeSites()
                        PageController.showBusyIndicator(false)
                    }
                    var noButtonFunction = function() {
                        
                    }

                    showQuestionDrawer(headerText, descriptionText, yesButtonText, noButtonText, yesButtonFunction, noButtonFunction)
                }
            }

            DividerType { visible: false }
        }
    }

    DrawerType2 {
        id: importSitesDrawer

        anchors.fill: parent
        expandedHeight: parent.height * 0.4375
        defaultColor: RedaVia.Theme.background
        borderColor: RedaVia.Theme.borderColor

        expandedStateContent: Item {
            implicitHeight: importSitesDrawer.expandedHeight

            BackButtonType {
                id: importSitesDrawerBackButton
                backButtonImageColor: RedaVia.Theme.textPrimary

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 16

                backButtonFunction: function() {
                    importSitesDrawer.closeTriggered()
                }
                
                onFocusChanged: {
                    if (this.activeFocus) {
                        importSitesDrawerListView.positionViewAtBeginning()
                    }
                }
            }

            ListViewType {
                id: importSitesDrawerListView

                anchors.top: importSitesDrawerBackButton.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                header: ColumnLayout {
                    width: importSitesDrawerListView.width

                    Header2Type {
                        Layout.fillWidth: true
                        Layout.margins: 16

                        fontFamily: RedaVia.Theme.fontFamily
                        headerTextColor: RedaVia.Theme.textPrimary
                        descriptionTextColor: RedaVia.Theme.textSecondary
                        headerText: qsTr("Import a list of sites")
                    }
                }

                model: importOptions

                delegate: ColumnLayout {
                    width: importSitesDrawerListView.width

                    LabelWithButtonType {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16

                        fontFamily: RedaVia.Theme.fontFamily
                        cardColor: RedaVia.Theme.cardBackground
                        cardBorderColor: RedaVia.Theme.borderColor
                        cardBorderWidth: 1
                        cardRadius: RedaVia.Theme.buttonRadius
                        textColor: RedaVia.Theme.textPrimary

                        text: title

                        clickedFunction: function() {
                            clickedHandler()
                        }
                    }

                    DividerType { visible: false }
                }
            }
        }
    }

    property list<QtObject> importOptions: [
        replaceOption,
        addOption,
    ]

    QtObject {
        id: replaceOption

        readonly property string title: qsTr("Replace site list")
        readonly property var clickedHandler: function() {
            var fileName = SystemController.getFileName(qsTr("Open sites file"),
                                                        qsTr("Sites files (*.json)"))
            if (fileName !== "") {
                root.importSites(fileName, true)
            }
        }
    }

    QtObject {
        id: addOption

        readonly property string title: qsTr("Add imported sites to existing ones")
        readonly property var clickedHandler: function() {
            var fileName = SystemController.getFileName(qsTr("Open sites file"),
                                                        qsTr("Sites files (*.json)"))
            if (fileName !== "") {
                root.importSites(fileName, false)
            }
        }
    }

    function importSites(fileName, replaceExistingSites) {
        PageController.showBusyIndicator(true)
        IpSplitTunnelingController.importSites(fileName, replaceExistingSites)
        PageController.showBusyIndicator(false)
        importSitesDrawer.closeTriggered()
        moreActionsDrawer.closeTriggered()
    }
}
