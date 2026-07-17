import QtQuick
import QtQuick.Controls

import "../RedaVia" as RedaVia

Item {
    id: root

    RedaVia.HomeDisconnected {
        id: homeDisconnected
        anchors.fill: parent
        visible: !homeConnected.visible

        onConnectPressed: {
            homeConnected.visible = true
        }
        onServerChangeRequested: {
            locationsLoader.active = true
        }
    }

    RedaVia.HomeConnected {
        id: homeConnected
        anchors.fill: parent
        visible: false

        onDisconnectPressed: {
            homeConnected.visible = false
        }
    }

    Loader {
        id: locationsLoader
        anchors.fill: parent
        active: false
        source: "../RedaVia/LocationsPage.qml"

        Connections {
            target: locationsLoader.item
            function onServerSelected(country) {
                locationsLoader.active = false
            }
        }
    }
}
