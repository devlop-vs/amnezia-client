#include "subscriptionUiController.h"

#include "amneziaApplication.h"
#include "core/configurators/wireguardConfigurator.h"
#include "core/utils/serverConfigUtils.h"
#include "core/utils/constants/apiKeys.h"
#include "core/utils/constants/apiConstants.h"
#include "core/utils/api/apiUtils.h"
#include "core/utils/qrCodeUtils.h"
#include "ui/controllers/systemController.h"
#include "version.h"
#include <QClipboard>
#include <QCoreApplication>
#include <QDebug>
#include <QSet>
#include <QEventLoop>
#include <QFutureWatcher>
#include <QTimer>

#if defined(Q_OS_ANDROID) && defined(GPAY)
#include "platforms/android/android_controller.h"
#endif

namespace
{
    namespace configKey
    {
        constexpr char awg[] = "awg";
        constexpr char vless[] = "vless";

        constexpr char apiEndpoint[] = "api_endpoint";
        constexpr char accessToken[] = "api_key";
        constexpr char certificate[] = "certificate";
        constexpr char publicKey[] = "public_key";
        constexpr char protocol[] = "protocol";

        constexpr char uuid[] = "installation_uuid";
        constexpr char osVersion[] = "os_version";
        constexpr char appVersion[] = "app_version";

        constexpr char userCountryCode[] = "user_country_code";
        constexpr char serverCountryCode[] = "server_country_code";
        constexpr char serviceType[] = "service_type";
        constexpr char serviceInfo[] = "service_info";
        constexpr char serviceProtocol[] = "service_protocol";

        constexpr char apiPayload[] = "api_payload";
        constexpr char keyPayload[] = "key_payload";

        constexpr char apiConfig[] = "api_config";
        constexpr char authData[] = "auth_data";

        constexpr char config[] = "config";

        constexpr char subscription[] = "subscription";
        constexpr char endDate[] = "end_date";

        constexpr char isConnectEvent[] = "is_connect_event";
    }

}

SubscriptionUiController::SubscriptionUiController(ServersController* serversController,
                                           ApiServicesModel* apiServicesModel,
                                           ServicesCatalogController* servicesCatalogController,
                                           SubscriptionController* subscriptionController,
                                           ApiSubscriptionPlansModel* apiSubscriptionPlansModel,
                                           ApiBenefitsModel* apiBenefitsModel,
                                           ApiAccountInfoModel* apiAccountInfoModel,
                                           ApiCountryModel* apiCountryModel,
                                           ApiDevicesModel* apiDevicesModel,
                                           SettingsController* settingsController,
                                           ConnectionController* connectionController,
                                           QObject *parent)
    : QObject(parent),
      m_serversController(serversController),
      m_apiServicesModel(apiServicesModel),
      m_servicesCatalogController(servicesCatalogController),
      m_subscriptionController(subscriptionController),
      m_apiSubscriptionPlansModel(apiSubscriptionPlansModel),
      m_apiBenefitsModel(apiBenefitsModel),
      m_apiAccountInfoModel(apiAccountInfoModel),
      m_apiCountryModel(apiCountryModel),
      m_apiDevicesModel(apiDevicesModel),
      m_settingsController(settingsController),
      m_connectionController(connectionController)
{
    connect(m_apiServicesModel, &ApiServicesModel::serviceSelectionChanged, this, [this]() {
        ApiServicesModel::ApiServicesData selectedServiceData = m_apiServicesModel->selectedServiceData();
        m_apiSubscriptionPlansModel->updateModel(selectedServiceData.subscriptionPlansJson);
        m_apiBenefitsModel->updateModel(selectedServiceData.benefits);
        m_googlePlayMonthlyPriceLabels.clear();

#if defined(Q_OS_ANDROID) && defined(GPAY)
        for (const QJsonValue &planValue : selectedServiceData.subscriptionPlansJson) {
            if (!planValue.isObject()) {
                continue;
            }

            const QJsonObject planObject = planValue.toObject();
            const QString productId = planObject.value(QStringLiteral("store_product_id")).toString().trimmed();
            if (productId.isEmpty()) {
                continue;
            }

            QString productType = planObject.value(QStringLiteral("store_product_type")).toString().trimmed().toLower();
            if (productType.isEmpty()) {
                productType = QStringLiteral("subs");
            }

            AndroidController::instance()->requestProductDetails(
                productId,
                productType,
                planObject.value(QStringLiteral("google_play_base_plan_id")).toString().trimmed());
        }
#endif
    });

#if defined(Q_OS_ANDROID) && defined(GPAY)
    connect(AndroidController::instance(), &AndroidController::googlePlayProductDetailsReceived, this,
            [this](bool success, const QString &productId, const QString &productType,
                   const QString &googlePlayBasePlanId, const QString &priceLabel,
               const QString &subtitleLabel, const QString &monthlyPriceLabel,
               qlonglong monthlyPriceAmountMicros,
                   const QString &errorString) {
                if (!success) {
                    qWarning().noquote() << "[IAP][GooglePlay] Product details request failed:" << productId
                                         << productType << googlePlayBasePlanId << errorString;
                    return;
                }

                m_apiSubscriptionPlansModel->updatePricingDetails(productId, productType, googlePlayBasePlanId,
                                                                  priceLabel, subtitleLabel);

                const QString planKey = googlePlayPlanKey(productId, productType, googlePlayBasePlanId);
                if (monthlyPriceLabel.isEmpty()) {
                    m_googlePlayMonthlyPriceLabels.remove(planKey);
                } else {
                    m_googlePlayMonthlyPriceLabels.insert(planKey, { monthlyPriceLabel, monthlyPriceAmountMicros });
                }
                refreshGooglePlayMinPriceLabel();
            });
#endif

    connect(this, &SubscriptionUiController::installServerFromApiFinished, this,
            [this](const QString &, int preferredDefaultServerIndex) {
        if (m_connectionController->isConnected()) {
            return;
        }

        const int selectedServerIndex = preferredDefaultServerIndex >= 0
                ? preferredDefaultServerIndex
                : (m_serversController->getServersCount() - 1);
        const QString serverId = m_serversController->getServerId(selectedServerIndex);
        if (!serverId.isEmpty()) {
            m_serversController->setDefaultServer(serverId);
        }
    });
}

