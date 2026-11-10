import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import PageEnum 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Config"
import "../RedaVia" as RedaVia
import "../Controls2/TextTypes"
import "../Components"

PageType {
    id: root

    Rectangle {
        anchors.fill: parent
        color: RedaVia.Theme.background
        z: -1
    }

    BackButtonType {
        id: backButton

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 20 + PageController.safeAreaTopMargin
        backButtonImageColor: RedaVia.Theme.textPrimary

        onActiveFocusChanged: {
            if(backButton.enabled && backButton.activeFocus) {
                listView.positionViewAtBeginning()
            }
        }
    }

    ListViewType {
        id: listView

        anchors.top: backButton.bottom
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.left: parent.left

        header: ColumnLayout {
            width: listView.width

            Image {
                id: image
                source: "qrc:/images/amneziaBigLogo.png"

                Layout.alignment: Qt.AlignCenter
                Layout.topMargin: 16
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.preferredWidth: 291
                Layout.preferredHeight: 224
            }

            Header2TextType {
                font.family: RedaVia.Theme.fontFamily
                color: RedaVia.Theme.textPrimary
                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                text: qsTr("Support RedaVPN")
                horizontalAlignment: Text.AlignHCenter
            }

            ParagraphTextType {
                font.family: RedaVia.Theme.fontFamily
                color: RedaVia.Theme.textSecondary
                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                horizontalAlignment: Text.AlignHCenter

                Layout.preferredHeight: 20
                font.pixelSize: 14

                text: qsTr("RedaVPN is a free and open-source application. You can support the developers if you like it.")
            }

            ParagraphTextType {
                font.family: RedaVia.Theme.fontFamily
                color: RedaVia.Theme.textSecondary
                Layout.fillWidth: true
                Layout.topMargin: 32
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                text: qsTr("Contacts")
            }
        }

        model: contacts

        delegate: ColumnLayout {
            width: listView.width

            LabelWithButtonType {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                fontFamily: RedaVia.Theme.fontFamily
                cardColor: RedaVia.Theme.cardBackground
                cardBorderColor: RedaVia.Theme.borderColor
                cardBorderWidth: 1
                cardRadius: RedaVia.Theme.buttonRadius
                textColor: RedaVia.Theme.textPrimary
                descriptionColor: RedaVia.Theme.textSecondary
                rightImageColor: RedaVia.Theme.textPrimary
                leftImageColor: RedaVia.Theme.textPrimary
                Layout.topMargin: 6

                text: title
                descriptionText: description
                leftImageSource: imageSource

                clickedFunction: handler
            }

            DividerType { visible: false }

        }

        footer: ColumnLayout {
            width: listView.width

            CaptionTextType {
                font.family: RedaVia.Theme.fontFamily
                color: RedaVia.Theme.textSecondary
                Layout.fillWidth: true
                Layout.topMargin: 40

                horizontalAlignment: Text.AlignHCenter

                text: qsTr("Software version: %1").arg(SettingsController.getAppVersion())

                MouseArea {
                    property int clickCount: 0
                    anchors.fill: parent
                    onClicked: {
                        if (clickCount > 10) {
                            SettingsController.enableDevMode()
                        } else {
                            clickCount++
                        }
                    }
                }
            }

            BasicButtonType {
                fontFamily: RedaVia.Theme.fontFamily
                borderColor: RedaVia.Theme.primaryGreen
                borderFocusedColor: RedaVia.Theme.primaryGreen
                buttonRadius: RedaVia.Theme.buttonRadius
                id: checkUpdatesButton

                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                Layout.bottomMargin: 16
                implicitHeight: 32

                defaultColor: RedaVia.Theme.cardBackground
                hoveredColor: RedaVia.Theme.cardBackgroundAlt
                pressedColor: RedaVia.Theme.connectedInner
                disabledColor: RedaVia.Theme.cardBackgroundAlt
                textColor: RedaVia.Theme.primaryGreen

                text: qsTr("Check for updates")

                clickedFunc: function() {
                    Qt.openUrlExternally("https://redavpn.com/client/desktop-client/releases/latest")
                }
            }

            BasicButtonType {
                fontFamily: RedaVia.Theme.fontFamily
                borderColor: RedaVia.Theme.primaryGreen
                borderFocusedColor: RedaVia.Theme.primaryGreen
                buttonRadius: RedaVia.Theme.buttonRadius
                id: privacyPolicyButton

                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 16
                Layout.topMargin: -15
                implicitHeight: 25

                defaultColor: RedaVia.Theme.cardBackground
                hoveredColor: RedaVia.Theme.cardBackgroundAlt
                pressedColor: RedaVia.Theme.connectedInner
                disabledColor: RedaVia.Theme.cardBackgroundAlt
                textColor: RedaVia.Theme.primaryGreen

                text: qsTr("Privacy Policy")

                clickedFunc: function() {
                    Qt.openUrlExternally(LanguageUiController.getCurrentSiteUrl("policy"))
                }
            }
        }
    }
    
    property list<QtObject> contacts: [
        telegramGroup,
        mail,
        github,
        website
    ]

    QtObject {
        id: telegramGroup

        readonly property string title: qsTr("Telegram group")
        readonly property string description: qsTr("To discuss features")
        readonly property string imageSource: "qrc:/images/controls/telegram.svg"
        readonly property var handler: function() {
            Qt.openUrlExternally(qsTr("https://t.me/RedaLink_QA"))
        }
    }

    QtObject {
        id: mail

        readonly property string title: qsTr("support@redavpn.com")
        readonly property string description: qsTr("For reviews and bug reports")
        readonly property string imageSource: "qrc:/images/controls/mail.svg"
        readonly property var handler: function() {
            Qt.openUrlExternally(qsTr("mailto:support@redavpn.com"))
        }
    }

    QtObject {
        id: github

        readonly property string title: qsTr("GitHub")
        readonly property string description: qsTr("Discover the source code")
        readonly property string imageSource: "qrc:/images/controls/github.svg"
        readonly property var handler: function() {
            Qt.openUrlExternally(qsTr("https://redavpn.com/client/redavpn-client"))
        }
    }

    QtObject {
        id: website

        readonly property string title: qsTr("Website")
        readonly property string description: qsTr("Visit official website")
        readonly property string imageSource: "qrc:/images/controls/amnezia.svg"
        readonly property var handler: function() {
            Qt.openUrlExternally(LanguageUiController.getCurrentSiteUrl())
        }
    }
}
