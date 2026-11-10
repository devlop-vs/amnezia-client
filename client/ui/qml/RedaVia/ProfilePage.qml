import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    width: StackView.view ? StackView.view.width : Theme.screenWidth
    height: StackView.view ? StackView.view.height : Theme.screenHeight
    radius: Theme.screenRadius
    color: Theme.background
    clip: true

    signal menuItemClicked(string item)
    signal settingsRequested()
    signal connectionSettingsRequested()
    signal appearanceRequested()
    signal aboutRequested()

    property string displayInitial: "?"
    property string displayName: qsTr("Guest")
    property string displaySubtitle: qsTr("Sign in to your account")

    property var menuItems: [
        { "key": "account", "text": qsTr("Account") },
        { "key": "reloadConfig", "text": qsTr("Reload Config") },
        { "key": "oldSettings", "text": qsTr("Old Settings") },
        { "key": "subscriptions", "text": qsTr("Subscriptions") },
        { "key": "refreshAccount", "text": qsTr("Refresh Account") },
        { "key": "resetPubkeys", "text": qsTr("Reset Pubkeys") },
        { "key": "connectionSettings", "text": qsTr("Connection Settings") },
        { "key": "killSwitch", "text": qsTr("Kill Switch") },
        { "key": "application", "text": qsTr("Application") },
        { "key": "helpAbout", "text": qsTr("Help & About") }
    ]

    function reloadVpnConfigFromGateway() {
        var serverId = ServersUiController.defaultServerId

        if (serverId.length === 0) {
            PageController.showNotificationMessage(qsTr("No VPN configuration installed"))
            return
        }
        if (!ServersUiController.isServerFromApi(serverId)) {
            PageController.showNotificationMessage(qsTr("Current VPN configuration cannot be reloaded from API"))
            return
        }
        if (ConnectionController.isConnected) {
            PageController.showNotificationMessage(qsTr("Cannot reload API config during active connection"))
            return
        }

        console.log("[RedaVia] Reload VPN config from API for serverId:", serverId)
        PageController.showBusyIndicator(true)
        SubscriptionUiController.updateServiceFromGateway(serverId, "", "", true)
        PageController.showBusyIndicator(false)
    }

    function resetVpnClientIdentityFromGateway() {
        var serverId = ServersUiController.defaultServerId

        if (serverId.length === 0) {
            PageController.showNotificationMessage(qsTr("No VPN configuration installed"))
            return
        }
        if (!ServersUiController.isServerFromApi(serverId)) {
            PageController.showNotificationMessage(qsTr("Current VPN configuration cannot be reloaded from API"))
            return
        }
        if (ConnectionController.isConnected) {
            PageController.showNotificationMessage(qsTr("Cannot reload API config during active connection"))
            return
        }

        console.log("[RedaVia] Reset VPN client identity from API for serverId:", serverId)
        PageController.showBusyIndicator(true)
        SubscriptionUiController.resetServiceClientIdentity(serverId)
        PageController.showBusyIndicator(false)
    }

    function openSubscriptionSettings() {
        var serverId = ServersUiController.defaultServerId

        if (serverId.length === 0) {
            PageController.showNotificationMessage(qsTr("No VPN configuration installed"))
            return
        }
        if (!ServersUiController.isServerFromApi(serverId)) {
            PageController.showNotificationMessage(qsTr("Current VPN configuration does not support subscription settings"))
            return
        }

        ServersUiController.setProcessedServerId(serverId)
        PageController.showBusyIndicator(true)
        var result = SubscriptionUiController.getAccountInfo(serverId, false)
        PageController.showBusyIndicator(false)
        if (!result) {
            return
        }

        var sv = root.StackView.view
        if (sv) {
            var pagePath = "qrc:/ui/qml/Pages2/PageSettingsApiServerInfo.qml"
            sv.push(pagePath, { "objectName": pagePath }, StackView.PushTransition)
        }
    }

    function refreshAccount() {
        if (!AuthController.isLoggedIn || AuthController.userEmail.length === 0) {
            PageController.showNotificationMessage(qsTr("Please sign in to refresh your account"))
            return
        }

        console.log("[RedaVia] Refresh account subscription for:", AuthController.userEmail)
        var started = SubscriptionUiController.getAccountInfoByEmail(AuthController.userEmail)
        if (!started) {
            PageController.showNotificationMessage(qsTr("Unable to refresh account"))
        }
    }

    function refreshProfileData() {
        if (AuthController.isLoggedIn && AuthController.userEmail.length > 0) {
            displayInitial = AuthController.userEmail.charAt(0).toUpperCase()
            displayName = AuthController.userEmail.split("@")[0]
            displaySubtitle = AuthController.userEmail
        } else {
            displayInitial = "?"
            displayName = qsTr("Guest")
            displaySubtitle = qsTr("Sign in to your account")
        }
    }

    Component.onCompleted: refreshProfileData()

    Connections {
        target: AuthController

        function onLoginSuccess(email) {
            root.refreshProfileData()
        }

        function onLoginStateChanged() {
            root.refreshProfileData()
        }

        function onUserInfoChanged() {
            root.refreshProfileData()
        }
    }

    Connections {
        target: SubscriptionUiController

        function onResetServiceClientIdentityFailed(message) {
            PageController.showNotificationMessage(message)
        }
    }

    onMenuItemClicked: function(item) {
        if (item === "account") {
            var sv = root.StackView.view
            if (sv) {
                sv.push("qrc:/ui/qml/RedaVia/AccessPage.qml")
            }
        } else if (item === "oldSettings") {
            root.settingsRequested()
        } else if (item === "connectionSettings") {
            root.connectionSettingsRequested()
        } else if (item === "application") {
            root.appearanceRequested()
        } else if (item === "helpAbout") {
            root.aboutRequested()
        } else if (item === "reloadConfig") {
            root.reloadVpnConfigFromGateway()
        } else if (item === "killSwitch") {
            var sv = root.StackView.view
            if (sv) {
                var pagePath = "qrc:/ui/qml/Pages2/PageSettingsKillSwitch.qml"
                sv.push(pagePath, { "objectName": pagePath }, StackView.PushTransition)
            }
        } else if (item === "resetPubkeys") {
            root.resetVpnClientIdentityFromGateway()
        } else if (item === "subscriptions") {
            root.openSubscriptionSettings()
        } else if (item === "refreshAccount") {
            root.refreshAccount()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        //StatusBar { Layout.fillWidth: true }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 14
            text: qsTr("Profile")
            font { family: Theme.fontFamily; pixelSize: 24; bold: true }
            color: Theme.textPrimary
            horizontalAlignment: Text.AlignHCenter
        }

        // Avatar
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            Layout.topMargin: 20

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 100; height: 100; radius: 50
                color: Theme.accentBlue

                Text {
                    anchors.centerIn: parent
                    text: root.displayInitial
                    font { family: Theme.fontFamily; pixelSize: 27; bold: true }
                    color: Theme.textPrimary
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 16
            text: root.displayName
            font { family: Theme.fontFamily; pixelSize: 21; weight: Font.DemiBold }
            color: Theme.textPrimary
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 6
            text: root.displaySubtitle
            font { family: Theme.fontFamily; pixelSize: 13 }
            color: Theme.textSecondary
            horizontalAlignment: Text.AlignHCenter
        }

        // Menu items
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.topMargin: 24
            spacing: 8
            clip: true

            footer: Item {
                width: ListView.view ? ListView.view.width : 0
                height: root.StackView.view ? root.StackView.view.bottomNavigationHeight : 0
            }

            model: root.menuItems

            delegate: Rectangle {
                width: ListView.view.width
                height: 43
                radius: Theme.smallRadius
                color: menuMouse.containsMouse ? Qt.lighter(Theme.cardBackground, 1.15) : Theme.cardBackground

                Behavior on color { ColorAnimation { duration: 150 } }

                scale: menuMouse.pressed ? 0.97 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20

                    Text {
                        text: modelData.text
                        font { family: Theme.fontFamily; pixelSize: 14; weight: Font.Medium }
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "›"
                        font { family: Theme.fontFamily; pixelSize: 22 }
                        color: Theme.textSecondary
                    }
                }

                MouseArea {
                    id: menuMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.menuItemClicked(modelData.key)
                }
            }
        }
    }

    // Bottom navigation is provided by PageStartRedaVia's TabBar.
}