QString SubscriptionUiController::googlePlayPlanKey(const QString &productId, const QString &productType,
                                                    const QString &googlePlayBasePlanId) const
{
    return productId.trimmed() + QStringLiteral("|")
           + productType.trimmed().toLower() + QStringLiteral("|")
           + googlePlayBasePlanId.trimmed();
}

void SubscriptionUiController::refreshGooglePlayMinPriceLabel()
{
#if defined(Q_OS_ANDROID) && defined(GPAY)
    const QString selectedServiceType = m_apiServicesModel->getSelectedServiceType();
    if (selectedServiceType != QStringLiteral("amnezia-premium") || m_googlePlayMonthlyPriceLabels.isEmpty()) {
        return;
    }

    QString minMonthlyPriceLabel;
    qlonglong minMonthlyPriceAmountMicros = 0;
    for (auto it = m_googlePlayMonthlyPriceLabels.cbegin(); it != m_googlePlayMonthlyPriceLabels.cend(); ++it) {
        if (it.value().label.isEmpty() || it.value().amountMicros <= 0) {
            continue;
        }
        if (minMonthlyPriceLabel.isEmpty() || it.value().amountMicros < minMonthlyPriceAmountMicros) {
            minMonthlyPriceLabel = it.value().label;
            minMonthlyPriceAmountMicros = it.value().amountMicros;
        }
    }

    if (minMonthlyPriceLabel.isEmpty()) {
        return;
    }

    m_apiServicesModel->updateMinPriceLabelForType(
        selectedServiceType,
        QCoreApplication::translate("ServicesCatalogController", "from %1 per month",
                                    "IAP: card footer minimum monthly price from Google Play")
            .arg(minMonthlyPriceLabel));
#endif
}

bool SubscriptionUiController::isCaptchaAwaitingUser() const
{
    return m_captchaState.isPending;
}

bool SubscriptionUiController::exportVpnKey(const QString &serverId, const QString &fileName)
{
    if (fileName.isEmpty()) {
        emit errorOccurred(ErrorCode::PermissionsError);
        return false;
    }

    prepareVpnKeyExport(serverId);
    if (m_vpnKey.isEmpty()) {
        emit errorOccurred(ErrorCode::ApiConfigEmptyError);
        return false;
    }

    return SystemController::saveFile(fileName, m_vpnKey);
}


