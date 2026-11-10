import QtQuick 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root

    Layout.fillWidth: true
    Layout.leftMargin: 28
    Layout.rightMargin: 28
    Layout.topMargin: 20
    Layout.bottomMargin: 24
    implicitHeight: statsContent.implicitHeight + 40
    radius: Theme.cardRadius
    color: Theme.cardBackground
    border.color: Theme.borderColor
    border.width: 1

    ColumnLayout {
        id: statsContent
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        Text {
            Layout.fillWidth: true
            text: qsTr("🌐  VPN-Protected Network Stats")
            font { family: Theme.fontFamily; pixelSize: 16; weight: Font.DemiBold }
            color: Theme.textPrimary
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 12
            rowSpacing: 12

            Repeater {
                model: [
                    { key: "todayDuration", label: qsTr("Protected Duration Today") },
                    { key: "todayTraffic", label: qsTr("Protected Volume Today") },
                    { key: "monthDuration", label: qsTr("Protected Duration This Month") },
                    { key: "monthTraffic", label: qsTr("Protected Volume This Month") }
                ]

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 76
                    radius: Theme.smallRadius
                    color: Theme.cardBackgroundAlt
                    border.color: Theme.borderColor
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: modelData.label
                            font { family: Theme.fontFamily; pixelSize: 11 }
                            color: Theme.textSecondary
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                switch (modelData.key) {
                                case "todayDuration":
                                    return ConnectionController.todayProtectedDurationText
                                case "todayTraffic":
                                    return ConnectionController.todayProtectedVolumeText
                                case "monthDuration":
                                    return ConnectionController.monthProtectedDurationText
                                case "monthTraffic":
                                    return ConnectionController.monthProtectedVolumeText
                                }
                                return "--"
                            }
                            font { family: Theme.fontFamily; pixelSize: 16; weight: Font.DemiBold }
                            color: Theme.primaryGreen
                        }
                    }
                }
            }
        }
    }
}
