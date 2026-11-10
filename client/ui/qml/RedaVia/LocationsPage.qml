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

    property int activeFilter: 0
    property var expandedCountries: ({})
    readonly property var protocolFilters: [
        { label: qsTr("Country/Region"), protocol: "" },
        { label: qsTr("Quick"), protocol: "wireguard" },
        { label: qsTr("General"), protocol: "openvpn" },
        { label: qsTr("Obfuscated VPN"), protocol: "vless" }
    ]
    signal serverSelected(string countryCode, string countryName, string protocolName)
    signal subscriptionRequested()

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

    function cityItems(cityNames, cityRequestNames, cityFallbackNames, cityQualities) {
        cityNames = cityNames || []
        cityRequestNames = cityRequestNames || []
        cityFallbackNames = cityFallbackNames || []
        cityQualities = cityQualities || []
        var items = []
        var count = Math.min(cityNames.length, cityRequestNames.length)
        for (var i = 0; i < count; ++i) {
            var cityName = cityNames[i] || ""
            var cityRequestName = cityRequestNames[i] || ""
            var cityFallbackName = i < cityFallbackNames.length ? cityFallbackNames[i] : ""
            var quality = i < cityQualities.length ? cityQualities[i] : {}
            items.push({
                name: cityName,
                requestName: cityRequestName,
                serverName: cityFallbackName,
                isDefault: cityName === "Default",
                latencyText: quality.latencyText || "-- ms",
                signalBars: quality.signalBars || 0,
                qualityStatus: quality.status || "unknown",
                qualityLabel: quality.label || "Unknown"
            })
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

    function selectConnectionCountry(countryIndex, countryCode, countryName, cityCode, cityName) {
        countryCode = countryCode || ""
        countryName = countryName || ""
        var currentCountryCode = ServersUiController.defaultServerApiCountryCode
        var requestedCityCode = cityCode || ""
        var requestedCityName = cityName || ""
        var requestedProtocol = root.selectedRequestProtocol()
        if (requestedCityCode.length === 0 && requestedProtocol.length === 0
                && countryCode.length > 0 && countryCode === currentCountryCode) {
            return true
        }
        if (requestedCityCode.length === 0 && requestedProtocol.length === 0
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
        if (serverId.length === 0
                || (ServersUiController.isServerFromApi(serverId)
                    && ServersUiController.isServerSubscriptionExpired(serverId))) {
            root.subscriptionRequested()
            return false
        }
        if (!ServersUiController.isServerFromApi(serverId)) {
            PageController.showNotificationMessage(qsTr("Current VPN configuration does not support location switching"))
            return false
        }

        ServersUiController.setProcessedServerId(serverId)

        PageController.showBusyIndicator(true)
        var result = SubscriptionUiController.updateServiceFromGateway(serverId, countryCode, countryName, false,
                                                                       requestedProtocol, requestedCityCode, requestedCityName)
        PageController.showBusyIndicator(false)
        return result
    }

    Component.onCompleted: {
        var serverId = ServersUiController.defaultServerId
        if (serverId.length > 0 && ServersUiController.isServerFromApi(serverId)) {
            ServersUiController.setProcessedServerId(serverId)
            SubscriptionUiController.refreshApiCountryModelFromServer(serverId)
            SubscriptionUiController.refreshNodeQuality()
        }
    }
    Component.onDestruction: SubscriptionUiController.stopNodeQualityMonitoring()

    Timer {
        interval: 45000
        repeat: true
        running: root.visible && Qt.application.state === Qt.ApplicationActive
        onTriggered: SubscriptionUiController.refreshNodeQuality()
    }

    Connections {
        target: NetworkReachabilityController
        function onHasInternetAccessChanged() {
            if (NetworkReachabilityController.hasInternetAccess
                    && root.visible && Qt.application.state === Qt.ApplicationActive) {
                SubscriptionUiController.refreshNodeQuality()
            }
        }
    }

    Connections {
        target: Qt.application
        function onStateChanged() {
            if (Qt.application.state === Qt.ApplicationActive && root.visible) {
                SubscriptionUiController.refreshNodeQuality()
            } else {
                SubscriptionUiController.stopNodeQualityMonitoring()
            }
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
            Button {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                background: Item { }
                contentItem: Image {
                    source: "qrc:/images/controls/search.svg"
                    sourceSize.width: 25
                    sourceSize.height: 25
                    fillMode: Image.PreserveAspectFit
                }
                onClicked: {
                    searchInput.forceActiveFocus()
                    Qt.inputMethod.show()
                }
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

            Image {
                id: searchIcon
                width: 20
                height: 20
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                source: "qrc:/images/controls/search.svg"
                sourceSize.width: width
                sourceSize.height: height
                fillMode: Image.PreserveAspectFit
            }

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.leftMargin: 52
                anchors.rightMargin: 20
                verticalAlignment: Text.AlignVCenter
                font { family: Theme.fontFamily; pixelSize: 13 }
                color: Theme.textPrimary

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: qsTr("Search for country or city")
                    font: parent.font
                    color: Theme.textSubtle
                    visible: !parent.text && !parent.activeFocus
                }
            }
        }

        // Filter tabs
        Item {
            Layout.fillWidth: true
            Layout.maximumWidth: root.width
            Layout.preferredHeight: 36
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.topMargin: 20
            clip: true

            Flickable {
                id: filterFlickable
                anchors.fill: parent
                contentWidth: filterRow.implicitWidth
                contentHeight: height
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Row {
                    id: filterRow
                    height: parent.height
                    spacing: 10

                    Repeater {
                        model: root.protocolFilters

                        Rectangle {
                            width: filterLabel.implicitWidth + 32
                            height: filterRow.height
                            radius: height / 2
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
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.maximumWidth: root.width - 40
            Layout.preferredHeight: visible ? obfuscatedDescription.implicitHeight + 28 : 0
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.topMargin: visible ? 14 : 0
            radius: 14
            color: Theme.cardBackground
            border {
                width: 1
                color: Theme.borderColor
            }
            visible: root.selectedProtocol() === "vless"

            Text {
                id: obfuscatedDescription
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                text: qsTr("Obfuscated servers hide common signs of VPN usage, allowing you to connect to a VPN on restricted networks of some countries or regions.")
                font {
                    family: Theme.fontFamily
                    pixelSize: 12
                }
                color: Theme.textSecondary
                wrapMode: Text.WordWrap
            }
        }

        // Server list
        ListView {
            Layout.fillWidth: true
            Layout.maximumWidth: root.width
            Layout.fillHeight: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.topMargin: 16
            spacing: 10
            clip: true

            model: ApiCountryModel
            currentIndex: ApiCountryModel.currentIndex

            delegate: Rectangle {
                id: countryDelegate
                width: Math.max(0, Math.min(ListView.view.width, root.width - 40))
                readonly property var pageRoot: root
                readonly property bool matchesCurrentFilters: root.matchesFilters(index, countryName, countryCode, cityNames)
                readonly property bool expanded: root.isCountryExpanded(countryCode, index)
                readonly property int countryModelIndex: index
                readonly property int rowHeight: 62
                readonly property int cityRowHeight: 46
                readonly property var visibleCityItems: root.cityItems(cityNames, cityRequestNames, cityFallbackNames, cityQualities)

                function selectLocation(countryIndex, code, name, cityCode, cityName, displayName) {
                    if (pageRoot.selectConnectionCountry(countryIndex, code, name, cityCode, cityName)) {
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
                            Layout.fillWidth: true
                            text: countryName
                            font { family: Theme.fontFamily; pixelSize: 15; weight: Font.DemiBold }
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: qsTr("%n Location(s)", "", cityCount)
                            font { family: Theme.fontFamily; pixelSize: 11 }
                            color: Theme.textSecondary
                            elide: Text.ElideRight
                        }
                    }

                    Text {
                        text: countryQualityStatus === "offline" ? qsTr("Offline") : countryLatencyText
                        font { family: Theme.fontFamily; pixelSize: 12; weight: Font.Medium }
                        color: countryQualityStatus === "online" || countryQualityStatus === "degraded"
                               ? Theme.primaryGreen : Theme.textSecondary
                        horizontalAlignment: Text.AlignRight
                    }

                    NodeSignalBars {
                        bars: countrySignalBars
                        status: countryQualityStatus
                        Accessible.name: countryQualityLabel
                    }

                    Rectangle {
                        id: expandButton
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: 18
                        color: expandMouse.pressed ? "#17243a" : "#101d32"
                        border { width: 1; color: Theme.borderColor }

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

                        MouseArea {
                            id: expandMouse
                            anchors.fill: parent
                            onClicked: countryDelegate.pageRoot.toggleCountryExpanded(countryCode, index)
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
                            width: Math.max(0, Math.min(parent.width, root.width - 88))
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
                                    text: modelData.isDefault ? qsTr("Default") : modelData.name
                                    font { family: Theme.fontFamily; pixelSize: 13; weight: Font.Medium }
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: modelData.qualityStatus === "offline" ? qsTr("Offline") : modelData.latencyText
                                    font { family: Theme.fontFamily; pixelSize: 12; weight: Font.Medium }
                                    color: modelData.qualityStatus === "online" || modelData.qualityStatus === "degraded"
                                           ? Theme.primaryGreen : Theme.textSecondary
                                    horizontalAlignment: Text.AlignRight
                                }

                                NodeSignalBars {
                                    bars: modelData.signalBars
                                    status: modelData.qualityStatus
                                    Accessible.name: modelData.qualityLabel
                                }
                            }

                            MouseArea {
                                id: cityMouse
                                anchors.fill: parent
                                onClicked: {
                                    var selectedIndex = modelData.isDefault ? countryDelegate.countryModelIndex : -1
                                    countryDelegate.selectLocation(selectedIndex, countryCode, countryName,
                                                                   modelData.requestName, modelData.serverName,
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
                    anchors.rightMargin: 50
                    anchors.top: parent.top
                    height: countryDelegate.rowHeight
                    enabled: parent.visible
                    onClicked: {
                        if (countryDelegate.visibleCityItems.length > 0) {
                            var firstCity = countryDelegate.visibleCityItems[0]
                            var selectedIndex = firstCity.isDefault
                                    ? countryDelegate.countryModelIndex : -1
                            countryDelegate.selectLocation(selectedIndex, countryCode, countryName,
                                                           firstCity.requestName, firstCity.serverName,
                                                           firstCity.isDefault ? countryName : firstCity.name)
                            return
                        }

                        var defaultCode = defaultCountryCode || ""
                        var selectionCode = defaultCode.length > 0 ? defaultCode : countryCode
                        countryDelegate.selectLocation(index, selectionCode, countryName, "", "", countryName)
                    }
                }
            }
        }
    }

    // Bottom navigation is provided by PageStartRedaVia's TabBar.
}