bool SubscriptionUiController::exportNativeConfig(const QString &serverId, const QString &serverCountryCode, const QString &fileName)
{
    if (fileName.isEmpty()) {
        emit errorOccurred(ErrorCode::PermissionsError);
        return false;
    }

    QString nativeConfig;
    ErrorCode errorCode = m_subscriptionController->exportNativeConfig(serverId, serverCountryCode, nativeConfig);
    if (errorCode != ErrorCode::NoError) {
        emit errorOccurred(errorCode);
        return false;
    }

    const bool saved = SystemController::saveFile(fileName, nativeConfig);
    getAccountInfo(serverId, true);
    return saved;
}


bool SubscriptionUiController::revokeNativeConfig(const QString &serverId, const QString &serverCountryCode)
{
    ErrorCode errorCode = m_subscriptionController->revokeNativeConfig(serverId, serverCountryCode);
    if (errorCode != ErrorCode::NoError) {
        emit errorOccurred(errorCode);
        return false;
    }
    return true;
}


void SubscriptionUiController::prepareVpnKeyExport(const QString &serverId)
{
    QString vpnKey;
    ErrorCode errorCode = m_subscriptionController->prepareVpnKeyExport(serverId, vpnKey);
    if (errorCode != ErrorCode::NoError) {
        emit errorOccurred(errorCode);
        return;
    }

    m_vpnKey = vpnKey;

    QString vpnKeyForQr = vpnKey;
    vpnKeyForQr.replace("vpn://", "");

    m_qrCodes = qrCodeUtils::generateQrCodeImageSeries(vpnKeyForQr.toUtf8());

    emit vpnKeyExportReady();
}


void SubscriptionUiController::copyVpnKeyToClipboard()
{
    auto clipboard = amnApp->getClipboard();
    clipboard->setText(m_vpnKey);
}

bool SubscriptionUiController::fillAvailableServices()
{
    QJsonObject servicesData;
    ErrorCode errorCode = m_servicesCatalogController->fillAvailableServices(servicesData);
    if (errorCode != ErrorCode::NoError) {
        emit errorOccurred(errorCode);
        return false;
    }

    m_apiServicesModel->updateModel(servicesData);
    if (m_apiServicesModel->rowCount() > 0) {
        m_apiServicesModel->setServiceIndex(0);
    }
    return true;
}

bool SubscriptionUiController::importPremiumFromAppStore(const QString &storeProductId)
{
#if defined(Q_OS_IOS) || defined(MACOS_NE)
    QString productId = storeProductId.trimmed();
    if (productId.isEmpty()) {
        productId = QStringLiteral("amnezia_premium_6_month");
    }

    int duplicateServerIndex = -1;
    ErrorCode errorCode = m_subscriptionController->processAppStorePurchase(
        m_apiServicesModel->getCountryCode(),
        m_apiServicesModel->getSelectedServiceType(),
        m_apiServicesModel->getSelectedServiceProtocol(),
        productId,
        &duplicateServerIndex);

    if (errorCode != ErrorCode::NoError) {
        if (errorCode == ErrorCode::ApiConfigAlreadyAdded) {
            emit installServerFromApiFinished(tr("This subscription has already been added"), duplicateServerIndex);
            return true;
        }
        emit errorOccurred(errorCode);
        return false;
    }

    emit installServerFromApiFinished(tr("%1 has been added to the app").arg(m_apiServicesModel->getSelectedServiceName()));
#endif
    return true;
}

bool SubscriptionUiController::importPremiumFromGooglePlay(const QString &storeProductId,
                                                           const QString &storeProductType,
                                                           const QString &googlePlayBasePlanId)
{
#if defined(Q_OS_ANDROID) && defined(GPAY)
    QString productId = storeProductId.trimmed();
    QString productType = storeProductType.trimmed().toLower();
    QString basePlanId = googlePlayBasePlanId.trimmed();

    if (productId.isEmpty()) {
        emit errorOccurred(ErrorCode::ApiPurchaseError);
        return false;
    }

    if (productType.isEmpty()) {
        productType = QStringLiteral("subs");
    }

    if (productType != QStringLiteral("subs") && productType != QStringLiteral("inapp")) {
        emit errorOccurred(ErrorCode::ApiPurchaseError);
        return false;
    }

    int duplicateServerIndex = -1;
    ErrorCode errorCode = m_subscriptionController->processGooglePlayPurchase(
        m_apiServicesModel->getCountryCode(),
        m_apiServicesModel->getSelectedServiceType(),
        m_apiServicesModel->getSelectedServiceProtocol(),
        productId,
        productType,
        basePlanId,
        &duplicateServerIndex);

    if (errorCode != ErrorCode::NoError) {
        if (errorCode == ErrorCode::ApiConfigAlreadyAdded) {
            emit installServerFromApiFinished(tr("This subscription has already been added"), duplicateServerIndex);
            return true;
        }
        emit errorOccurred(errorCode);
        return false;
    }

    emit installServerFromApiFinished(tr("%1 has been added to the app").arg(m_apiServicesModel->getSelectedServiceName()));
    return true;
#else
    Q_UNUSED(storeProductId);
    Q_UNUSED(storeProductType);
    Q_UNUSED(googlePlayBasePlanId);
    emit errorOccurred(ErrorCode::ApiPurchaseError);
    return false;
#endif
}

