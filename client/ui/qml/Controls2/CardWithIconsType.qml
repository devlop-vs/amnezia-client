import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Style 1.0

import "TextTypes"

Button {
    id: root

    property string headerText
    property string bodyText
    property string footerText
    property string fontFamily: "PT Root UI VF"

    property color headerTextColor: AmneziaStyle.color.paleGray
    property color bodyTextColor: AmneziaStyle.color.mutedGray
    property color footerTextColor: AmneziaStyle.color.mutedGray
    property color recommendedTextColor: AmneziaStyle.color.midnightBlack
    property color recommendedBackgroundColor: AmneziaStyle.color.softViolet
    property color cardBorderColor: AmneziaStyle.color.transparent
    property int cardBorderWidth: 0
    property int cardRadius: 16
    property bool showRecommendedBadge: false
    property string recommendedText: ""

    property string hoveredColor: AmneziaStyle.color.slateGray
    property string defaultColor: AmneziaStyle.color.onyxBlack

    property string textColor: AmneziaStyle.color.midnightBlack

    property string rightImageSource
    property string rightImageColor: AmneziaStyle.color.paleGray

    property string leftImageSource

    property alias focusItem: rightImage

    hoverEnabled: true
    clip: false

    readonly property real cardTextOpacity: !enabled ? 1.0 : pressed ? 0.7 : hovered ? 0.8 : 1.0

    background: Rectangle {
        id: backgroundRect

        anchors.fill: parent
        radius: root.cardRadius

        color: root.hovered && root.enabled ? root.hoveredColor : root.defaultColor
        border.color: root.cardBorderColor
        border.width: root.cardBorderWidth

        Behavior on color {
            PropertyAnimation { duration: 200 }
        }
    }

    contentItem: Item {
        id: contentRoot

        z: 1
        anchors.left: parent.left
        anchors.right: parent.right

        readonly property bool badgeVisible: root.showRecommendedBadge && root.recommendedText !== ""

        implicitHeight: layoutCol.implicitHeight

        ColumnLayout {
            id: layoutCol

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0

            Item {
                id: badgeTopSpacer

                Layout.fillWidth: true
                Layout.preferredHeight: contentRoot.badgeVisible ? (recBadge.height / 2 + 8) : 0

                Rectangle {
                    id: recBadge

                    visible: contentRoot.badgeVisible
                    z: 2

                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.top

                    radius: 10
                    color: root.recommendedBackgroundColor
                    implicitHeight: recLabel.implicitHeight + 8
                    implicitWidth: recLabel.implicitWidth + 16

                    width: implicitWidth
                    height: implicitHeight

                    BadgeTextType {
                        id: recLabel

                        anchors.centerIn: parent
                        text: root.recommendedText
                        color: root.recommendedTextColor
                        font.family: root.fontFamily
                    }
                }
            }

            RowLayout {
                id: content

                Layout.fillWidth: true

                Image {
                    id: leftImage
                    source: leftImageSource

                    visible: leftImageSource !== ""

                    Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                    Layout.topMargin: 24
                    Layout.bottomMargin: 24
                    Layout.leftMargin: 24
                }

                ColumnLayout {

                    ListItemTitleType {
                        text: root.headerText
                        visible: text !== ""

                        color: root.headerTextColor
                        font.family: root.fontFamily

                        Layout.fillWidth: true
                        Layout.rightMargin: 16
                        Layout.leftMargin: 16
                        Layout.topMargin: contentRoot.badgeVisible ? 0 : 16
                        Layout.bottomMargin: root.bodyText !== "" ? 0 : 16

                        opacity: root.cardTextOpacity
                    }

                    CaptionTextType {
                        text: root.bodyText
                        visible: text !== ""

                        color: root.bodyTextColor
                        font.family: root.fontFamily
                        textFormat: Text.RichText
                        onLinkActivated: function(link) {
                            Qt.openUrlExternally(link)
                        }

                        Layout.fillWidth: true
                        Layout.rightMargin: 16
                        Layout.leftMargin: 16
                        Layout.bottomMargin: root.footerText !== "" ? 0 : 8

                        opacity: root.cardTextOpacity
                    }

                    ButtonTextType {
                        text: root.footerText
                        visible: text !== ""

                        color: root.footerTextColor
                        font.family: root.fontFamily

                        Layout.fillWidth: true
                        Layout.rightMargin: 16
                        Layout.leftMargin: 16
                        Layout.topMargin: 16
                        Layout.bottomMargin: 16

                        opacity: root.cardTextOpacity
                    }
                }

                ImageButtonType {
                    id: rightImage

                    implicitWidth: 40
                    implicitHeight: 40

                    hoverEnabled: false
                    image: rightImageSource
                    imageColor: rightImageColor
                    visible: rightImageSource ? true : false

                    Layout.alignment: Qt.AlignRight | Qt.AlignTop
                    Layout.topMargin: 16
                    Layout.bottomMargin: 16
                    Layout.rightMargin: 16

                    Rectangle {
                        id: rightImageBackground

                        anchors.fill: parent
                        radius: 12
                        color: root.pressed ? rightImage.pressedColor : root.hovered && root.enabled ? rightImage.hoveredColor : rightImage.defaultColor

                        Behavior on color {
                            PropertyAnimation { duration: 200 }
                        }
                    }

                    onClicked: {
                        root.clicked()
                    }
                }
            }
        }
    }
}
