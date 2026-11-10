import QtQuick
import QtQuick.Layouts

import Style 1.0

import "TextTypes"

Item {
    id: root

    property string actionButtonImage
    property var actionButtonFunction

    property alias actionButton: headerActionButton

    property string headerText
    property string descriptionText
    property string fontFamily: "PT Root UI VF"
    property color headerTextColor: AmneziaStyle.color.paleGray
    property color descriptionTextColor: AmneziaStyle.color.mutedGray
    property color actionButtonImageColor: AmneziaStyle.color.paleGray

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    ColumnLayout {
        id: content
        anchors.fill: parent

        RowLayout {
            Header2TextType {
                id: header

                Layout.fillWidth: true

                text: root.headerText
                color: root.headerTextColor
                font.family: root.fontFamily
            }

            ImageButtonType {
                id: headerActionButton

                implicitWidth: 40
                implicitHeight: 40

                image: root.actionButtonImage
                imageColor: root.actionButtonImageColor

                visible: image ? true : false

                onClicked: {
                    if (actionButtonFunction && typeof actionButtonFunction === "function") {
                        actionButtonFunction()
                    }
                }
            }
        }

        ParagraphTextType {
            id: description

            Layout.topMargin: 16
            Layout.fillWidth: true

            text: root.descriptionText

            color: root.descriptionTextColor
            font.family: root.fontFamily

            visible: root.descriptionText !== ""
        }
    }

    Keys.onEnterPressed: {
        if (actionButtonFunction && typeof actionButtonFunction === "function") {
            actionButtonFunction()
        }
    }

    Keys.onReturnPressed: {
        if (actionButtonFunction && typeof actionButtonFunction === "function") {
            actionButtonFunction()
        }
    }
}