bool SubscriptionUiController::restoreServiceFromAppStore()
{
#if defined(Q_OS_IOS) || defined(MACOS_NE)
    const QString premiumServiceType = QStringLiteral("amnezia-premium");

    if (!fillAvailableServices()) {
        qWarning().noquote() << "[IAP] Unable to fetch services list before restore";
        emit errorOccurred(ErrorCode::ApiServicesMissingError);
        return false;
    }

    if (m_apiServicesModel->rowCount() <= 0) {
        emit errorOccurred(ErrorCode::ApiServicesMissingError);
        return false;
    }

    // Ensure we have a valid premium selection for gateway requests
    bool premiumSelected = false;
    for (int i = 0; i < m_apiServicesModel->rowCount(); ++i) {
        m_apiServicesModel->setServiceIndex(i);
        if (m_apiServicesModel->getSelectedServiceType() == premiumServiceType) {
            premiumSelected = true;
            break;
        }
    }

    if (!premiumSelected) {
        emit errorOccurred(ErrorCode::ApiServicesMissingError);
        return false;
    }

    SubscriptionController::AppStoreRestoreResult result = m_subscriptionController->processAppStoreRestore(
        m_apiServicesModel->getCountryCode(),
        m_apiServicesModel->getSelectedServiceType(),
        m_apiServicesModel->getSelectedServiceProtocol());

    if (!result.hasInstalledConfig) {
        if (result.duplicateConfigAlreadyPresent) {
            emit installServerFromApiFinished(tr("This subscription has already been added"), result.duplicateServerIndex);
            return true;
        }
        emit errorOccurred(result.errorCode);
        return false;
    }

    emit installServerFromApiFinished(tr("Subscription restored successfully."));
    if (result.duplicateCount > 0) {
        qInfo().noquote() << "[IAP] Skipped" << result.duplicateCount
                          << "duplicate restored transactions for original transaction IDs already processed";
    }
#endif
    return true;
}

bool SubscriptionUiController::importFreeFromGateway()
{
    QString userCountryCode = m_apiServicesModel->getCountryCode();
    QString serviceType = m_apiServicesModel->getSelectedServiceType();
    QString serviceProtocol = m_apiServicesModel->getSelectedServiceProtocol();

    if (m_serversController->isServerFromApiAlreadyExists(userCountryCode, serviceType, serviceProtocol)) {
        emit errorOccurred(ErrorCode::ApiConfigAlreadyAdded);
        return false;
    }

    SubscriptionController::ProtocolData protocolData = m_subscriptionController->generateProtocolData(serviceProtocol);
    SubscriptionController::CaptchaInfo captchaInfo;

    ErrorCode errorCode = m_subscriptionController->importServiceFromGateway(userCountryCode, serviceType,
                                                                             serviceProtocol, protocolData,
                                                                             captchaInfo);

    if (errorCode == ErrorCode::NoError) {
        emit installServerFromApiFinished(tr("%1 installed successfully.").arg(m_apiServicesModel->getSelectedServiceName()));
        return true;
    } else if (errorCode == ErrorCode::ApiCaptchaRequiredError && captchaInfo.isRequired) {
        m_captchaState.userCountryCode = userCountryCode;
        m_captchaState.serviceType = serviceType;
        m_captchaState.serviceProtocol = serviceProtocol;
        m_captchaState.openvpnPrivKey = protocolData.certPrivKey;
        m_captchaState.wireguardClientPrivKey = protocolData.wireGuardClientPrivKey;
        m_captchaState.wireguardClientPubKey = protocolData.wireGuardClientPubKey;
        m_captchaState.xrayUuid = protocolData.xrayUuid;
        m_captchaState.isPending = true;

        emit captchaRequired(captchaInfo.captchaId, captchaInfo.captchaImageBase64,
                             captchaInfo.hint.isEmpty() ? tr("Enter the digits from the image to continue") : captchaInfo.hint);
        return false;
    } else {
        emit errorOccurred(errorCode);
        return false;
    }
}

