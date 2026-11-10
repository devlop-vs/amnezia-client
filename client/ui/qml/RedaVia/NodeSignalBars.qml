pragma ComponentBehavior: Bound

import QtQuick 2.15
import QtQuick.Layouts 1.15

RowLayout {
    id: root

    property int bars: 0
    property string status: "unknown"
    property color activeColor: Theme.primaryGreen
    property color inactiveColor: Theme.textSubtle

    spacing: 2
    implicitWidth: 26
    implicitHeight: 16

    Repeater {
        model: 4

        delegate: Rectangle {
            required property int index

            Layout.alignment: Qt.AlignBottom
            Layout.preferredWidth: 5
            Layout.preferredHeight: 4 + index * 4
            radius: 1
            color: root.status !== "offline" && root.status !== "unknown" && index < root.bars
                   ? root.activeColor : root.inactiveColor
        }
    }
}
