import QtQuick
import QtQuick.Layouts

import "."

import Style 1.0

Rectangle {
    id: root

    property var benefitsModel: null
    property string fontFamily: "PT Root UI VF"
    property color panelColor: AmneziaStyle.color.benefitsPanelBackground
    property color panelBorderColor: AmneziaStyle.color.transparent
    property color titleColor: AmneziaStyle.color.paleGray
    property color bodyColor: AmneziaStyle.color.mutedGray
    property color linkColor: AmneziaStyle.color.goldenApricot
    property int panelRadius: 16

    visible: benefitsModel && benefitsModel.rowCount() > 0

    radius: root.panelRadius
    color: root.panelColor
    border.width: panelBorderColor === AmneziaStyle.color.transparent ? 0 : 1
    border.color: root.panelBorderColor
    implicitHeight: inner.implicitHeight + 24

    ColumnLayout {
        id: inner

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 20

        Repeater {
            model: benefitsModel

            delegate: BenefitRow {
                Layout.fillWidth: true
                iconSource: model.icon
                titleText: model.title
                bodyText: model.body
                link: !!model.link
                fontFamily: root.fontFamily
                titleColor: root.titleColor
                bodyColor: root.bodyColor
                linkColor: root.linkColor
            }
        }
    }
}