void SubscriptionUiController::onCaptchaSolved(const QString &captchaId, const QString &solution)
{
    if (!m_captchaState.isPending) {
        return;
    }

    SubscriptionController::ProtocolData protocolData;
    protocolData.certPrivKey = m_captchaState.openvpnPrivKey;
    protocolData.wireGuardClientPrivKey = m_captchaState.wireguardClientPrivKey;
    protocolData.wireGuardClientPubKey = m_captchaState.wireguardClientPubKey;
    protocolData.xrayUuid = m_captchaState.xrayUuid;

    SubscriptionController::CaptchaInfo retryCaptcha;
    ErrorCode errorCode = m_subscriptionController->resolveImportServiceCaptcha(
            m_captchaState.userCountryCode,
            m_captchaState.serviceType,
            m_captchaState.serviceProtocol,
            protocolData,
            captchaId,
            solution,
            &retryCaptcha);

    if (errorCode == ErrorCode::NoError) {
        m_captchaState.isPending = false;
        emit captchaFlowDismissRequested();
        emit installServerFromApiFinished(tr("%1 installed successfully.").arg(m_apiServicesModel->getSelectedServiceName()));
        return;
    }

    if ((errorCode == ErrorCode::ApiCaptchaInvalidError || errorCode == ErrorCode::ApiCaptchaRefreshError
         || errorCode == ErrorCode::ApiCaptchaRequiredError)
        && retryCaptcha.isRequired) {
        emit captchaRequired(retryCaptcha.captchaId, retryCaptcha.captchaImageBase64,
                             retryCaptcha.hint.isEmpty() ? tr("Enter the digits from the image to continue") : retryCaptcha.hint);
        return;
    }

    m_captchaState.isPending = false;
    emit errorOccurred(errorCode);
}

void SubscriptionUiController::onRefreshCaptchaRequested()
{
    if (!m_captchaState.isPending) {
        return;
    }

    SubscriptionController::ProtocolData protocolData;
    protocolData.certPrivKey = m_captchaState.openvpnPrivKey;
    protocolData.wireGuardClientPrivKey = m_captchaState.wireguardClientPrivKey;
    protocolData.wireGuardClientPubKey = m_captchaState.wireguardClientPubKey;
    protocolData.xrayUuid = m_captchaState.xrayUuid;

    SubscriptionController::CaptchaInfo captchaInfo;

    ErrorCode errorCode = m_subscriptionController->importServiceFromGateway(
            m_captchaState.userCountryCode,
            m_captchaState.serviceType,
            m_captchaState.serviceProtocol,
            protocolData,
            captchaInfo);

    if (errorCode == ErrorCode::ApiCaptchaRequiredError && captchaInfo.isRequired) {
        emit captchaRequired(captchaInfo.captchaId, captchaInfo.captchaImageBase64,
                             captchaInfo.hint.isEmpty() ? tr("Enter the digits from the image to continue") : captchaInfo.hint);
    } else if (errorCode != ErrorCode::NoError) {
        m_captchaState.isPending = false;
        emit errorOccurred(errorCode);
    }
}

bool SubscriptionUiController::importTrialFromGateway(const QString &email)
{
    emit trialEmailError(QString());
    ErrorCode errorCode = m_subscriptionController->importTrialFromGateway(m_apiServicesModel->getCountryCode(),
                                                                            m_apiServicesModel->getSelectedServiceType(),
                                                                            m_apiServicesModel->getSelectedServiceProtocol(),
                                                                            email);
    if (errorCode != ErrorCode::NoError) {
        if (errorCode == ErrorCode::ApiTrialAlreadyUsedError) {
            emit trialEmailError(
                    tr("This email address has already been used to activate a trial. If you like the service, you can upgrade to Premium"));
        } else {
            emit errorOccurred(errorCode);
        }
        return false;
    }

    emit installServerFromApiFinished(tr("%1 installed successfully.").arg(m_apiServicesModel->getSelectedServiceName()));
    return true;
}

