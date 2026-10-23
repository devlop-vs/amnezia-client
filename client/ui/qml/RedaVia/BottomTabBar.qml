import QtQuick 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects

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
        anchors.fill: parent
        anchors.topMargin: 8
        spacing: 0

        Repeater {
            model: [
                "qrc:/ui/qml/RedaVia/assets/home.svg",
                "qrc:/ui/qml/RedaVia/assets/countries.svg",
                "qrc:/ui/qml/RedaVia/assets/subscription.svg",
                "qrc:/ui/qml/RedaVia/assets/settings.svg"
            ]

            Item {
                Layout.fillWidth: true
                Layout.preferredWidth: root.width / 4
                Layout.fillHeight: true

                property bool isActive: root.currentIndex === index

                Image {
                    id: tabIcon
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: modelData
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: width
                    sourceSize.height: height

                    layer.enabled: true
                    layer.effect: ColorOverlay {
                        color: isActive ? Theme.primaryGreen : Theme.textSecondary
                    }

                    scale: tabMouse.pressed ? 0.85 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }
                }

                MouseArea {
                    id: tabMouse
                    anchors.fill: parent
                    onClicked: {
                        root.currentIndex = index
                        root.tabClicked(index)
                    }
                }
            }
        }
    }
}
