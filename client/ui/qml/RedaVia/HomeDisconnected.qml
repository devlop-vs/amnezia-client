import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects

import "../Controls2"

Rectangle {
    id: root
    width: Theme.screenWidth
    height: Theme.screenHeight
    radius: Theme.screenRadius
    color: Theme.background
    clip: true

    signal connectPressed()
    signal serverChangeRequested()
    signal subscriptionRequested()

    property string countryCode: "GB"
    property string countryName: qsTr("United Kingdom")
    property string protocolName: ""
    property bool showSubscriptionStatusBar: false

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

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 20
            text: qsTr("Connecting Time")
            font { family: Theme.fontFamily; pixelSize: 14 }
            color: Theme.textBody
            horizontalAlignment: Text.AlignHCenter
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

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 224
            Layout.topMargin: 20

            PowerButton {
                anchors.horizontalCenter: parent.horizontalCenter
                connected: false
                onClicked: {
                    if (root.showSubscriptionStatusBar) {
                        subscriptionStatusButton.forceActiveFocus()
                        return
                    }

                    root.connectPressed()
                }
            }
        }

        BasicButtonType {
            id: subscriptionStatusButton
            visible: root.showSubscriptionStatusBar

            Layout.fillWidth: true
            Layout.leftMargin: 28
            Layout.rightMargin: 28
            Layout.topMargin: 16
            Layout.bottomMargin: 8

            text: qsTr("Subscribe to RedaVPN — Choose Plan")
            defaultColor: "#F5E6C8"
            hoveredColor: "#EBD7AF"
            pressedColor: "#DEC18A"
            textColor: Theme.dangerRed
            borderColor: Theme.borderColor
            borderWidth: 1
            borderFocusedWidth: 0
            buttonRadius: 20
            fontFamily: Theme.fontFamily
            clickedFunc: function() {
                root.subscriptionRequested()
            }

            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutQuad } }
        }

        ServerCard {
            Layout.topMargin: 8
            flag: root.flagEmoji(root.countryCode)
            country: root.countryName.length > 0 ? root.countryName : qsTr("Select location")
            ipAddress: root.protocolDisplayName(root.protocolName)
            onClicked: root.serverChangeRequested()
        }

        SpeedStats {
            Layout.topMargin: 20
            downloadSpeed: "0 Mbps"
            uploadSpeed: "0 Mbps"
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