bool SubscriptionUiController::updateServiceFromGateway(const QString &serverId, const QString &newCountryCode, const QString &newCountryName,
                                                    bool reloadServiceConfig, const QString &serviceProtocolOverride,
                                                    const QString &newCityName)
{
    bool isConnectEvent = newCountryCode.isEmpty() && newCountryName.isEmpty() && !reloadServiceConfig;
    bool wasSubscriptionExpired = false;
    if (const auto oldApiV2 = m_serversController->apiV2Config(serverId)) {
        wasSubscriptionExpired = oldApiV2->apiConfig.subscriptionExpiredByServer
                || oldApiV2->apiConfig.isSubscriptionExpired();
    }

    ErrorCode errorCode = m_subscriptionController->updateServiceFromGateway(serverId, newCountryCode, isConnectEvent,
                                                                            newCityName, serviceProtocolOverride, false, newCountryName);

    if (errorCode == ErrorCode::NoError) {
        refreshApiCountryModelFromServer(serverId);
        m_serversController->setDefaultServer(serverId);
        if (wasSubscriptionExpired) {
            emit subscriptionRefreshNeeded();
        }
        if (reloadServiceConfig) {
            emit reloadServerFromApiFinished(tr("API config reloaded"));
        } else if (newCountryName.isEmpty()) {
            emit updateServerFromApiFinished();
        } else {
            const QString locationName = newCityName.isEmpty() ? newCountryName : QStringLiteral("%1 / %2").arg(newCountryName, newCityName);
            emit changeApiCountryFinished(tr("Successfully changed the country of connection to %1").arg(locationName));
        }
        return true;
    } else {
        if (errorCode == ErrorCode::ApiSubscriptionExpiredError) {
            emit subscriptionExpiredOnServer();
        } else {
            emit errorOccurred(errorCode);
        }
        return false;
    }
}

bool SubscriptionUiController::resetServiceClientIdentity(const QString &serverId)
{
    QString serverMessage;
    ErrorCode errorCode = m_subscriptionController->resetServiceClientIdentity(serverId, &serverMessage);

    if (errorCode == ErrorCode::NoError) {
        refreshApiCountryModelFromServer(serverId);
        m_serversController->setDefaultServer(serverId);
        emit reloadServerFromApiFinished(tr("Reset successfully."));
        return true;
    }

    if (errorCode == ErrorCode::ApiSubscriptionExpiredError) {
        emit subscriptionExpiredOnServer();
    } else if (errorCode == ErrorCode::ApiUpdateRequestError) {
        const QString message = serverMessage.isEmpty()
                ? tr("Reset request failed")
                : tr("Reset request failed: %1").arg(serverMessage);
        emit resetServiceClientIdentityFailed(message);
    } else {
        emit errorOccurred(errorCode);
    }
    return false;
}


bool SubscriptionUiController::deactivateDevice(const QString &serverId)
{
    ErrorCode errorCode = m_subscriptionController->deactivateDevice(serverId);
    if (errorCode != ErrorCode::NoError) {
        emit errorOccurred(errorCode);
        return false;
    }

    return true;
}


bool SubscriptionUiController::deactivateExternalDevice(const QString &serverId, const QString &uuid, const QString &serverCountryCode)
{
    ErrorCode errorCode = m_subscriptionController->deactivateExternalDevice(serverId, uuid, serverCountryCode);
    if (errorCode != ErrorCode::NoError) {
        emit errorOccurred(errorCode);
        return false;
    }

    return true;
}


void SubscriptionUiController::validateConfig(const QString &serverId)
{
    if (serverId.isEmpty()) {
        emit configValidated(serverId, false);
        return;
    }

    ErrorCode errorCode = ErrorCode::NoError;
    const auto apiV2 = m_serversController->apiV2Config(serverId);
    const QString serviceProtocol = apiV2.has_value()
            ? apiV2->serviceProtocol().trimmed().toLower()
            : QString();
    const bool isWireGuardConnection = serviceProtocol == QStringLiteral("awg")
            || serviceProtocol == QStringLiteral("wireguard");

    if (isWireGuardConnection) {
        bool reuseExistingConfig = false;
        errorCode = m_subscriptionController->prepareWireGuardPeerConnection(serverId,
                                                                              reuseExistingConfig);
        if (errorCode == ErrorCode::NoError && !reuseExistingConfig) {
            errorCode = m_subscriptionController->refreshWireGuardConfigForConnection(serverId);
        }
    } else {
        const bool hasInstalledContainers = m_serversController->hasInstalledContainers(serverId);
        errorCode = m_subscriptionController->validateAndUpdateConfig(serverId, hasInstalledContainers);
    }

    if (errorCode != ErrorCode::NoError) {
        if (errorCode == ErrorCode::ApiSubscriptionExpiredError) {
            emit subscriptionExpiredOnServer();
        } else {
            emit errorOccurred(errorCode);
        }
        emit configValidated(serverId, false);
        return;
    }
    refreshApiCountryModelFromServer(serverId);
    emit configValidated(serverId, true);
}

