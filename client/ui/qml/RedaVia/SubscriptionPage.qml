import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    width: Theme.screenWidth
    height: Theme.screenHeight
    radius: Theme.screenRadius
    color: Theme.background
    clip: true

    property int selectedPlan: 1
    signal continueClicked(int planIndex)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        //StatusBar { Layout.fillWidth: true }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 24
            text: "Choose your plan"
            font { family: Theme.fontFamily; pixelSize: 27; bold: true }
            color: Theme.textPrimary
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 10
            text: "Unlimited protection on every device"
            font { family: Theme.fontFamily; pixelSize: 14 }
            color: Theme.textSecondary
            horizontalAlignment: Text.AlignHCenter
        }

        // Plan cards
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.topMargin: 30
            spacing: 24

            Repeater {
                model: ListModel {
                    id: planModel
                    ListElement { name: "Monthly"; price: "$9.99"; badge: "Flexible"; badgeColor: "#ffd21e" }
                    ListElement { name: "Yearly"; price: "$4.99 / mo"; badge: "Most popular"; badgeColor: "#35e76f" }
                    ListElement { name: "2 Years"; price: "$3.49 / mo"; badge: "Best value"; badgeColor: "#ffd21e" }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 126
                    radius: Theme.cardRadius

                    property bool isSelected: root.selectedPlan === index

                    color: isSelected ? "#173b2a" : Theme.cardBackground
                    border {
                        width: isSelected ? 2 : 1
                        color: isSelected ? Theme.primaryGreen : Theme.borderColor
                    }

                    Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                    Behavior on border.color { ColorAnimation { duration: 250 } }
                    Behavior on border.width { NumberAnimation { duration: 250 } }

                    scale: planMouse.pressed ? 0.97 : (isSelected ? 1.02 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 24
                        anchors.rightMargin: 24

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: model.name
                                font { family: Theme.fontFamily; pixelSize: 18; weight: Font.DemiBold }
                                color: Theme.textPrimary
                            }
                            Text {
                                text: model.price
                                font { family: Theme.fontFamily; pixelSize: 25; bold: true }
                                color: Theme.textPrimary
                            }
                        }

                        Text {
                            text: model.badge
                            font { family: Theme.fontFamily; pixelSize: 12; weight: Font.Medium }
                            color: model.badgeColor
                        }
                    }

                    MouseArea {
                        id: planMouse
                        anchors.fill: parent
                        onClicked: root.selectedPlan = index
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        PrimaryButton {
            Layout.leftMargin: 20
            Layout.rightMargin: 20
            Layout.bottomMargin: root.height - Theme.tabBarY + 20
            text: "Continue"
            onClicked: root.continueClicked(root.selectedPlan)
        }
    }

    BottomTabBar { currentIndex: 2 }
}
