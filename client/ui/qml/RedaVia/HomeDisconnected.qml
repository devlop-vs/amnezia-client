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

    signal connectPressed()
    signal serverChangeRequested()
    signal subscriptionRequested()

    property string countryCode: "GB"
    property string countryName: "United Kingdom"
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

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        //StatusBar { Layout.fillWidth: true }

        TopBar {
            Layout.topMargin: 10
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 20
            text: "Connecting Time"
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
                onClicked: root.connectPressed()
            }
        }

        // PageRedaVia owns and refreshes the current subscription state.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 58
            Layout.leftMargin: 28
            Layout.rightMargin: 28
            radius: 20
            color: Theme.cardBackground
            visible: root.showSubscriptionStatusBar

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
                        color: Theme.dangerRed
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "Subscribe to RedaVPN"
                        font { family: Theme.fontFamily; pixelSize: 15; weight: Font.DemiBold }
                        color: Theme.dangerRed
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "Choose Plan"
                    font { family: Theme.fontFamily; pixelSize: 14 }
                    color: Theme.textMuted
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.subscriptionRequested()
            }
        }

        ServerCard {
            Layout.topMargin: 16
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

        Item { Layout.fillHeight: true }

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
    }

    BottomTabBar { currentIndex: 0 }
}