void SubscriptionUiController::notifyWireGuardPeerDisconnected(const QString &serverId)
{
    const auto apiV2 = m_serversController->apiV2Config(serverId);
    const QString serviceProtocol = apiV2.has_value()
            ? apiV2->serviceProtocol().trimmed().toLower()
            : QString();
    qInfo() << "SubscriptionUiController::notifyWireGuardPeerDisconnected"
            << "serverId=" << serverId
            << "serviceProtocol=" << serviceProtocol;
    if (serviceProtocol != QStringLiteral("wireguard")
            && serviceProtocol != QStringLiteral("awg")) {
        qInfo() << "SubscriptionUiController::notifyWireGuardPeerDisconnected: skipped for non-WireGuard protocol"
                << "serverId=" << serverId;
        return;
    }

    const ErrorCode errorCode = m_subscriptionController->notifyWireGuardPeerDisconnected(serverId);
    if (errorCode != ErrorCode::NoError) {
        // Local disconnect is authoritative. A failed cleanup notification must
        // not restore or otherwise change the client's disconnected state.
        qWarning() << "SubscriptionUiController::notifyWireGuardPeerDisconnected: failed"
                   << "serverId=" << serverId
                   << "errorCode=" << static_cast<int>(errorCode);
    }
}

void SubscriptionUiController::setCurrentProtocol(const QString &serverId, const QString &protocolName)
{
    m_subscriptionController->setCurrentProtocol(serverId, protocolName);
}


bool SubscriptionUiController::isVlessProtocol(const QString &serverId)
{
    return m_subscriptionController->isVlessProtocol(serverId);
}


void SubscriptionUiController::removeApiConfig(const QString &serverId)
{
    m_subscriptionController->removeApiConfig(serverId);
    emit apiConfigRemoved(tr("Api config removed"));
}

void SubscriptionUiController::removeServer(const QString &serverId)
{
    const QString serverName = m_serversController->notificationDisplayName(serverId);
    if (!m_subscriptionController->removeServer(serverId)) {
        return;
    }
    emit apiServerRemoved(tr("Server '%1' was removed").arg(serverName));
}


QList<QString> SubscriptionUiController::getQrCodes()
{
    return m_qrCodes;
}

int SubscriptionUiController::getQrCodesCount()
{
    return static_cast<int>(m_qrCodes.size());
}

QString SubscriptionUiController::getVpnKey()
{
    return m_vpnKey;
}

QString SubscriptionUiController::loginAccountSubscriptionState() const
{
    return m_loginAccountSubscriptionState;
}

void SubscriptionUiController::setLoginAccountSubscriptionState(const QString &state)
{
    if (m_loginAccountSubscriptionState == state) {
        return;
    }
    m_loginAccountSubscriptionState = state;
    emit loginAccountSubscriptionStateChanged();
}

bool SubscriptionUiController::getAccountInfo(const QString &serverId, bool reload)
{
    if (reload) {
        QEventLoop wait;
        QTimer::singleShot(1000, &wait, &QEventLoop::quit);
        wait.exec(QEventLoop::ExcludeUserInputEvents);
    }
    QJsonObject accountInfo;
    ErrorCode errorCode = m_subscriptionController->getAccountInfo(serverId, accountInfo);
    if (errorCode != ErrorCode::NoError) {
        emit errorOccurred(errorCode);
        return false;
    }

    const auto apiV2 = m_serversController->apiV2Config(serverId);
    if (!apiV2.has_value()) {
        emit errorOccurred(ErrorCode::InternalError);
        return false;
    }
    m_apiAccountInfoModel->updateModel(accountInfo, apiV2->toJson());
    updateApiCountryModel();

    if (reload) {
        updateApiDevicesModel();
    }

    return true;
}

