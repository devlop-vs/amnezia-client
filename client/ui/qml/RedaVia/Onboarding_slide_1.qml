import QtQuick

Rectangle {
    id: onboarding_slide_1

    readonly property real horizontalPadding: Math.max(24, width * 0.06)
    readonly property real topPadding: Math.max(0, height * 0.02)
    readonly property real bottomPadding: Math.max(24, height * 0.04)
    readonly property real indicatorDot: Math.max(8, Math.min(10, width * 0.02))
    readonly property real indicatorActiveWidth: indicatorDot * 3
    readonly property int titleSize: Math.round(Math.max(26, Math.min(32, width * 0.076)))
    readonly property int accentSize: Math.round(Math.max(15, Math.min(18, width * 0.041)))
    readonly property int bodySize: Math.round(Math.max(14, Math.min(16, width * 0.038)))
    readonly property int buttonTextSize: Math.round(Math.max(15, Math.min(17, width * 0.041)))
    readonly property real imageAreaHeight: Math.max(220, height * 0.42)
    readonly property real maxImageHeight: imageAreaHeight * 0.9

    signal nextClicked()

    implicitWidth: 393
    implicitHeight: 796

    clip: true
    color: "#071224"
    radius: Math.min(28, width * 0.07)

    Item {
        anchors.fill: parent
        anchors.leftMargin: onboarding_slide_1.horizontalPadding
        anchors.rightMargin: onboarding_slide_1.horizontalPadding
        anchors.topMargin: onboarding_slide_1.topPadding
        anchors.bottomMargin: onboarding_slide_1.bottomPadding

        Column {
            anchors.fill: parent
            spacing: Math.max(12, parent.height * 0.02)

            Item {
                width: parent.width
                height: onboarding_slide_1.imageAreaHeight

                Image {
                    id: shield_Illustration_Area
                    anchors.centerIn: parent
                    width: Math.min(parent.width, sourceSize.width)
                    height: Math.min(onboarding_slide_1.maxImageHeight, sourceSize.height)
                    fillMode: Image.PreserveAspectFit
                    source: "qrc:/ui/qml/RedaVia/assets/shield_Illustration_Area.png"
                }
            }

            Item {
                width: parent.width
                height: indicatorRow.height

                Row {
                    id: indicatorRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: onboarding_slide_1.indicatorDot

                    Rectangle {
                        width: onboarding_slide_1.indicatorActiveWidth
                        height: onboarding_slide_1.indicatorDot
                        radius: height / 2
                        color: "#35e76f"
                    }

                    Rectangle {
                        width: onboarding_slide_1.indicatorDot
                        height: onboarding_slide_1.indicatorDot
                        radius: height / 2
                        color: "#293a55"
                    }

                    Rectangle {
                        width: onboarding_slide_1.indicatorDot
                        height: onboarding_slide_1.indicatorDot
                        radius: height / 2
                        color: "#293a55"
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Math.max(12, parent.height * 0.015)

                Text {
                    width: parent.width
                    color: "#ffffff"
                    font.family: "Inter"
                    font.pixelSize: onboarding_slide_1.titleSize
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: "What is VPN?"
                }

                Text {
                    width: parent.width
                    color: "#35e76f"
                    font.family: "Inter"
                    font.pixelSize: onboarding_slide_1.accentSize
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: "Browse more securely with one click!"
                }

                Text {
                    width: parent.width
                    color: "#94a3b8"
                    font.family: "Inter"
                    font.pixelSize: onboarding_slide_1.bodySize
                    font.weight: Font.Normal
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    lineHeight: Math.max(22, onboarding_slide_1.bodySize * 1.5)
                    lineHeightMode: Text.FixedHeight
                    text: "A VPN improves your online privacy, keeping your online activities safe from prying eyes and making it safer to use public Wi-Fi."
                }
            }

            Item {
                width: parent.width
                height: 1
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.max(56, parent.height * 0.075)
            color: "#35e76f"
            radius: Math.min(18, height * 0.32)

            Text {
                anchors.centerIn: parent
                color: "#071224"
                font.family: "Inter"
                font.pixelSize: onboarding_slide_1.buttonTextSize
                font.weight: Font.Bold
                text: "Next"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: onboarding_slide_1.nextClicked()
            }
        }
    }
}