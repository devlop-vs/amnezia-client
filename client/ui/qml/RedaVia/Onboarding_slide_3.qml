import QtQuick

Rectangle {
    id: onboarding_slide_3

    readonly property real horizontalPadding: Math.max(24, width * 0.06)
    readonly property real topPadding: Math.max(0, height * 0.02)
    readonly property real bottomPadding: Math.max(24, height * 0.04)
    readonly property real indicatorDot: Math.max(8, Math.min(10, width * 0.02))
    readonly property real indicatorActiveWidth: indicatorDot * 3
    readonly property int titleSize: Math.round(Math.max(26, Math.min(32, width * 0.076)))
    readonly property int bodySize: Math.round(Math.max(14, Math.min(16, width * 0.038)))
    readonly property int buttonTextSize: Math.round(Math.max(15, Math.min(17, width * 0.041)))
    readonly property int linkTextSize: Math.round(Math.max(12, Math.min(14, width * 0.033)))
    readonly property real imageAreaHeight: Math.max(200, height * 0.34)
    readonly property real maxImageHeight: imageAreaHeight * 0.9
    readonly property real buttonSpacing: Math.max(12, height * 0.015)

    signal signUpClicked()
    signal signInClicked()

    implicitWidth: 393
    implicitHeight: 796

    clip: true
    color: "#071224"
    radius: Math.min(28, width * 0.07)

    Item {
        anchors.fill: parent
        anchors.leftMargin: onboarding_slide_3.horizontalPadding
        anchors.rightMargin: onboarding_slide_3.horizontalPadding
        anchors.topMargin: onboarding_slide_3.topPadding
        anchors.bottomMargin: onboarding_slide_3.bottomPadding

        Column {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                bottom: actionColumn.top
                bottomMargin: Math.max(16, parent.height * 0.03)
            }
            spacing: Math.max(12, parent.height * 0.018)

            Item {
                width: parent.width
                height: onboarding_slide_3.imageAreaHeight

                Image {
                    id: global_Illustration_Area
                    anchors.centerIn: parent
                    width: Math.min(parent.width, sourceSize.width)
                    height: Math.min(onboarding_slide_3.maxImageHeight, sourceSize.height)
                    fillMode: Image.PreserveAspectFit
                    source: "qrc:/ui/qml/RedaVia/assets/global_Illustration_Area.png"
                }
            }

            Item {
                width: parent.width
                height: indicatorRow.height

                Row {
                    id: indicatorRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: onboarding_slide_3.indicatorDot

                    Rectangle {
                        width: onboarding_slide_3.indicatorDot
                        height: onboarding_slide_3.indicatorDot
                        radius: height / 2
                        color: "#293a55"
                    }

                    Rectangle {
                        width: onboarding_slide_3.indicatorDot
                        height: onboarding_slide_3.indicatorDot
                        radius: height / 2
                        color: "#293a55"
                    }

                    Rectangle {
                        width: onboarding_slide_3.indicatorActiveWidth
                        height: onboarding_slide_3.indicatorDot
                        radius: height / 2
                        color: "#35e76f"
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Math.max(14, parent.height * 0.018)

                Text {
                    width: parent.width
                    color: "#ffffff"
                    font.family: "Inter"
                    font.pixelSize: onboarding_slide_3.titleSize
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: "Trustworthy Protection"
                }

                Text {
                    width: parent.width
                    color: "#94a3b8"
                    font.family: "Inter"
                    font.pixelSize: onboarding_slide_3.bodySize
                    font.weight: Font.Normal
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    lineHeight: Math.max(22, onboarding_slide_3.bodySize * 1.55)
                    lineHeightMode: Text.FixedHeight
                    text: "RedaVPN provides trustworthy security protection for ordinary users, technology enthusiasts, and industry experts. Join a global community that puts digital freedom and security first."
                }
            }
        }

        Column {
            id: actionColumn
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            spacing: onboarding_slide_3.buttonSpacing

            Rectangle {
                width: parent.width
                height: Math.max(56, parent.height * 0.075)
                color: "#35e76f"
                radius: Math.min(18, height * 0.32)

                Text {
                    anchors.centerIn: parent
                    color: "#071224"
                    font.family: "Inter"
                    font.pixelSize: onboarding_slide_3.buttonTextSize
                    font.weight: Font.Bold
                    text: "Sign Up"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: onboarding_slide_3.signUpClicked()
                }
            }

            Rectangle {
                width: parent.width
                height: Math.max(56, parent.height * 0.075)
                color: "#071224"
                border.color: "#35e76f"
                border.width: 1
                radius: Math.min(18, height * 0.32)

                Text {
                    anchors.centerIn: parent
                    color: "#35e76f"
                    font.family: "Inter"
                    font.pixelSize: onboarding_slide_3.buttonTextSize
                    font.weight: Font.Bold
                    text: "Sign In"
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: onboarding_slide_3.signInClicked()
                }
            }

            Text {
                width: parent.width
                color: "#94a3b8"
                font.family: "Inter"
                font.pixelSize: onboarding_slide_3.linkTextSize
                font.weight: Font.DemiBold
                font.underline: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: "Subscription and Privacy Information"
            }
        }
    }
}