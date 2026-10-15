import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    width: Theme.screenWidth
    height: Theme.screenHeight
    radius: Theme.screenRadius
    color: Theme.background
    clip: true

    property int activeFilter: 0
    property var expandedCountries: ({})
    readonly property var protocolFilters: [
        { label: qsTr("All"), protocol: "" },
        { label: qsTr("WireGuard"), protocol: "wireguard" },
        { label: qsTr("OpenVPN"), protocol: "openvpn" },
        { label: qsTr("VLESS"), protocol: "vless" }
    ]
    signal serverSelected(string countryCode, string countryName, string protocolName)

    function selectedProtocol() {
        if (root.activeFilter < 0 || root.activeFilter >= root.protocolFilters.length) {
            return ""
        }
        return root.protocolFilters[root.activeFilter].protocol
    }

    function selectedRequestProtocol() {
        var protocol = root.selectedProtocol()
        return protocol.length === 0 ? "wireguard" : protocol
    }

    function matchesProtocol(countryIndex) {
        var protocol = root.selectedProtocol()
        if (protocol.length === 0) {
            return true
        }
        return ApiCountryModel.supportsProtocol(countryIndex, protocol)
    }

    function matchesSearch(countryName, countryCode, cityNames) {
        countryName = countryName || ""
        countryCode = countryCode || ""
        cityNames = cityNames || []
        var searchText = searchInput.text.trim().toLowerCase()
        if (searchText.length === 0) {
            return true
        }

        if (countryName.toLowerCase().indexOf(searchText) !== -1
                || countryCode.toLowerCase().indexOf(searchText) !== -1) {
            return true
        }
        for (var i = 0; i < cityNames.length; ++i) {
            var cityName = cityNames[i] || ""
            if (cityName.toLowerCase().indexOf(searchText) !== -1) {
                return true
            }
        }
        return false
    }

    function matchesFilters(countryIndex, countryName, countryCode, cityNames) {
        return root.matchesSearch(countryName, countryCode, cityNames)
            && root.matchesProtocol(countryIndex)
    }

    function countryKey(countryCode, countryIndex) {
        countryCode = countryCode || ""
        return countryCode.length > 0 ? countryCode : ("index-" + countryIndex)
    }

    function isCountryExpanded(countryCode, countryIndex) {
        return root.expandedCountries[root.countryKey(countryCode, countryIndex)] === true
    }

    function toggleCountryExpanded(countryCode, countryIndex) {
        var key = root.countryKey(countryCode, countryIndex)
        var nextState = root.expandedCountries[key] !== true
        var states = {}
        for (var existingKey in root.expandedCountries) {
            states[existingKey] = root.expandedCountries[existingKey]
        }
        states[key] = nextState
        root.expandedCountries = states
    }

    function cityItems(cityNames, cityRequestNames) {
        cityNames = cityNames || []
        cityRequestNames = cityRequestNames || []
        var items = []
        var count = Math.min(cityNames.length, cityRequestNames.length)
        for (var i = 0; i < count; ++i) {
            var cityName = cityNames[i] || ""
            var cityRequestName = cityRequestNames[i] || cityName
            items.push({ name: cityName, requestName: cityRequestName, isDefault: cityName === "Default" })
        }
        return items
    }

    function activateProtocolFilter(filterIndex) {
        if (filterIndex < 0 || filterIndex >= root.protocolFilters.length) {
            return
        }
        if (filterIndex === root.activeFilter) {
            return
        }

        root.activeFilter = filterIndex
    }

    function flagEmoji(countryCode) {
        countryCode = countryCode || ""
        var code = countryCode.toUpperCase()
        if (code.length !== 2) {
            return "🌐"
        }

        return String.fromCodePoint(0x1F1E6 + code.charCodeAt(0) - 65,
                                    0x1F1E6 + code.charCodeAt(1) - 65)
    }

    function locationsText(countryCode) {
        countryCode = countryCode || ""
        switch (countryCode.toUpperCase()) {
        case "GB": return "16 Locations"
        case "US": return "16 Locations"
        case "FR": return "19 Locations"
        case "DE": return "19 Locations"
        case "CA": return "16 Locations"
        case "SG": return "12 Locations"
        case "JP": return "11 Locations"
        default: return "1 Location"
        }
    }

    function pingText(countryCode) {
        countryCode = countryCode || ""
        switch (countryCode.toUpperCase()) {
        case "GB": return "16 ms"
        case "US": return "167 ms"
        case "FR": return "67 ms"
        case "DE": return "67 ms"
        case "CA": return "89 ms"
        case "SG": return "38 ms"
        case "JP": return "65 ms"
        default: return "-- ms"
        }
    }

    function pingColor(countryCode) {
        countryCode = countryCode || ""
        switch (countryCode.toUpperCase()) {
        case "US": return "#ff5353"
        case "CA": return "#ffd21e"
        default: return "#35e76f"
        }
    }

    function selectConnectionCountry(countryIndex, countryCode, countryName, cityName) {
        countryCode = countryCode || ""
        countryName = countryName || ""
        var currentCountryCode = ServersUiController.defaultServerApiCountryCode
        var requestedCityName = cityName || ""
        var requestedProtocol = root.selectedRequestProtocol()
        if (requestedCityName.length === 0 && requestedProtocol.length === 0
                && countryCode.length > 0 && countryCode === currentCountryCode) {
            return true
        }
        if (requestedCityName.length === 0 && requestedProtocol.length === 0
                && countryIndex === ApiCountryModel.currentIndex && countryCode === currentCountryCode) {
            return true
        }
        if (countryCode.length === 0) {
            PageController.showNotificationMessage(qsTr("Unable to switch to this location"))
            return false
        }
        if (ConnectionController.isConnectionInProgress) {
            PageController.showNotificationMessage(qsTr("Unable change server location while trying to make an active connection"))
            return false
        }
        if (ConnectionController.isConnected) {
            PageController.showNotificationMessage(qsTr("Unable change server location while there is an active connection"))
            return false
        }

        var serverId = ServersUiController.defaultServerId
        if (serverId.length === 0) {
            PageController.showNotificationMessage(qsTr("No VPN configuration installed"))
            return false
        }
        if (!ServersUiController.isServerFromApi(serverId)) {
            PageController.showNotificationMessage(qsTr("Current VPN configuration does not support location switching"))
            return false
        }

        ServersUiController.setProcessedServerId(serverId)

        PageController.showBusyIndicator(true)
        var result = SubscriptionUiController.updateServiceFromGateway(serverId, countryCode, countryName, false, requestedProtocol, requestedCityName)
        PageController.showBusyIndicator(false)
        return result
    }

    Component.onCompleted: {
        var serverId = ServersUiController.defaultServerId
        if (serverId.length > 0 && ServersUiController.isServerFromApi(serverId)) {
            ServersUiController.setProcessedServerId(serverId)
            SubscriptionUiController.refreshApiCountryModelFromServer(serverId)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        //StatusBar { Layout.fillWidth: true }

        // Title row
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.topMargin: 10

            Item { Layout.fillWidth: true }
            Text {
                text: "Locations"
                font { family: Theme.fontFamily; pixelSize: 20; bold: true }
                color: Theme.textPrimary
                Layout.alignment: Qt.AlignHCenter
            }
            Item { Layout.fillWidth: true }
            Text {
                text: "⌕"
                font { family: Theme.fontFamily; pixelSize: 25 }
                color: Theme.textPrimary
            }
        }

        // Search bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.topMargin: 16
            radius: 17
            color: "#0e1a2f"
            border { width: 1; color: Theme.borderColor }

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                verticalAlignment: Text.AlignVCenter
                font { family: Theme.fontFamily; pixelSize: 13 }
                color: Theme.textPrimary

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "⌕   Search for country or city"
                    font: parent.font
                    color: Theme.textSubtle
                    visible: !parent.text && !parent.activeFocus
                }
            }
        }

        // Filter tabs
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.topMargin: 20
            spacing: 10

            Repeater {
                model: root.protocolFilters

                Rectangle {
                    Layout.preferredHeight: 36
                    Layout.preferredWidth: filterLabel.implicitWidth + 32
                    radius: 18
                    color: root.activeFilter === index ? Theme.primaryGreen : Theme.cardBackground

                    Behavior on color { ColorAnimation { duration: 200 } }

                    scale: filterMouse.pressed ? 0.93 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }

                    Text {
                        id: filterLabel
                        anchors.centerIn: parent
                        text: modelData.label
                        font { family: Theme.fontFamily; pixelSize: 12; weight: Font.Medium }
                        color: root.activeFilter === index ? Theme.background : Theme.textPrimary
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    MouseArea {
                        id: filterMouse
                        anchors.fill: parent
                        onClicked: root.activateProtocolFilter(index)
                    }
                }
            }
        }

        // Server list
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.topMargin: 16
            Layout.bottomMargin: root.height - Theme.tabBarY
            spacing: 10
            clip: true

            model: ApiCountryModel
            currentIndex: ApiCountryModel.currentIndex

            delegate: Rectangle {
                id: countryDelegate
                width: ListView.view.width
                readonly property var pageRoot: root
                readonly property bool matchesCurrentFilters: root.matchesFilters(index, countryName, countryCode, cityNames)
                readonly property bool expanded: root.isCountryExpanded(countryCode, index)
                readonly property int countryModelIndex: index
                readonly property int rowHeight: 62
                readonly property int cityRowHeight: 46
                readonly property var visibleCityItems: root.cityItems(cityNames, cityRequestNames)

                function selectLocation(countryIndex, code, name, cityName, displayName) {
                    if (pageRoot.selectConnectionCountry(countryIndex, code, name, cityName)) {
                        pageRoot.serverSelected(code, displayName || name, pageRoot.selectedRequestProtocol())
                    }
                }

                height: matchesCurrentFilters ? rowHeight + (expanded ? visibleCityItems.length * cityRowHeight + 8 : 0) : 0
                radius: Theme.buttonRadius
                color: Theme.cardBackground
                visible: matchesCurrentFilters
                clip: true

                scale: delegateMouse.pressed ? 0.97 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }

                // Fade-in on creation
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }

                RowLayout {
                    id: countryRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: countryDelegate.rowHeight
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    Text {
                        text: root.flagEmoji(countryCode)
                        font.pixelSize: 27
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: countryName
                            font { family: Theme.fontFamily; pixelSize: 15; weight: Font.DemiBold }
                            color: Theme.textPrimary
                        }
                        Text {
                            text: root.locationsText(countryCode)
                            font { family: Theme.fontFamily; pixelSize: 11 }
                            color: Theme.textSecondary
                        }
                    }

                    Text {
                        text: root.pingText(countryCode)
                        font { family: Theme.fontFamily; pixelSize: 12; weight: Font.Medium }
                        color: root.pingColor(countryCode)
                    }

                    Text {
                        text: "▥"
                        font { family: Theme.fontFamily; pixelSize: 16 }
                        color: Theme.primaryGreen
                    }

                    Item {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18

                        Rectangle {
                            width: 9
                            height: 2
                            radius: 1
                            color: Theme.textSecondary
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: -3
                            rotation: countryDelegate.expanded ? -45 : 45
                        }
                        Rectangle {
                            width: 9
                            height: 2
                            radius: 1
                            color: Theme.textSecondary
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: 3
                            rotation: countryDelegate.expanded ? 45 : -45
                        }
                    }
                }

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: countryRow.bottom
                    anchors.leftMargin: 54
                    anchors.rightMargin: 14
                    visible: countryDelegate.expanded
                    spacing: 6

                    Repeater {
                        model: countryDelegate.visibleCityItems

                        Rectangle {
                            width: parent.width
                            height: countryDelegate.cityRowHeight
                            radius: 14
                            color: cityMouse.pressed ? "#17243a" : "#101d32"
                            border { width: modelData.isDefault ? 1 : 0; color: Theme.borderColor }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 8

                                Item {
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16

                                    Rectangle {
                                        visible: modelData.isDefault
                                        width: 7
                                        height: 7
                                        radius: 3.5
                                        color: Theme.primaryGreen
                                        anchors.centerIn: parent
                                    }
                                    Rectangle {
                                        visible: !modelData.isDefault
                                        width: 2
                                        height: 10
                                        radius: 1
                                        color: Theme.textSecondary
                                        anchors.left: parent.left
                                        anchors.leftMargin: 3
                                        anchors.top: parent.top
                                        anchors.topMargin: 2
                                    }
                                    Rectangle {
                                        visible: !modelData.isDefault
                                        width: 9
                                        height: 2
                                        radius: 1
                                        color: Theme.textSecondary
                                        anchors.left: parent.left
                                        anchors.leftMargin: 3
                                        anchors.top: parent.top
                                        anchors.topMargin: 10
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    font { family: Theme.fontFamily; pixelSize: 13; weight: Font.Medium }
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: cityMouse
                                anchors.fill: parent
                                onClicked: {
                                    var selectedIndex = modelData.isDefault ? countryDelegate.countryModelIndex : -1
                                    countryDelegate.selectLocation(selectedIndex, countryCode, countryName,
                                                                   modelData.requestName,
                                                                   modelData.isDefault ? countryName : modelData.name)
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    id: delegateMouse
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: countryDelegate.rowHeight
                    enabled: parent.visible
                    onClicked: {
                        if (mouse.x >= width - 44) {
                            countryDelegate.pageRoot.toggleCountryExpanded(countryCode, index)
                        } else {
                            var defaultCode = defaultCountryCode || ""
                            var selectionCode = defaultCode.length > 0 ? defaultCode : countryCode
                            countryDelegate.selectLocation(index, selectionCode, countryName, "", countryName)
                        }
                    }
                }
            }
        }
    }

    BottomTabBar { currentIndex: 1 }
}
