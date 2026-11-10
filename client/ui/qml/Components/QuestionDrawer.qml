pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Style 1.0

import "../Controls2"
import "../Controls2/TextTypes"

import "../Config"
import "../RedaVia" as RedaVia

DrawerType2 {
    id: root

    defaultColor: RedaVia.Theme.background
    borderColor: RedaVia.Theme.borderColor

    property string headerText
    property string descriptionText
    property string yesButtonText
    property string noButtonText

    property var yesButtonFunction
    property var noButtonFunction

    expandedStateContent: ColumnLayout {
        id: content

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        spacing: 8

        onImplicitHeightChanged: {
            root.expandedHeight = content.implicitHeight + 32 + PageController.safeAreaBottomMargin
        }

        Header2TextType {
            Layout.fillWidth: true
            Layout.topMargin: 16
            Layout.rightMargin: 16
            Layout.leftMargin: 16

            text: root.headerText
            color: RedaVia.Theme.textPrimary
            font.family: RedaVia.Theme.fontFamily
        }

        ParagraphTextType {
            Layout.fillWidth: true
            Layout.topMargin: 8
            Layout.rightMargin: 16
            Layout.leftMargin: 16

            text: root.descriptionText
            color: RedaVia.Theme.textSecondary
            font.family: RedaVia.Theme.fontFamily
        }

        BasicButtonType {
            id: yesButton
            Layout.fillWidth: true
            Layout.topMargin: 16
            Layout.rightMargin: 16
            Layout.leftMargin: 16

            fontFamily: RedaVia.Theme.fontFamily
            defaultColor: RedaVia.Theme.primaryGreen
            hoveredColor: Qt.lighter(RedaVia.Theme.primaryGreen, 1.08)
            pressedColor: Qt.darker(RedaVia.Theme.primaryGreen, 1.08)
            disabledColor: RedaVia.Theme.borderColor
            textColor: RedaVia.Theme.background
            borderColor: RedaVia.Theme.primaryGreen
            borderFocusedColor: RedaVia.Theme.textPrimary
            buttonRadius: RedaVia.Theme.buttonRadius

            text: root.yesButtonText

            clickedFunc: function() {
                if (root.yesButtonFunction && typeof root.yesButtonFunction === "function") {
                    root.yesButtonFunction()
                }
            }
        }

        BasicButtonType {
            id: noButton
            Layout.fillWidth: true
            Layout.rightMargin: 16
            Layout.leftMargin: 16

            fontFamily: RedaVia.Theme.fontFamily
            defaultColor: RedaVia.Theme.cardBackground
            hoveredColor: RedaVia.Theme.cardBackgroundAlt
            pressedColor: RedaVia.Theme.borderColor
            disabledColor: RedaVia.Theme.cardBackground
            textColor: RedaVia.Theme.textPrimary
            borderColor: RedaVia.Theme.borderColor
            borderFocusedColor: RedaVia.Theme.primaryGreen
            borderWidth: 1
            buttonRadius: RedaVia.Theme.buttonRadius

            visible: root.noButtonText !== ""

            text: root.noButtonText

            clickedFunc: function() {
                if (root.noButtonFunction && typeof root.noButtonFunction === "function") {
                    root.noButtonFunction()
                }
            }
        }
    }
}
