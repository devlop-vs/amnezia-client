import QtQuick 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    width: parent.width
    height: parent.height - Theme.tabBarY
    y: Theme.tabBarY

    property int currentIndex: 0
    signal tabClicked(int index)

    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: Theme.borderColor
    }

    RowLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 8
        spacing: 50

        Repeater {
            model: [
                { icon: "⌂", label: "Home" },
                { icon: "◉", label: "Locations" },
                { icon: "▣", label: "Subscription" },
                { icon: "◎", label: "Profile" }
            ]

            ColumnLayout {
                spacing: 4
                Layout.preferredWidth: 58

                property bool isActive: root.currentIndex === index

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: modelData.icon
                    font { family: Theme.fontFamily; pixelSize: 18 }
                    color: isActive ? Theme.primaryGreen : Theme.textSecondary
                    Behavior on color { ColorAnimation { duration: 200 } }

                    scale: tabMouse.pressed ? 0.85 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: modelData.label
                    font {
                        family: Theme.fontFamily; pixelSize: 10
                        weight: isActive ? Font.Medium : Font.Normal
                    }
                    color: isActive ? Theme.primaryGreen : Theme.textSecondary
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                MouseArea {
                    id: tabMouse
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    onClicked: {
                        root.currentIndex = index
                        root.tabClicked(index)
                    }
                }
            }
        }
    }
}
