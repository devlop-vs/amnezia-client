import QtQuick
import QtQuick.Controls

import "../RedaVia" as RedaVia

Item {
    id: root

    property string currentCountryCode: ""
    property string currentCountryName: ""
    property string currentProtocolName: ""
    property bool showSubscriptionStatusBar: true
    property bool subscriptionRefreshInProgress: false

    function refreshCurrentServer() {
        root.currentCountryCode = ServersUiController.defaultServerApiCountryCode
        root.currentCountryName = ServersUiController.defaultServerApiCountryName
        root.currentProtocolName = ServersUiController.defaultServerApiServiceProtocol
    }

    function refreshSubscriptionState() {
        if (root.subscriptionRefreshInProgress) {
            return
        }

        var serverId = ServersUiController.defaultServerId
        if (serverId.length === 0 || !ServersUiController.isServerFromApi(serverId)) {
            root.showSubscriptionStatusBar = true
            return
        }

        // Use persisted state immediately, then replace it with the latest
        // account state returned by /v1/account_info.
        root.showSubscriptionStatusBar =
                ServersUiController.isServerSubscriptionExpired(serverId)

        root.subscriptionRefreshInProgress = true
        var result = SubscriptionUiController.getAccountInfo(serverId, false)
        if (result) {
            root.showSubscriptionStatusBar =
                    ApiAccountInfoModel.data("isSubscriptionExpired")
        }
        root.subscriptionRefreshInProgress = false
    }

    function applyLoginAccountSubscriptionState() {
        // Once an API server exists, its persisted state and the latest
        // /v1/account_info response are authoritative.  The login state is a
        // discovery fallback and may still contain the pre-purchase value.
        var serverId = ServersUiController.defaultServerId
        if (serverId.length > 0
                && ServersUiController.isServerFromApi(serverId)) {
            return
        }

        var state = SubscriptionUiController.loginAccountSubscriptionState
        if (state === "none" || state === "expired") {
            root.showSubscriptionStatusBar = true
        } else if (state === "active") {
            root.showSubscriptionStatusBar = false
        }
    }

    signal subscriptionRequested()

    Component.onCompleted: {
        root.refreshCurrentServer()
        root.refreshSubscriptionState()
        root.applyLoginAccountSubscriptionState()
    }

    Connections {
        target: SubscriptionUiController

        function onLoginAccountSubscriptionStateChanged() {
            root.applyLoginAccountSubscriptionState()
        }
    }

    // /v1/account_info can be requested by the subscription/details flow while
    // this page remains below it in the StackView.  Component.onCompleted is
    // not invoked again when that page is popped, so consume the model update
    // directly instead of keeping the pre-purchase visibility value.
    Connections {
        target: ApiAccountInfoModel

        function onModelReset() {
            root.showSubscriptionStatusBar =
                    ApiAccountInfoModel.data("isSubscriptionExpired")
        }
    }

    // External checkout temporarily backgrounds the application. Refresh the
    // persisted server/account state as soon as the user returns from payment.
    Connections {
        target: Qt.application

        function onStateChanged() {
            if (Qt.application.state === Qt.ApplicationActive) {
                root.refreshCurrentServer()
                root.refreshSubscriptionState()
            }
        }
    }

    Connections {
        target: ServersUiController

        function onDefaultServerIdChanged(serverId) {
            root.refreshCurrentServer()
            root.refreshSubscriptionState()
        }
    }

    RedaVia.HomeDisconnected {
        id: homeDisconnected
        anchors.fill: parent
        visible: !ConnectionController.isConnected
        countryCode: root.currentCountryCode
        countryName: root.currentCountryName
        protocolName: root.currentProtocolName
        showSubscriptionStatusBar: root.showSubscriptionStatusBar

        onConnectPressed: {
            ConnectionController.connectButtonClicked()
        }
        onServerChangeRequested: {
            locationsLoader.active = true
        }
        onSubscriptionRequested: root.subscriptionRequested()
    }

    RedaVia.HomeConnected {
        id: homeConnected
        anchors.fill: parent
        visible: ConnectionController.isConnected
        countryCode: root.currentCountryCode
        countryName: root.currentCountryName
        protocolName: root.currentProtocolName

        onDisconnectPressed: {
            ConnectionController.closeConnection()
        }
    }

    Loader {
        id: locationsLoader
        anchors.fill: parent
        active: false
        source: "../RedaVia/LocationsPage.qml"

        Connections {
            target: locationsLoader.item
            function onServerSelected(countryCode, countryName, protocolName) {
                root.currentCountryCode = countryCode
                root.currentCountryName = countryName
                root.currentProtocolName = protocolName
                locationsLoader.active = false
            }
        }
    }
}
