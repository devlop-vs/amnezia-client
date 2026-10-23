import QtQuick
import QtQuick.Layouts

import Style 1.0

import "../Controls2/TextTypes"

ParagraphTextType {
    id: root

    property string termsUrl: ""
    property string privacyUrl: ""
    property string fontFamily: "PT Root UI VF"
    property color textColor: AmneziaStyle.color.mutedGray
    property string linkColorString: AmneziaStyle.color.goldenApricotString

    Layout.fillWidth: true

    horizontalAlignment: Text.AlignHCenter
    textFormat: Text.RichText
    color: root.textColor
    font.family: root.fontFamily
    font.pixelSize: 12
    lineHeight: 1.35
    lineHeightMode: Text.ProportionalHeight

    text: qsTr("By continuing, you agree to the <a href=\"%1\" style=\"color: %3;\">Terms of Use</a> and <a href=\"%2\" style=\"color: %3;\">Privacy Policy</a>")
            .arg(root.termsUrl)
            .arg(root.privacyUrl)
            .arg(root.linkColorString)

    onLinkActivated: function(link) {
        Qt.openUrlExternally(link)
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
}
