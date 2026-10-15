import QtQuick
import QtQuick.Controls

import "../RedaVia" as RedaVia

Item {
    id: root

    property string currentCountryCode: ""
    property string currentCountryName: ""
    property string currentProtocolName: ""

    function refreshCurrentServer() {
        root.currentCountryCode = ServersUiController.defaultServerApiCountryCode
        root.currentCountryName = ServersUiController.defaultServerApiCountryName
        root.currentProtocolName = ServersUiController.defaultServerApiServiceProtocol
    }

    Component.onCompleted: root.refreshCurrentServer()

    Connections {
        target: ServersUiController

        function onDefaultServerIdChanged(serverId) {
            root.refreshCurrentServer()
        }
    }

    RedaVia.HomeDisconnected {
        id: homeDisconnected
        anchors.fill: parent
        visible: !ConnectionController.isConnected
        countryCode: root.currentCountryCode
        countryName: root.currentCountryName
        protocolName: root.currentProtocolName

        onConnectPressed: {
            ConnectionController.connectButtonClicked()
        }
        onServerChangeRequested: {
            locationsLoader.active = true
        }
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
