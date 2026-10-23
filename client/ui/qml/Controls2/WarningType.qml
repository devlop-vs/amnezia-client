import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import Style 1.0

import "TextTypes"

Rectangle {
    id: root

    property string fontFamily: "PT Root UI VF"
    property string textColor: AmneziaStyle.color.paleGray
    property string backGroundColor: AmneziaStyle.color.onyxBlack
    property string imageColor: AmneziaStyle.color.paleGray
    property string borderColor: AmneziaStyle.color.transparent
    property int borderWidth: 0
    property int cardRadius: 8
    property string textString
    property int textFormat: Text.PlainText

    property string iconPath
    property real iconWidth: 16
    property real iconHeight: 16

    color: backGroundColor
    border.color: root.borderColor
    border.width: root.borderWidth
    radius: root.cardRadius
    implicitHeight: content.implicitHeight + content.anchors.topMargin + content.anchors.bottomMargin

    RowLayout {
        id: content
        width: parent.width
        anchors.fill: parent

        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 8
        anchors.bottomMargin: 8

        spacing: 0

        Image {
            Layout.alignment: Qt.AlignTop

            width: iconWidth
            height: iconHeight

            source: iconPath

            layer {
                enabled: true
                effect: ColorOverlay {
                    color: imageColor
                }
            }
        }

        CaptionTextType {
            id: supportingText

            Layout.fillWidth: true
            Layout.leftMargin: 8

            text: textString
            font.family: root.fontFamily
            textFormat: root.textFormat
            color: textColor
        }
    }
}
