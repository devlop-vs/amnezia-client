import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import Style 1.0

import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"
import "../RedaVia" as RedaVia

DrawerType2 {
    id: root

    defaultColor: RedaVia.Theme.background
    borderColor: RedaVia.Theme.borderColor

    expandedStateContent: Item {
        id: container

        implicitHeight: root.height * 0.9

        Component.onCompleted: {
            root.expandedHeight = container.implicitHeight
        }

        ColumnLayout {
            id: backButtonLayout

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 16

            BackButtonType {
                id: backButton

                Layout.fillWidth: true
                backButtonImageColor: RedaVia.Theme.textPrimary

                backButtonImage: "qrc:/images/controls/arrow-left.svg"
                backButtonFunction: function() { root.closeTriggered() }
            }

            Header2Type {
                id: header

                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.rightMargin: 16
                Layout.leftMargin: 16

                fontFamily: RedaVia.Theme.fontFamily
                headerTextColor: RedaVia.Theme.textPrimary
                descriptionTextColor: RedaVia.Theme.textSecondary
                actionButtonImageColor: RedaVia.Theme.textPrimary
                headerText: qsTr("Choose language")
            }
        }

        ListViewType {
            id: listView

            anchors.top: backButtonLayout.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            property int selectedIndex: LanguageUiController.currentLanguageIndex

            model: LanguageModel

            ButtonGroup {
                id: buttonGroup
            }

            delegate: Item {
                implicitWidth: listView.width - 32
                implicitHeight: delegateContent.implicitHeight + 6
                x: 16

                ColumnLayout {
                    id: delegateContent

                    anchors.fill: parent

                    RadioButton {
                        id: radioButton

                        implicitWidth: parent.width
                        implicitHeight: radioButtonContent.implicitHeight

                        hoverEnabled: true

                        property bool isFocusable: true

                        Keys.onTabPressed: {
                            FocusController.nextKeyTabItem()
                        }

                        Keys.onBacktabPressed: {
                            FocusController.previousKeyTabItem()
                        }

                        Keys.onUpPressed: {
                            FocusController.nextKeyUpItem()
                        }

                        Keys.onDownPressed: {
                            FocusController.nextKeyDownItem()
                        }

                        Keys.onLeftPressed: {
                            FocusController.nextKeyLeftItem()
                        }

                        Keys.onRightPressed: {
                            FocusController.nextKeyRightItem()
                        }

                        indicator: Rectangle {
                            width: parent.width
                            height: parent.height - 6
                            anchors.verticalCenter: parent.verticalCenter
                            radius: RedaVia.Theme.inputRadius
                            color: radioButton.hovered ? RedaVia.Theme.cardBackgroundAlt : RedaVia.Theme.cardBackground
                            border.color: radioButton.checked || radioButton.focus ? RedaVia.Theme.primaryGreen : RedaVia.Theme.borderColor
                            border.width: 1

                            Behavior on color {
                                PropertyAnimation { duration: 200 }
                            }
                            Behavior on border.color {
                                PropertyAnimation { duration: 200 }
                            }
                        }

                        RowLayout {
                            id: radioButtonContent
                            anchors.fill: parent

                            anchors.rightMargin: 16
                            anchors.leftMargin: 16

                            spacing: 0

                            z: 1

                            ParagraphTextType {
                                Layout.fillWidth: true
                                Layout.topMargin: 20
                                Layout.bottomMargin: 20

                                text: languageName
                                color: RedaVia.Theme.textPrimary
                                font.family: RedaVia.Theme.fontFamily
                            }

                            Image {
                                source: "qrc:/images/controls/check.svg"
                                visible: radioButton.checked

                                width: 24
                                height: 24

                                Layout.rightMargin: 8

                                layer.enabled: true
                                layer.effect: ColorOverlay {
                                    color: RedaVia.Theme.primaryGreen
                                }
                            }
                        }

                        ButtonGroup.group: buttonGroup
                        checked: listView.selectedIndex === index

                        onClicked: {
                            listView.selectedIndex = index
                            LanguageUiController.changeLanguage(languageIndex)
                            root.closeTriggered()
                        }
                    }
                }

                Keys.onEnterPressed: radioButton.clicked()
                Keys.onReturnPressed: radioButton.clicked()
            }
        }
    }
}
