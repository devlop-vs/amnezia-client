import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../Controls2"
import "../Controls2/TextTypes"

import SortFilterProxyModel 0.2

import InstalledAppsModel 1.0
import Style 1.0
import "../RedaVia" as RedaVia

DrawerType2 {
    id: root

    property bool useRedaViaTheme: false

    anchors.fill: parent
    expandedHeight: parent.height * 0.9
    defaultColor: useRedaViaTheme ? RedaVia.Theme.background : AmneziaStyle.color.onyxBlack
    borderColor: useRedaViaTheme ? RedaVia.Theme.borderColor : AmneziaStyle.color.slateGray

    onAboutToShow: {
        PageController.showBusyIndicator(true)
        installedAppsModel.updateModel()
        PageController.showBusyIndicator(false)
    }

    InstalledAppsModel {
        id: installedAppsModel
    }

    expandedStateContent: Item {
        id: container

        implicitHeight: expandedHeight

        ColumnLayout {
            id: backButton

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: searchField.top
            anchors.topMargin: 16

            BackButtonType {
                backButtonImage: "qrc:/images/controls/arrow-left.svg"
                backButtonImageColor: root.useRedaViaTheme ? RedaVia.Theme.textPrimary : AmneziaStyle.color.paleGray
                backButtonFunction: function() {
                    root.closeTriggered()
                }
            }

            Header2Type {
                id: header
                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.rightMargin: 16
                Layout.leftMargin: 16

                fontFamily: root.useRedaViaTheme ? RedaVia.Theme.fontFamily : "PT Root UI VF"
                headerTextColor: root.useRedaViaTheme ? RedaVia.Theme.textPrimary : AmneziaStyle.color.paleGray
                descriptionTextColor: root.useRedaViaTheme ? RedaVia.Theme.textSecondary : AmneziaStyle.color.mutedGray
                headerText: qsTr("Choose application")
            }

            ListViewType {
                id: listView

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 16
                Layout.rightMargin: 16
                Layout.leftMargin: 16

                model: SortFilterProxyModel {
                    id: proxyInstalledAppsModel
                    sourceModel: installedAppsModel
                    filters: RegExpFilter {
                        roleName: "appName"
                        pattern: ".*" + searchField.textField.text + ".*"
                        caseSensitivity: Qt.CaseInsensitive
                    }
                }

                ButtonGroup {
                    id: buttonGroup
                }

                delegate: Item {
                    width: listView.width
                    implicitHeight: appRow.implicitHeight + (root.useRedaViaTheme ? 16 : 0)

                    Rectangle {
                        anchors.fill: parent
                        anchors.bottomMargin: root.useRedaViaTheme ? 8 : 0
                        visible: root.useRedaViaTheme
                        color: RedaVia.Theme.cardBackground
                        border.color: RedaVia.Theme.borderColor
                        border.width: 1
                        radius: RedaVia.Theme.buttonRadius
                    }

                    RowLayout {
                        id: appRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top

                        CheckBoxType {
                            Layout.fillWidth: true

                            fontFamily: root.useRedaViaTheme ? RedaVia.Theme.fontFamily : "PT Root UI VF"
                            textColor: root.useRedaViaTheme ? RedaVia.Theme.textPrimary : AmneziaStyle.color.paleGray
                            descriptionTextColor: root.useRedaViaTheme ? RedaVia.Theme.textSecondary : AmneziaStyle.color.mutedGray
                            hoveredColor: root.useRedaViaTheme ? RedaVia.Theme.cardBackgroundAlt : AmneziaStyle.color.barelyTranslucentWhite
                            defaultBorderColor: root.useRedaViaTheme ? RedaVia.Theme.borderColor : AmneziaStyle.color.paleGray
                            checkedBorderColor: root.useRedaViaTheme ? RedaVia.Theme.primaryGreen : AmneziaStyle.color.goldenApricot
                            checkedImageColor: root.useRedaViaTheme ? RedaVia.Theme.primaryGreen : AmneziaStyle.color.goldenApricot
                            borderFocusedColor: root.useRedaViaTheme ? RedaVia.Theme.primaryGreen : AmneziaStyle.color.paleGray

                            text: appName
                            checked: isAppSelected
                            onCheckedChanged: {
                                installedAppsModel.selectedStateChanged(proxyInstalledAppsModel.mapToSource(index), checked)
                            }
                        }

                        Image {
                            source: "image://installedAppImage/" + appIcon

                            sourceSize.width: 24
                            sourceSize.height: 24

                            Layout.rightMargin: 24
                        }
                    }

                    DividerType {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        visible: !root.useRedaViaTheme
                    }
                }
            }
        }

        TextFieldWithHeaderType {
            id: searchField

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: addButton.top
            anchors.bottomMargin: 16
            anchors.rightMargin: 16
            anchors.leftMargin: 16

            fontFamily: root.useRedaViaTheme ? RedaVia.Theme.fontFamily : "PT Root UI VF"
            headerTextColor: root.useRedaViaTheme ? RedaVia.Theme.textSecondary : AmneziaStyle.color.mutedGray
            textFieldTextColor: root.useRedaViaTheme ? RedaVia.Theme.textPrimary : AmneziaStyle.color.paleGray
            textFieldPlaceholderTextColor: root.useRedaViaTheme ? RedaVia.Theme.textPlaceholder : AmneziaStyle.color.mutedGray
            borderColor: root.useRedaViaTheme ? RedaVia.Theme.borderColor : AmneziaStyle.color.slateGray
            borderFocusedColor: root.useRedaViaTheme ? RedaVia.Theme.primaryGreen : AmneziaStyle.color.paleGray
            backgroundColor: root.useRedaViaTheme ? RedaVia.Theme.cardBackground : AmneziaStyle.color.slateGray
            backgroundDisabledColor: root.useRedaViaTheme ? RedaVia.Theme.cardBackground : AmneziaStyle.color.slateGray
            bgBorderHoveredColor: root.useRedaViaTheme ? RedaVia.Theme.cardBackgroundAlt : AmneziaStyle.color.slateGray
            backgroundRadius: root.useRedaViaTheme ? RedaVia.Theme.inputRadius : 16

            textField.placeholderText: qsTr("application name")
        }

        BasicButtonType {
            id: addButton

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            anchors.rightMargin: 16
            anchors.leftMargin: 16

            fontFamily: root.useRedaViaTheme ? RedaVia.Theme.fontFamily : "PT Root UI VF"
            defaultColor: root.useRedaViaTheme ? RedaVia.Theme.primaryGreen : AmneziaStyle.color.paleGray
            hoveredColor: root.useRedaViaTheme ? Qt.lighter(RedaVia.Theme.primaryGreen, 1.08) : AmneziaStyle.color.lightGray
            pressedColor: root.useRedaViaTheme ? Qt.darker(RedaVia.Theme.primaryGreen, 1.08) : AmneziaStyle.color.mutedGray
            disabledColor: root.useRedaViaTheme ? RedaVia.Theme.borderColor : AmneziaStyle.color.charcoalGray
            textColor: root.useRedaViaTheme ? RedaVia.Theme.background : AmneziaStyle.color.midnightBlack
            borderColor: root.useRedaViaTheme ? RedaVia.Theme.primaryGreen : AmneziaStyle.color.paleGray
            borderFocusedColor: root.useRedaViaTheme ? RedaVia.Theme.textPrimary : AmneziaStyle.color.paleGray
            buttonRadius: root.useRedaViaTheme ? RedaVia.Theme.buttonRadius : 16

            text: qsTr("Add selected")

            clickedFunc: function() {
                PageController.showBusyIndicator(true)
                AppSplitTunnelingController.addApps(installedAppsModel.getSelectedAppsInfo())
                PageController.showBusyIndicator(false)
                root.closeTriggered()
            }
        }
    }
}
