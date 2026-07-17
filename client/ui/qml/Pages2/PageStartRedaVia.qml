import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes

import PageEnum 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"
import "../Components"

PageType {
    id: root

    property bool isControlsDisabled: false

    Connections {
        target: PageController

        function onGoToPageHome() {
            stackView.goToRedaViaPage("qrc:/ui/qml/Pages2/PageRedaVia.qml", "PageRedaVia")
            tabBar.currentIndex = 0
        }

        function onDisableControls(disabled) {
            isControlsDisabled = disabled
        }

        function onClosePage() {
            if (stackView.depth <= 1) {
                PageController.hideWindow()
                return
            }
            stackView.pop()
        }

        function onGoToPage(page, slide) {
            var pagePath = PageController.getPagePath(page)
            if (slide) {
                stackView.push(pagePath, { "objectName" : pagePath }, StackView.PushTransition)
            } else {
                stackView.push(pagePath, { "objectName" : pagePath }, StackView.Immediate)
            }
        }

        function onGoToStartPage() {
            while (stackView.depth > 1) {
                stackView.pop()
            }
        }

        function onEscapePressed() {
            if (root.isControlsDisabled) {
                return
            }
            if (stackView.depth <= 1) {
                PageController.hideWindow()
            } else {
                PageController.closePage()
            }
        }
    }

    Connections {
        target: ImportController

        function onImportErrorOccurred(error, goToPageHome) {
            PageController.showErrorMessage(error)
        }

        function onRestoreAppConfig(data) {
            PageController.showBusyIndicator(true)
            SettingsController.restoreAppConfigFromData(data)
            PageController.showBusyIndicator(false)
        }
    }

    Connections {
        target: SettingsController

        function onRestoreBackupFinished() {
            PageController.showNotificationMessage(qsTr("Settings restored from backup file"))
            PageController.goToPageHome()
        }
    }

    StackViewType {
        id: stackView
        objectName: "redaViaStackView"

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.left: parent.left
        anchors.bottom: tabBar.top

        enabled: !root.isControlsDisabled

        function goToRedaViaPage(pagePath, objectName) {
            stackView.clear(StackView.Immediate)
            stackView.replace(pagePath, { "objectName" : objectName }, StackView.Immediate)
        }

        Component.onCompleted: {
            stackView.push("qrc:/ui/qml/Pages2/PageRedaVia.qml",
                { "objectName" : "PageRedaVia" })
        }

        Keys.onPressed: function(event) {
            switch (event.key) {
            case Qt.Key_Tab:
            case Qt.Key_Down:
            case Qt.Key_Right:
                FocusController.nextKeyTabItem()
                break
            case Qt.Key_Backtab:
            case Qt.Key_Up:
            case Qt.Key_Left:
                FocusController.previousKeyTabItem()
                break
            default:
                PageController.keyPressEvent(event.key)
                event.accepted = true
            }
        }
    }

    TabBar {
        id: tabBar
        objectName: "redaViaTabBar"

        anchors.right: parent.right
        anchors.left: parent.left
        anchors.bottom: parent.bottom

        anchors.bottomMargin: PageController.imeHeight

        topPadding: 8
        bottomPadding: 8 + PageController.safeAreaBottomMargin
        leftPadding: 72
        rightPadding: 72

        height: homeTabButton.implicitHeight + tabBar.topPadding + tabBar.bottomPadding

        enabled: !root.isControlsDisabled

        background: Shape {
            width: parent.width
            height: parent.height

            ShapePath {
                startX: 0
                startY: 0

                PathLine { x: width; y: 0 }
                PathLine { x: width; y: tabBar.height - 1 }
                PathLine { x: 0; y: tabBar.height - 1 }
                PathLine { x: 0; y: 0 }

                strokeWidth: 1
                strokeColor: AmneziaStyle.color.slateGray
                fillColor: AmneziaStyle.color.onyxBlack
            }
        }

        TabImageButtonType {
            id: homeTabButton
            objectName: "redaViaHomeTabButton"

            isSelected: tabBar.currentIndex === 0
            image: "qrc:/images/controls/home.svg"
            clickedFunc: function () {
                stackView.goToRedaViaPage("qrc:/ui/qml/Pages2/PageRedaVia.qml", "PageRedaVia")
                tabBar.currentIndex = 0
            }
        }

        TabImageButtonType {
            id: locationsTabButton
            objectName: "redaViaLocationsTabButton"

            isSelected: tabBar.currentIndex === 1
            image: "qrc:/images/controls/map-pin.svg"
            clickedFunc: function () {
                stackView.goToRedaViaPage("qrc:/ui/qml/RedaVia/LocationsPage.qml", "LocationsPage")
                tabBar.currentIndex = 1
            }
        }

        TabImageButtonType {
            id: subscriptionTabButton
            objectName: "redaViaSubscriptionTabButton"

            isSelected: tabBar.currentIndex === 2
            image: "qrc:/images/controls/infinity.svg"
            clickedFunc: function () {
                PageController.showBusyIndicator(true)
                var result = SubscriptionUiController.fillAvailableServices()
                PageController.showBusyIndicator(false)
                if (result) {
                    PageController.goToPage(PageEnum.PageSetupWizardApiServicesList)
                }
                tabBar.currentIndex = 2
            }
        }

        TabImageButtonType {
            id: profileTabButton
            objectName: "redaViaProfileTabButton"

            isSelected: tabBar.currentIndex === 3
            image: "qrc:/images/controls/settings.svg"
            clickedFunc: function () {
                stackView.goToRedaViaPage("qrc:/ui/qml/RedaVia/ProfilePage.qml", "ProfilePage")
                tabBar.currentIndex = 3
            }
        }
    }
}
