import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects

Rectangle {
    id: root
    width: Theme.screenWidth
    height: Theme.screenHeight
    radius: Theme.screenRadius
    color: Theme.background
    clip: true

    signal disconnectPressed()

    property string countryCode: "GB"
    property string countryName: qsTr("United Kingdom")
    property string protocolName: "wireguard"

    function flagEmoji(countryCode) {
        var code = countryCode.toUpperCase()
        if (code.length !== 2) {
            return "🌐"
        }

        return String.fromCodePoint(0x1F1E6 + code.charCodeAt(0) - 65,
                                    0x1F1E6 + code.charCodeAt(1) - 65)
    }

    function protocolDisplayName(protocol) {
        switch (protocol.toLowerCase()) {
        case "wireguard": return "WireGuard"
        case "awg": return "AmneziaWG"
        case "openvpn": return "OpenVPN"
        case "vless": return "VLESS"
        default: return protocol
        }
    }

    function protocolShortName(protocol) {
        switch (protocol.toLowerCase()) {
        case "wireguard": return "WG"
        case "awg": return "AWG"
        case "openvpn": return "OVPN"
        case "vless": return "VLESS"
        default: return protocol.toUpperCase()
        }
    }

    function scrollToNetworkStats() {
        flickable.contentY = Math.max(0, Math.min(networkStats.y,
                                                   flickable.contentHeight - flickable.height))
    }

    Flickable {
        id: flickable
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.DragOverBounds

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: content
            width: flickable.width
            spacing: 0

        //StatusBar { Layout.fillWidth: true }

        TopBar {
            Layout.topMargin: 10
        }

        // Country flag + name
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 20
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 20
                color: Theme.accentBlueDark
                Text {
                    anchors.centerIn: parent
                    text: root.flagEmoji(root.countryCode)
                    font.pixelSize: 27
                }
            }

            Text {
                text: root.countryName.length > 0 ? root.countryName : qsTr("Selected location")
                font { family: Theme.fontFamily; pixelSize: 17; weight: Font.DemiBold }
                color: Theme.textPrimary
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 8
            text: ConnectionController.connectionDurationText
            font { family: Theme.fontFamily; pixelSize: 48; bold: true }
            color: Theme.textPrimary
            horizontalAlignment: Text.AlignHCenter

            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutQuad } }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 4
            text: ServersUiController.serverHostName(ConnectionController.connectionServerId)
            font { family: Theme.fontFamily; pixelSize: 14 }
            color: Theme.textSecondary
            horizontalAlignment: Text.AlignHCenter
        }

        // Power button
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 224
            Layout.topMargin: 8

            PowerButton {
                anchors.horizontalCenter: parent.horizontalCenter
                size: 164
                connected: true
                onClicked: root.disconnectPressed()
            }
        }

        // Connected status card
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 58
            Layout.leftMargin: 28
            Layout.rightMargin: 28
            radius: 20
            color: Theme.cardBackground

            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutQuad } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20

                Row {
                    spacing: 8
                    Rectangle {
                        width: 10; height: 10; radius: 5
                        color: Theme.primaryGreen
                        anchors.verticalCenter: parent.verticalCenter

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: 1000; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
                        }
                    }
                    Text {
                        text: qsTr("Connected")
                        font { family: Theme.fontFamily; pixelSize: 15; weight: Font.DemiBold }
                        color: Theme.primaryGreen
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: root.protocolDisplayName(root.protocolName)
                    font { family: Theme.fontFamily; pixelSize: 14 }
                    color: Theme.textMuted
                }
            }
        }

        SpeedStats {
            Layout.topMargin: 16
            downloadSpeed: ConnectionController.downloadSpeedText
            uploadSpeed: ConnectionController.uploadSpeedText
        }

        // Stats cards
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 28
            Layout.rightMargin: 28
            Layout.topMargin: 20
            spacing: 14

            Repeater {
                model: [
                    { key: "ping", label: qsTr("Ping") },
                    { key: "protocol", label: qsTr("Protocol") },
                    { key: "duration", label: qsTr("Duration") }
                ]

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 82
                    radius: Theme.buttonRadius
                    color: Theme.cardBackground

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.topMargin: 21
                        spacing: 15

                        Text {
                            text: modelData.label
                            font { family: Theme.fontFamily; pixelSize: 12 }
                            color: Theme.textMuted
                        }
                        Text {
                            text: modelData.key === "duration"
                                  ? ConnectionController.connectionDurationText
                                  : (modelData.key === "protocol" ? root.protocolShortName(root.protocolName) : "16 ms")
                            font { family: Theme.fontFamily; pixelSize: 18; bold: true }
                            color: Theme.primaryGreen
                        }
                    }
                }
            }
        }

        Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 12
            Layout.bottomMargin: 8
            implicitWidth: 48
            implicitHeight: 48
            background: Item { }
            contentItem: Image {
                source: "qrc:/ui/qml/RedaVia/assets/doublearrows.svg"
                fillMode: Image.PreserveAspectFit
                sourceSize.width: 32
                sourceSize.height: 32
            }
            onClicked: root.scrollToNetworkStats()
        }

        // Planet earth
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 335
            Layout.leftMargin: 5

            Image {
                id: earthImage
                anchors.fill: parent
                source: "qrc:/ui/qml/RedaVia/assets/earth-background.png"
                fillMode: Image.PreserveAspectCrop
                visible: false
                smooth: true
            }

            Rectangle {
                id: earthMask
                anchors.fill: parent
                visible: false
            }

            OpacityMask {
                anchors.fill: earthImage
                source: earthImage
                maskSource: earthMask
            }
        }

            HomeNetworkStats {
                id: networkStats
            }
        }
    }

    // Bottom navigation is provided by PageStartRedaVia's TabBar.
}
