import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Style 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"
import "../Components"
import "../RedaVia" as RedaVia
import PageEnum 1.0

PageType {
    id: root

    Rectangle {
        anchors.fill: parent
        color: RedaVia.Theme.background
        z: -1
    }

    property int selectedPlanIndex: 0
    property string premiumHeaderName: ""
    property string premiumHeaderDescription: ""

    readonly property var currentPlan: ApiSubscriptionPlansModel.planAt(selectedPlanIndex)

    function syncFromModel() {
        root.selectedPlanIndex = ApiSubscriptionPlansModel.recommendedRowIndex()

        root.premiumHeaderName = String(ApiServicesModel.getSelectedServiceData("name"))
        root.premiumHeaderDescription = String(ApiServicesModel.getSelectedServiceData("serviceDescription"))
    }

    Component.onCompleted: syncFromModel()

    BackButtonType {
        id: backButton

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 20 + PageController.safeAreaTopMargin

        onFocusChanged: {
            if (activeFocus) {
                flick.contentY = 0
            }
        }
    }

    FlickableType {
        id: flick

        anchors.top: backButton.bottom
        anchors.bottom: continueButton.top
        anchors.left: parent.left
        anchors.right: parent.right

        contentHeight: scrollColumn.childrenRect.height + 24

        ColumnLayout {
            id: scrollColumn

            width: flick.width
            spacing: 0

            BaseHeaderType {
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.bottomMargin: 24

                headerText: root.premiumHeaderName
                descriptionText: root.premiumHeaderDescription
                fontFamily: RedaVia.Theme.fontFamily
                headerTextColor: RedaVia.Theme.textPrimary
                descriptionTextColor: RedaVia.Theme.textSecondary
            }

            Repeater {
                model: ApiSubscriptionPlansModel

                delegate: SubscriptionPlanCard {
                    required property int index
                    required property var model

                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.bottomMargin: index === ApiSubscriptionPlansModel.rowCount() - 1 ? 24 : 12

                    selected: root.selectedPlanIndex === index
                    billingPeriod: String(model.billingPeriod)
                    priceLabel: String(model.priceLabel)
                    subtitle: String(model.subtitle)
                    showRecommendedBadge: !!model.recommended
                    recommendedText: qsTr("Recommended")
                    fontFamily: RedaVia.Theme.fontFamily
                    defaultColor: RedaVia.Theme.cardBackground
                    selectedColor: RedaVia.Theme.cardBackgroundAlt
                    defaultBorderColor: RedaVia.Theme.borderColor
                    selectedBorderColor: RedaVia.Theme.primaryGreen
                    primaryTextColor: RedaVia.Theme.textPrimary
                    selectedTextColor: RedaVia.Theme.primaryGreen
                    secondaryTextColor: RedaVia.Theme.textSecondary
                    badgeColor: RedaVia.Theme.primaryGreen
                    badgeTextColor: RedaVia.Theme.background
                    cardRadius: RedaVia.Theme.cardRadius

                    onSelectRequested: root.selectedPlanIndex = index
                }
            }

            LabelTextType {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.bottomMargin: 12

                text: qsTr("Premium features")
                color: RedaVia.Theme.textSecondary
                font.family: RedaVia.Theme.fontFamily
                font.pixelSize: 13
            }

            BenefitsPanel {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.bottomMargin: 24

                benefitsModel: ApiBenefitsModel
                fontFamily: RedaVia.Theme.fontFamily
                panelColor: RedaVia.Theme.cardBackground
                panelBorderColor: RedaVia.Theme.borderColor
                titleColor: RedaVia.Theme.textPrimary
                bodyColor: RedaVia.Theme.textSecondary
                linkColor: RedaVia.Theme.primaryGreen
                panelRadius: RedaVia.Theme.cardRadius
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.bottomMargin: 24
                visible: Qt.platform.os === "ios" || IsMacOsNeBuild || (Qt.platform.os === "android" && IsGooglePlayBillingBuild)
                spacing: 16

                ParagraphTextType {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    textFormat: Text.PlainText
                    color: RedaVia.Theme.textSecondary
                    font.family: RedaVia.Theme.fontFamily
                    font.pixelSize: 12

                    text: {
                        if (Qt.platform.os === "android" && IsGooglePlayBillingBuild) {
                            return qsTr("Charged through Google Play at confirmation. Renews automatically unless canceled before the end of the current billing period. Manage in Google Play subscriptions.")
                        }
                        return qsTr("Charged to your Apple ID at confirmation. Renews automatically unless auto-renew is turned off at least 24 hours before period end. Manage in Apple ID settings.")
                    }
                }

                TermsAndPrivacyText {
                    fontFamily: RedaVia.Theme.fontFamily
                    textColor: RedaVia.Theme.textSecondary
                    linkColorString: RedaVia.Theme.primaryGreen
                    termsUrl: (Qt.platform.os === "android" && IsGooglePlayBillingBuild)
                              ? String(ApiServicesModel.getSelectedServiceData("termsOfUseUrl"))
                              : "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
                    privacyUrl: LanguageUiController.getCurrentSiteUrl("policy")
                }
            }

            TermsAndPrivacyText {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.bottomMargin: 24

                visible: !(Qt.platform.os === "ios" || IsMacOsNeBuild || (Qt.platform.os === "android" && IsGooglePlayBillingBuild))

                fontFamily: RedaVia.Theme.fontFamily
                textColor: RedaVia.Theme.textSecondary
                linkColorString: RedaVia.Theme.primaryGreen

                termsUrl: String(ApiServicesModel.getSelectedServiceData("termsOfUseUrl"))
                privacyUrl: String(ApiServicesModel.getSelectedServiceData("privacyPolicyUrl"))
            }
        }
    }

    BasicButtonType {
        id: continueButton

        z: 2
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 16 + PageController.safeAreaBottomMargin

        text: {
            var plan = root.currentPlan
            if (!plan) {
                return qsTr("Continue")
            }
            return qsTr("Subscribe — %1 for %2").arg(String(plan.billingPeriod)).arg(String(plan.priceLabel))
        }

        defaultColor: RedaVia.Theme.primaryGreen
        hoveredColor: "#57ed86"
        pressedColor: "#24c95a"
        disabledColor: RedaVia.Theme.borderColor
        textColor: RedaVia.Theme.background
        fontFamily: RedaVia.Theme.fontFamily
        buttonRadius: RedaVia.Theme.buttonRadius

        clickedFunc: function() {
            var plan = root.currentPlan
            if (!plan) {
                return
            }
            if (plan.isTrial) {
                PageController.goToPage(PageEnum.PageSetupWizardApiTrialEmail)
                return
            }
            if (Qt.platform.os === "ios" || IsMacOsNeBuild) {
                PageController.showBusyIndicator(true)
                var storeId = plan.storeProductId !== undefined ? String(plan.storeProductId) : ""
                SubscriptionUiController.importPremiumFromAppStore(storeId)
                PageController.showBusyIndicator(false)
                return
            }
            if (Qt.platform.os === "android" && IsGooglePlayBillingBuild) {
                PageController.showBusyIndicator(true)
                var androidStoreId = plan.storeProductId !== undefined ? String(plan.storeProductId) : ""
                var androidStoreProductType = plan.storeProductType !== undefined ? String(plan.storeProductType) : ""
                var androidGooglePlayBasePlanId = plan.googlePlayBasePlanId !== undefined ? String(plan.googlePlayBasePlanId) : ""
                SubscriptionUiController.importPremiumFromGooglePlay(androidStoreId, androidStoreProductType, androidGooglePlayBasePlanId)
                PageController.showBusyIndicator(false)
                return
            }
            if (plan.checkoutUrl) {
                Qt.openUrlExternally(plan.checkoutUrl)
                PageController.closePage()
                PageController.closePage()
                return
            }
        }
    }
}