void SubscriptionUiController::handleAccountLookupFinished(
    ErrorCode errorCode,
    const SubscriptionController::AccountLookupResult &result)
{
    if (errorCode != ErrorCode::NoError) {
        setLoginAccountSubscriptionState(QStringLiteral("unknown"));
        emit errorOccurred(errorCode);
        return;
    }

    if (!result.accountInfo.isEmpty()) {
        QString currentCountryCode;
        QJsonObject serverConfig;
        if (!result.restoredServerId.isEmpty()) {
            const auto apiV2 = m_serversController->apiV2Config(result.restoredServerId);
            if (apiV2.has_value()) {
                currentCountryCode = apiV2->apiConfig.serverCountryCode;
                serverConfig = apiV2->toJson();
            }
        }
        m_apiAccountInfoModel->updateModel(result.accountInfo, serverConfig);
        m_apiCountryModel->updateModel(
            result.accountInfo.value(apiDefs::key::availableCountries).toArray(),
            currentCountryCode);
        m_apiCountryModel->updateIssuedConfigsInfo(
            result.accountInfo.value(apiDefs::key::issuedConfigs).toArray());
        updateApiDevicesModel();
    }

    switch (result.state) {
    case SubscriptionController::AccountSubscriptionState::NoSubscription:
        setLoginAccountSubscriptionState(QStringLiteral("none"));
        return;
    case SubscriptionController::AccountSubscriptionState::Expired:
        setLoginAccountSubscriptionState(QStringLiteral("expired"));
        return;
    case SubscriptionController::AccountSubscriptionState::Active:
        setLoginAccountSubscriptionState(QStringLiteral("active"));
        break;
    }

    if (result.restoredServerId.isEmpty()) {
        emit errorOccurred(ErrorCode::ApiConfigEmptyError);
        return;
    }

    int preferredServerIndex = -1;
    for (int index = 0; index < m_serversController->getServersCount(); ++index) {
        if (m_serversController->getServerId(index) == result.restoredServerId) {
            preferredServerIndex = index;
            break;
        }
    }
    emit installServerFromApiFinished(QString(), preferredServerIndex);
}

bool SubscriptionUiController::getAccountInfoByEmail(const QString &email)
{
    // SubscriptionController uses the application-wide QNetworkAccessManager
    // and the server repositories. Keep the complete lookup/restore operation
    // on their owning (UI) thread instead of invoking them from QtConcurrent.
    QTimer::singleShot(0, this, [this, email]() {
        SubscriptionController::AccountLookupResult result;
        const ErrorCode errorCode =
            m_subscriptionController->getAccountInfoByEmail(email, result);
        handleAccountLookupFinished(errorCode, result);
    });
    return true;
}

void SubscriptionUiController::updateApiCountryModel()
{
    m_apiCountryModel->updateModel(m_apiAccountInfoModel->getAvailableCountries(), "");
    m_apiCountryModel->updateIssuedConfigsInfo(m_apiAccountInfoModel->getIssuedConfigsInfo());
}

void SubscriptionUiController::refreshApiCountryModelFromServer(const QString &serverId)
{
    const auto apiV2 = m_serversController->apiV2Config(serverId);
    if (!apiV2.has_value()) {
        return;
    }

    m_apiCountryModel->updateModel(apiV2->apiConfig.availableCountries,
                                   apiV2->apiConfig.serverCountryCode);
}

void SubscriptionUiController::updateApiDevicesModel()
{
    m_apiDevicesModel->updateModel(m_apiAccountInfoModel->getIssuedConfigsInfo(), m_settingsController->getInstallationUuid(false));
}

void SubscriptionUiController::getRenewalLink(const QString &serverId)
{
    if (serverId.isEmpty()) {
        emit errorOccurred(ErrorCode::InternalError);
        return;
    }

    auto *watcher = new QFutureWatcher<QPair<ErrorCode, QString>>(this);
    connect(watcher, &QFutureWatcher<QPair<ErrorCode, QString>>::finished, this, [this, watcher]() {
        const auto [errorCode, url] = watcher->result();
        watcher->deleteLater();
        if (errorCode != ErrorCode::NoError) {
            emit errorOccurred(errorCode);
            return;
        }
        if (url.isEmpty()) {
            return;
        }
        emit renewalLinkReceived(url);
    });
    watcher->setFuture(m_subscriptionController->getRenewalLink(serverId));
}

