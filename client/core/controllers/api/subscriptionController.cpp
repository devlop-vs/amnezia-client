#include "subscriptionController.h"

#include <QDebug>
#include <QDateTime>
#include <QEventLoop>
#include <QFutureWatcher>
#include <QCryptographicHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPromise>
#include <QSet>
#include <QSysInfo>
#include <QUuid>
#include <QVariantMap>

#include "core/configurators/openVpnConfigurator.h"
#include "core/configurators/wireguardConfigurator.h"
#include "core/utils/containerEnum.h"
#include "core/utils/containers/containerUtils.h"
#include "core/utils/protocolEnum.h"
#include "core/utils/serverConfigUtils.h"
#include "core/utils/constants/apiKeys.h"
#include "core/utils/constants/apiConstants.h"
#include "core/utils/api/apiUtils.h"
#include "core/controllers/gatewayController.h"
#include "core/utils/protocolEnum.h"
#include "core/protocols/protocolUtils.h"
#include "core/utils/constants/configKeys.h"
#include "core/utils/constants/protocolConstants.h"
#include "version.h"
#include "core/models/containerConfig.h"
#include "core/models/api/apiConfig.h"

#if defined(Q_OS_IOS) || defined(MACOS_NE)
    #include "platforms/ios/ios_controller.h"
    #include <AmneziaVPN-Swift.h>
#endif

#ifdef Q_OS_ANDROID
    #include "platforms/android/android_controller.h"
#endif

using namespace amnezia;

namespace
{
constexpr int googlePlaySubscriptionRequestTimeoutMsecs = 60 * 1000;
constexpr int configRequestTimeoutMsecs = 30 * 1000;

QString getSubscriptionStatusForRenewal(const ApiConfig &apiConfig)
{
    if (apiConfig.subscriptionExpiredByServer) {
        return QStringLiteral("expired");
    }

    if (!apiConfig.subscription.endDate.isEmpty()) {
        if (apiUtils::isSubscriptionExpired(apiConfig.subscription.endDate)) {
            return QStringLiteral("expired");
        }
        if (apiUtils::isSubscriptionExpiringSoon(apiConfig.subscription.endDate)) {
            return QStringLiteral("expire_soon");
        }
    }

    return QStringLiteral("active");
}

bool isWireGuardKeyExchangeProtocol(const QString &protocol)
{
    return protocol == configKey::awg || protocol == configKey::wireguard;
}

bool hasReusableProtocolIdentity(const QString &protocol, const SubscriptionController::ProtocolData &protocolData)
{
    if (isWireGuardKeyExchangeProtocol(protocol)) {
        return !protocolData.wireGuardClientPubKey.isEmpty() && !protocolData.wireGuardClientPrivKey.isEmpty();
    }
    if (protocol == configKey::vless) {
        return !protocolData.xrayUuid.isEmpty();
    }

    return true;
}

SubscriptionController::ProtocolData storedProtocolIdentity(const ApiV2ServerConfig &apiV2, const QString &protocol);

DockerContainer defaultContainerForServiceProtocol(const ApiV2ServerConfig &apiV2, const QString &protocol)
{
    const QString normalizedProtocol = protocol.trimmed().toLower();

    if (normalizedProtocol == configKey::vless && apiV2.containers.contains(DockerContainer::Xray)) {
        return DockerContainer::Xray;
    }
    if (normalizedProtocol == configKey::openvpn && apiV2.containers.contains(DockerContainer::OpenVpn)) {
        return DockerContainer::OpenVpn;
    }
    if (normalizedProtocol == configKey::wireguard && apiV2.containers.contains(DockerContainer::WireGuard)) {
        return DockerContainer::WireGuard;
    }
    if (normalizedProtocol == configKey::awg) {
        if (apiV2.containers.contains(DockerContainer::Awg2)) {
            return DockerContainer::Awg2;
        }
        if (apiV2.containers.contains(DockerContainer::Awg)) {
            return DockerContainer::Awg;
        }
    }

    return DockerContainer::None;
}

void alignDefaultContainerWithServiceProtocol(ApiV2ServerConfig &apiV2, const QString &protocol)
{
    const DockerContainer protocolContainer = defaultContainerForServiceProtocol(apiV2, protocol);
    if (protocolContainer != DockerContainer::None) {
        apiV2.defaultContainer = protocolContainer;
        return;
    }

    if (apiV2.defaultContainer != DockerContainer::None && apiV2.containers.contains(apiV2.defaultContainer)) {
        return;
    }

    for (auto it = apiV2.containers.constBegin(); it != apiV2.containers.constEnd(); ++it) {
        const DockerContainer container = it.key();
        if (ContainerUtils::containerService(container) == ServiceType::Vpn || container == DockerContainer::SSXray) {
            apiV2.defaultContainer = container;
            return;
        }
    }
}

bool protocolIdentitiesMatch(const QString &protocol, const SubscriptionController::ProtocolData &left,
                             const SubscriptionController::ProtocolData &right)
{
    if (isWireGuardKeyExchangeProtocol(protocol)) {
        return left.wireGuardClientPrivKey == right.wireGuardClientPrivKey
                && left.wireGuardClientPubKey == right.wireGuardClientPubKey
                && left.wireGuardClientId == right.wireGuardClientId;
    }
    if (protocol == configKey::vless) {
        return left.xrayUuid == right.xrayUuid;
    }

    return true;
}

SubscriptionController::ProtocolData protocolIdentityFromApiConfig(const ApiConfig &apiConfig, const QString &protocol)
{
    SubscriptionController::ProtocolData protocolData;

    if (isWireGuardKeyExchangeProtocol(protocol)) {
        protocolData.wireGuardClientPrivKey = apiConfig.clientIdentity.wireGuardClientPrivKey;
        protocolData.wireGuardClientPubKey = apiConfig.clientIdentity.wireGuardClientPubKey;
        protocolData.wireGuardClientId = apiConfig.clientIdentity.wireGuardClientId.isEmpty()
                ? apiConfig.clientIdentity.wireGuardClientPubKey
                : apiConfig.clientIdentity.wireGuardClientId;
    } else if (protocol == configKey::vless) {
        protocolData.xrayUuid = apiConfig.clientIdentity.vlessUuid;
    }

    return protocolData;
}

void applyProtocolIdentityToApiConfig(ApiConfig &apiConfig, const QString &protocol,
                                      const SubscriptionController::ProtocolData &protocolData)
{
    if (isWireGuardKeyExchangeProtocol(protocol)) {
        if (!protocolData.wireGuardClientPrivKey.isEmpty()) {
            apiConfig.clientIdentity.wireGuardClientPrivKey = protocolData.wireGuardClientPrivKey;
        }
        if (!protocolData.wireGuardClientPubKey.isEmpty()) {
            apiConfig.clientIdentity.wireGuardClientPubKey = protocolData.wireGuardClientPubKey;
        }
        apiConfig.clientIdentity.wireGuardClientId = protocolData.wireGuardClientId.isEmpty()
                ? protocolData.wireGuardClientPubKey
                : protocolData.wireGuardClientId;
    } else if (protocol == configKey::vless && !protocolData.xrayUuid.isEmpty()) {
        apiConfig.clientIdentity.vlessUuid = protocolData.xrayUuid;
    }
}

SubscriptionController::ProtocolData reusableProtocolIdentity(const ApiV2ServerConfig &apiV2, const QString &protocol)
{
    const SubscriptionController::ProtocolData apiConfigIdentity = protocolIdentityFromApiConfig(apiV2.apiConfig, protocol);
    const SubscriptionController::ProtocolData storedIdentity = storedProtocolIdentity(apiV2, protocol);

    const bool hasApiConfigIdentity = hasReusableProtocolIdentity(protocol, apiConfigIdentity);
    const bool hasStoredIdentity = hasReusableProtocolIdentity(protocol, storedIdentity);

    if (hasApiConfigIdentity && hasStoredIdentity && !protocolIdentitiesMatch(protocol, apiConfigIdentity, storedIdentity)) {
        qWarning().noquote() << "[API] Local protocol identity mismatch detected before /v1/config request;"
                             << "using persisted client identity from api_config";
    }

    if (hasApiConfigIdentity) {
        return apiConfigIdentity;
    }

    if (hasStoredIdentity) {
        return storedIdentity;
    }

    return SubscriptionController::ProtocolData{};
}

SubscriptionController::ProtocolData storedProtocolIdentity(const ApiV2ServerConfig &apiV2, const QString &protocol)
{
    SubscriptionController::ProtocolData protocolData;

    for (auto it = apiV2.containers.constBegin(); it != apiV2.containers.constEnd(); ++it) {
        const ContainerConfig &containerConfig = it.value();

        if (isWireGuardKeyExchangeProtocol(protocol)) {
            const auto *awgConfig = containerConfig.getAwgProtocolConfig();
            if (awgConfig && awgConfig->clientConfig.has_value()) {
                protocolData.wireGuardClientPrivKey = awgConfig->clientConfig->clientPrivateKey;
                protocolData.wireGuardClientPubKey = awgConfig->clientConfig->clientPublicKey;
                protocolData.wireGuardClientId = awgConfig->clientConfig->clientId.isEmpty()
                        ? protocolData.wireGuardClientPubKey
                        : awgConfig->clientConfig->clientId;
                if (hasReusableProtocolIdentity(protocol, protocolData)) {
                    return protocolData;
                }
            }

            const auto *wireGuardConfig = containerConfig.getWireGuardProtocolConfig();
            if (wireGuardConfig && wireGuardConfig->clientConfig.has_value()) {
                protocolData.wireGuardClientPrivKey = wireGuardConfig->clientConfig->clientPrivateKey;
                protocolData.wireGuardClientPubKey = wireGuardConfig->clientConfig->clientPublicKey;
                protocolData.wireGuardClientId = wireGuardConfig->clientConfig->clientId.isEmpty()
                        ? protocolData.wireGuardClientPubKey
                        : wireGuardConfig->clientConfig->clientId;
                if (hasReusableProtocolIdentity(protocol, protocolData)) {
                    return protocolData;
                }
            }
        } else if (protocol == configKey::vless) {
            const auto *xrayConfig = containerConfig.getXrayProtocolConfig();
            if (xrayConfig && xrayConfig->clientConfig.has_value()) {
                protocolData.xrayUuid = xrayConfig->clientConfig->id;
                if (hasReusableProtocolIdentity(protocol, protocolData)) {
                    return protocolData;
                }
            }
        }
    }

    return protocolData;
}

QJsonObject withWireGuardIdentity(QJsonObject protocolConfig, const SubscriptionController::ProtocolData &protocolData)
{
    if (protocolData.wireGuardClientPrivKey.isEmpty() || protocolData.wireGuardClientPubKey.isEmpty()) {
        return protocolConfig;
    }

    QJsonObject clientConfig = QJsonDocument::fromJson(protocolConfig.value(configKey::lastConfig).toString().toUtf8()).object();
    clientConfig[configKey::clientPrivKey] = protocolData.wireGuardClientPrivKey;
    clientConfig[configKey::clientPubKey] = protocolData.wireGuardClientPubKey;
    clientConfig[configKey::clientId] = protocolData.wireGuardClientId.isEmpty()
            ? protocolData.wireGuardClientPubKey
            : protocolData.wireGuardClientId;
    protocolConfig[configKey::lastConfig] = QString::fromUtf8(QJsonDocument(clientConfig).toJson(QJsonDocument::Compact));

    return protocolConfig;
}

bool isVlessIdentityPlaceholder(const QString &id)
{
    const QString trimmedId = id.trimmed();
    return trimmedId.isEmpty()
            || trimmedId == QLatin1String("$XRAY_CLIENT_ID")
            || trimmedId == QLatin1String("$VLESS_CLIENT_ID")
            || trimmedId == QLatin1String("$VLESS_UUID")
            || trimmedId == QLatin1String("$CLIENT_ID");
}

QJsonObject withVlessIdentityInNativeConfig(QJsonObject nativeConfig, const QString &xrayUuid)
{
    QJsonArray outbounds = nativeConfig.value(protocols::xray::outbounds).toArray();
    if (outbounds.isEmpty()) {
        return nativeConfig;
    }

    QJsonObject outbound = outbounds.at(0).toObject();
    QJsonObject settings = outbound.value(protocols::xray::settings).toObject();
    QJsonArray vnext = settings.value(protocols::xray::vnext).toArray();
    if (vnext.isEmpty()) {
        return nativeConfig;
    }

    QJsonObject vnextEntry = vnext.at(0).toObject();
    QJsonArray users = vnextEntry.value(protocols::xray::users).toArray();
    if (users.isEmpty()) {
        return nativeConfig;
    }

    QJsonObject user = users.at(0).toObject();
    if (!isVlessIdentityPlaceholder(user.value(protocols::xray::id).toString())) {
        return nativeConfig;
    }
    user[protocols::xray::id] = xrayUuid;
    users.replace(0, user);
    vnextEntry[protocols::xray::users] = users;
    vnext.replace(0, vnextEntry);
    settings[protocols::xray::vnext] = vnext;
    outbound[protocols::xray::settings] = settings;
    outbounds.replace(0, outbound);
    nativeConfig[protocols::xray::outbounds] = outbounds;

    return nativeConfig;
}

QJsonObject withVlessIdentity(QJsonObject protocolConfig, const SubscriptionController::ProtocolData &protocolData)
{
    if (protocolData.xrayUuid.isEmpty()) {
        return protocolConfig;
    }

    const QString lastConfig = protocolConfig.value(configKey::lastConfig).toString();
    QJsonObject clientConfig = QJsonDocument::fromJson(lastConfig.toUtf8()).object();
    if (clientConfig.contains(protocols::xray::outbounds) && !clientConfig.contains(configKey::config)) {
        clientConfig = withVlessIdentityInNativeConfig(clientConfig, protocolData.xrayUuid);
        protocolConfig[configKey::lastConfig] = QString::fromUtf8(QJsonDocument(clientConfig).toJson(QJsonDocument::Compact));
        return protocolConfig;
    }

    const QString nativeConfigString = clientConfig.value(configKey::config).toString();
    QJsonObject nativeConfig = QJsonDocument::fromJson(nativeConfigString.toUtf8()).object();
    if (nativeConfig.contains(protocols::xray::outbounds)) {
        nativeConfig = withVlessIdentityInNativeConfig(nativeConfig, protocolData.xrayUuid);
        clientConfig[configKey::config] = QString::fromUtf8(QJsonDocument(nativeConfig).toJson(QJsonDocument::Compact));
    }
    if (isVlessIdentityPlaceholder(clientConfig.value(configKey::clientId).toString())) {
        clientConfig[configKey::clientId] = protocolData.xrayUuid;
    }
    protocolConfig[configKey::lastConfig] = QString::fromUtf8(QJsonDocument(clientConfig).toJson(QJsonDocument::Compact));

    return protocolConfig;
}

void persistProtocolIdentity(QJsonObject &serverConfigJson, const QString &protocol, const SubscriptionController::ProtocolData &protocolData)
{
    if (!hasReusableProtocolIdentity(protocol, protocolData)) {
        return;
    }

    QJsonArray containers = serverConfigJson.value(configKey::containers).toArray();
    for (int i = 0; i < containers.size(); ++i) {
        QJsonObject container = containers.at(i).toObject();
        bool updated = false;

        if (isWireGuardKeyExchangeProtocol(protocol)) {
            for (const QLatin1String protocolKey : { configKey::awg, configKey::wireguard }) {
                if (container.contains(protocolKey)) {
                    container[protocolKey] = withWireGuardIdentity(container.value(protocolKey).toObject(), protocolData);
                    updated = true;
                }
            }
        } else if (protocol == configKey::vless) {
            for (const QLatin1String protocolKey : { configKey::xray, configKey::ssxray }) {
                if (container.contains(protocolKey)) {
                    container[protocolKey] = withVlessIdentity(container.value(protocolKey).toObject(), protocolData);
                    updated = true;
                }
            }
        }

        if (updated) {
            containers.replace(i, container);
        }
    }
    serverConfigJson[configKey::containers] = containers;
}

QString findMatchingGooglePlayRenewalServerId(const SecureServersRepository *serversRepository,
                                             const QString &serviceType)
{
    const QString trimmedServiceType = serviceType.trimmed();

    const QString defaultServerId = serversRepository->defaultServerId();
    if (!defaultServerId.isEmpty()) {
        const auto defaultApiV2 = serversRepository->apiV2Config(defaultServerId);
        if (defaultApiV2.has_value()
                && defaultApiV2->apiConfig.isInAppPurchase
                && (trimmedServiceType.isEmpty() || defaultApiV2->serviceType() == trimmedServiceType)) {
            return defaultServerId;
        }
    }

    for (int i = 0; i < serversRepository->serversCount(); ++i) {
        const QString existingServerId = serversRepository->serverIdAt(i);
        if (existingServerId == defaultServerId) {
            continue;
        }
        const auto existingApiV2 = serversRepository->apiV2Config(existingServerId);
        if (!existingApiV2.has_value()) {
            continue;
        }

        if (!trimmedServiceType.isEmpty() && existingApiV2->serviceType() != trimmedServiceType) {
            continue;
        }
        if (!existingApiV2->apiConfig.isInAppPurchase) {
            continue;
        }

        return existingServerId;
    }

    return QString();
}

void refreshWireGuardIdentityInExistingServerConfigs(SecureServersRepository *serversRepository,
                                                     const QString &serviceType,
                                                     const SubscriptionController::ProtocolData &protocolData)
{
    if (!hasReusableProtocolIdentity(configKey::wireguard, protocolData)) {
        return;
    }

    const QString trimmedServiceType = serviceType.trimmed();
    int updatedServersCount = 0;
    for (int i = 0; i < serversRepository->serversCount(); ++i) {
        const QString serverId = serversRepository->serverIdAt(i);
        const auto apiV2 = serversRepository->apiV2Config(serverId);
        if (!apiV2.has_value()) {
            continue;
        }

        if (!trimmedServiceType.isEmpty() && apiV2->serviceType() != trimmedServiceType) {
            continue;
        }

        ApiV2ServerConfig syncedApiV2 = *apiV2;
        applyProtocolIdentityToApiConfig(syncedApiV2.apiConfig, configKey::wireguard, protocolData);

        QJsonObject syncedConfig = syncedApiV2.toJson();
        persistProtocolIdentity(syncedConfig, configKey::wireguard, protocolData);
        serversRepository->editServer(serverId, syncedConfig, serverConfigUtils::configTypeFromJson(syncedConfig));
        ++updatedServersCount;
    }

    qInfo().noquote() << "[GPAY] Refreshed WireGuard/AWG identity in existing server configs;"
                      << "updatedServersCount =" << updatedServersCount
                      << "publicKey =" << protocolData.wireGuardClientPubKey;
}
}


SubscriptionController::SubscriptionController(SecureServersRepository* serversRepository,
                                               SecureAppSettingsRepository* appSettingsRepository)
    : m_serversRepository(serversRepository), m_appSettingsRepository(appSettingsRepository)
{
}

QJsonObject SubscriptionController::GatewayRequestData::toJsonObject() const
{
    QJsonObject obj;
    if (!osVersion.isEmpty()) {
        obj[apiDefs::key::osVersion] = osVersion;
    }
    if (!appVersion.isEmpty()) {
        obj[apiDefs::key::appVersion] = appVersion;
    }
    if (!appLanguage.isEmpty()) {
        obj[apiDefs::key::appLanguage] = appLanguage;
    }
    if (!installationUuid.isEmpty()) {
        obj[apiDefs::key::uuid] = installationUuid;
    }
    if (!userCountryCode.isEmpty()) {
        obj[apiDefs::key::userCountryCode] = userCountryCode;
    }
    if (!serverCountryCode.isEmpty()) {
        obj[apiDefs::key::serverCountryCode] = serverCountryCode;
    }
    if (!serverCityName.isEmpty()) {
        obj[apiDefs::key::serverCityName] = serverCityName;
    }
    if (!serviceType.isEmpty()) {
        obj[apiDefs::key::serviceType] = serviceType;
    }
    if (!serviceProtocol.isEmpty()) {
        obj[apiDefs::key::serviceProtocol] = serviceProtocol;
    }
    if (!authData.isEmpty()) {
        obj[apiDefs::key::authData] = authData;
    }
    return obj;
}

QJsonObject SubscriptionController::authDataWithUserEmail(QJsonObject authData) const
{
    const QString email = m_appSettingsRepository->getAuthUserEmail();
    if (!email.isEmpty()) {
        authData[apiDefs::key::email] = email;
    }
    return authData;
}

SubscriptionController::ProtocolData SubscriptionController::generateProtocolData(const QString &protocol)
{
    ProtocolData protocolData;
    if (isWireGuardKeyExchangeProtocol(protocol)) {
        auto connData = WireguardConfigurator::genClientKeys();
        protocolData.wireGuardClientPubKey = connData.clientPubKey;
        protocolData.wireGuardClientPrivKey = connData.clientPrivKey;
        protocolData.wireGuardClientId = connData.clientPubKey;
    } else if (protocol == configKey::vless) {
        protocolData.xrayUuid = QUuid::createUuid().toString(QUuid::WithoutBraces);
    }

    return protocolData;
}

void SubscriptionController::appendProtocolDataToApiPayload(const QString &protocol, const ProtocolData &protocolData, QJsonObject &apiPayload) const
{
    if (isWireGuardKeyExchangeProtocol(protocol)) {
        apiPayload[apiDefs::key::publicKey] = protocolData.wireGuardClientPubKey;
    } else if (protocol == configKey::vless) {
        apiPayload[apiDefs::key::publicKey] = protocolData.xrayUuid;
    }
}

QString SubscriptionController::makeGooglePlayObfuscatedAccountId(const QString &userId) const
{
    const QString normalizedUserId = userId.trimmed();
    if (normalizedUserId.isEmpty()) {
        return QString();
    }

    const QByteArray seed = QStringLiteral("redavpn:user:%1").arg(normalizedUserId).toUtf8();
    return QString::fromLatin1(QCryptographicHash::hash(seed, QCryptographicHash::Sha256).toHex());
}

ErrorCode SubscriptionController::extractServerConfigJsonFromResponse(const QByteArray &apiResponseBody, const QString &protocol, 
                                                                        const ProtocolData &protocolData, QJsonObject &serverConfigJson)
{
    const QJsonObject responseObject = QJsonDocument::fromJson(apiResponseBody).object();

    // The gateway can return configs in two formats:
    // 1. Legacy/wrapped format: { "config": "vpn://<base64...>" }
    // 2. Direct API v2 format: { "config_version": 2, "containers": [...], "api_config": {...} }
    // Treating the direct format as a wrapped response makes `config` empty and
    // incorrectly raises ApiConfigEmptyError (1102), even though the server sent
    // a valid Xray/VLESS config.
    if (responseObject.contains(configKey::configVersion)
            && responseObject.contains(configKey::containers)) {
        serverConfigJson = responseObject;
        persistProtocolIdentity(serverConfigJson, protocol, protocolData);
        return ErrorCode::NoError;
    }

    QString data = responseObject.value(configKey::config).toString();

    data.replace("vpn://", "");
    QByteArray ba = QByteArray::fromBase64(data.toUtf8(), QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals);

    if (ba.isEmpty()) {
        qDebug() << "empty vpn key"
                 << "responseKeys=" << responseObject.keys()
                 << "configValueLength=" << data.length();
        return ErrorCode::ApiConfigEmptyError;
    }

    QByteArray ba_uncompressed = qUncompress(ba);
    if (!ba_uncompressed.isEmpty()) {
        ba = ba_uncompressed;
    }

    QString configStr = ba;
    if (isWireGuardKeyExchangeProtocol(protocol)) {
        configStr.replace("$WIREGUARD_CLIENT_PRIVATE_KEY", protocolData.wireGuardClientPrivKey);
    }
    if (protocol == configKey::awg) {
        auto newServerConfig = QJsonDocument::fromJson(configStr.toUtf8()).object();
        auto containers = newServerConfig.value(configKey::containers).toArray();
        if (containers.isEmpty()) {
            qDebug() << "missing containers field";
            return ErrorCode::ApiConfigEmptyError;
        }
        auto container = containers.at(0).toObject();
        QString containerName = ContainerUtils::containerTypeToString(DockerContainer::Awg);
        auto serverProtocolConfig = container.value(containerName).toObject();
        auto clientProtocolConfig =
                QJsonDocument::fromJson(serverProtocolConfig.value(configKey::lastConfig).toString().toUtf8()).object();

        // TODO looks like this block can be removed after v1 configs EOL

        serverProtocolConfig[configKey::junkPacketCount] = clientProtocolConfig.value(configKey::junkPacketCount);
        serverProtocolConfig[configKey::junkPacketMinSize] = clientProtocolConfig.value(configKey::junkPacketMinSize);
        serverProtocolConfig[configKey::junkPacketMaxSize] = clientProtocolConfig.value(configKey::junkPacketMaxSize);
        serverProtocolConfig[configKey::initPacketJunkSize] = clientProtocolConfig.value(configKey::initPacketJunkSize);
        serverProtocolConfig[configKey::responsePacketJunkSize] = clientProtocolConfig.value(configKey::responsePacketJunkSize);
        serverProtocolConfig[configKey::initPacketMagicHeader] = clientProtocolConfig.value(configKey::initPacketMagicHeader);
        serverProtocolConfig[configKey::responsePacketMagicHeader] = clientProtocolConfig.value(configKey::responsePacketMagicHeader);
        serverProtocolConfig[configKey::underloadPacketMagicHeader] = clientProtocolConfig.value(configKey::underloadPacketMagicHeader);
        serverProtocolConfig[configKey::transportPacketMagicHeader] = clientProtocolConfig.value(configKey::transportPacketMagicHeader);

        serverProtocolConfig[configKey::cookieReplyPacketJunkSize] = clientProtocolConfig.value(configKey::cookieReplyPacketJunkSize);
        serverProtocolConfig[configKey::transportPacketJunkSize] = clientProtocolConfig.value(configKey::transportPacketJunkSize);
        serverProtocolConfig[configKey::specialJunk1] = clientProtocolConfig.value(configKey::specialJunk1);
        serverProtocolConfig[configKey::specialJunk2] = clientProtocolConfig.value(configKey::specialJunk2);
        serverProtocolConfig[configKey::specialJunk3] = clientProtocolConfig.value(configKey::specialJunk3);
        serverProtocolConfig[configKey::specialJunk4] = clientProtocolConfig.value(configKey::specialJunk4);
        serverProtocolConfig[configKey::specialJunk5] = clientProtocolConfig.value(configKey::specialJunk5);

        //

        container[containerName] = serverProtocolConfig;
        containers.replace(0, container);
        newServerConfig[configKey::containers] = containers;
        configStr = QString(QJsonDocument(newServerConfig).toJson());
    }

    serverConfigJson = QJsonDocument::fromJson(configStr.toUtf8()).object();
    persistProtocolIdentity(serverConfigJson, protocol, protocolData);
    return ErrorCode::NoError;
}

void SubscriptionController::updateApiConfigInJson(QJsonObject &serverConfigJson, const QString &serviceType,
                                                    const QString &serviceProtocol, const QString &userCountryCode,
                                                    const QByteArray &apiResponseBody,
                                                    const QString &serverCountryCode,
                                                    const QString &serverCountryName)
{
    QJsonObject apiConfig = serverConfigJson.value(apiDefs::key::apiConfig).toObject();
    
    apiConfig[apiDefs::key::serviceType] = serviceType;
    apiConfig[apiDefs::key::serviceProtocol] = serviceProtocol;
    apiConfig[apiDefs::key::userCountryCode] = userCountryCode;
    if (!serverCountryCode.isEmpty()) {
        apiConfig[apiDefs::key::serverCountryCode] = serverCountryCode;
    }
    if (!serverCountryName.isEmpty()) {
        apiConfig[apiDefs::key::serverCountryName] = serverCountryName;
    }
    
    if (serverConfigJson.value(configKey::configVersion).toInt() == serverConfigUtils::ConfigSource::AmneziaGateway) {
        QJsonObject responseObj = QJsonDocument::fromJson(apiResponseBody).object();
        if (responseObj.contains(apiDefs::key::supportedProtocols)) {
            apiConfig.insert(apiDefs::key::supportedProtocols, responseObj.value(apiDefs::key::supportedProtocols).toArray());
        }
        if (responseObj.contains(apiDefs::key::serviceInfo)) {
            apiConfig.insert(apiDefs::key::serviceInfo, responseObj.value(apiDefs::key::serviceInfo).toObject());
        }
    }
    
    serverConfigJson[apiDefs::key::apiConfig] = apiConfig;
}

ErrorCode SubscriptionController::executeRequest(const QString &endpoint, const QJsonObject &apiPayload, QByteArray &responseBody,
                                                 bool isTestPurchase, int timeoutMsecs)
{
    GatewayController gatewayController(m_appSettingsRepository->getGatewayEndpoint(isTestPurchase), m_appSettingsRepository->isDevGatewayEnv(isTestPurchase),
                                        timeoutMsecs > 0 ? timeoutMsecs : apiDefs::requestTimeoutMsecs,
                                        m_appSettingsRepository->isStrictKillSwitchEnabled(), m_appSettingsRepository);
    return gatewayController.post(endpoint, apiPayload, responseBody);
}

ErrorCode SubscriptionController::importServiceFromGateway(const QString &userCountryCode, const QString &serviceType,
                                                            const QString &serviceProtocol, const ProtocolData &protocolData,
                                                            CaptchaInfo &captchaInfo)
{
    GatewayRequestData gatewayRequestData { QSysInfo::productType(),
                                            QString(APP_VERSION),
                                            m_appSettingsRepository->getAppLanguage().name().split("_").first(),
                                            m_appSettingsRepository->getInstallationUuid(true),
                                            userCountryCode,
                                            "",
                                            "",
                                            serviceType,
                                            serviceProtocol,
                                            authDataWithUserEmail(QJsonObject()) };

    QJsonObject apiPayload = gatewayRequestData.toJsonObject();
    appendProtocolDataToApiPayload(serviceProtocol, protocolData, apiPayload);

    QByteArray responseBody;
    ErrorCode errorCode = executeRequest(QString("%1v1/config"), apiPayload, responseBody, false, configRequestTimeoutMsecs);

    if (errorCode == ErrorCode::ApiCaptchaRequiredError) {
        QJsonDocument jsonDoc = QJsonDocument::fromJson(responseBody);
        if (jsonDoc.isObject()) {
            QJsonObject jsonObj = jsonDoc.object();
            captchaInfo.captchaId = jsonObj.value("captcha_id").toString();
            captchaInfo.captchaImageBase64 = jsonObj.value("captcha_image").toString();
            captchaInfo.hint = jsonObj.value("hint").toString();
            captchaInfo.isRequired = true;
        }
        return errorCode;
    }

    if (errorCode != ErrorCode::NoError) {
        return errorCode;
    }

    QJsonObject serverConfigJson;
    errorCode = extractServerConfigJsonFromResponse(responseBody, serviceProtocol, protocolData, serverConfigJson);
    if (errorCode != ErrorCode::NoError) {
        return errorCode;
    }

    updateApiConfigInJson(serverConfigJson, serviceType, serviceProtocol, userCountryCode, responseBody);

    if (serverConfigJson.value(configKey::configVersion).toInt() != serverConfigUtils::ConfigSource::AmneziaGateway) {
        return ErrorCode::InternalError;
    }

    ApiV2ServerConfig apiV2ServerConfig = ApiV2ServerConfig::fromJson(serverConfigJson);
    alignDefaultContainerWithServiceProtocol(apiV2ServerConfig, serviceProtocol);
    applyProtocolIdentityToApiConfig(apiV2ServerConfig.apiConfig, serviceProtocol, protocolData);
    m_serversRepository->addServer(QString(), apiV2ServerConfig.toJson(),
                                   serverConfigUtils::configTypeFromJson(apiV2ServerConfig.toJson()));
    return ErrorCode::NoError;
}

ErrorCode SubscriptionController::importTrialFromGateway(const QString &userCountryCode, const QString &serviceType,
                                                         const QString &serviceProtocol, const QString &email)
{
    const QString trimmedEmail = email.trimmed();
    if (trimmedEmail.isEmpty()) {
        return ErrorCode::ApiConfigEmptyError;
    }

    GatewayRequestData gatewayRequestData { QSysInfo::productType(),
                                            QString(APP_VERSION),
                                            m_appSettingsRepository->getAppLanguage().name().split("_").first(),
                                            m_appSettingsRepository->getInstallationUuid(true),
                                            userCountryCode,
                                            "",
                                            "",
                                            serviceType,
                                            serviceProtocol,
                                            QJsonObject() };

    ProtocolData protocolData = generateProtocolData(serviceProtocol);
    QJsonObject apiPayload = gatewayRequestData.toJsonObject();
    appendProtocolDataToApiPayload(serviceProtocol, protocolData, apiPayload);
    apiPayload.insert(apiDefs::key::email, trimmedEmail);

    QByteArray responseBody;
    ErrorCode errorCode = executeRequest(QString("%1v1/trial"), apiPayload, responseBody);
    if (errorCode != ErrorCode::NoError) {
        return errorCode;
    }

    QJsonObject responseObject = QJsonDocument::fromJson(responseBody).object();
    QString key = responseObject.value(apiDefs::key::config).toString();
    if (key.isEmpty()) {
        return ErrorCode::ApiConfigEmptyError;
    }

    key.replace(QStringLiteral("vpn://"), QString());
    QByteArray configBytes = QByteArray::fromBase64(key.toUtf8(), QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals);
    QByteArray uncompressed = qUncompress(configBytes);
    if (!uncompressed.isEmpty()) {
        configBytes = uncompressed;
    }

    if (configBytes.isEmpty()) {
        return ErrorCode::ApiConfigEmptyError;
    }

    QJsonObject configObject = QJsonDocument::fromJson(configBytes).object();
    if (configObject.value(configKey::configVersion).toInt() != serverConfigUtils::ConfigSource::AmneziaGateway) {
        return ErrorCode::InternalError;
    }

    persistProtocolIdentity(configObject, serviceProtocol, protocolData);

    ApiV2ServerConfig apiV2ServerConfig = ApiV2ServerConfig::fromJson(configObject);
    applyProtocolIdentityToApiConfig(apiV2ServerConfig.apiConfig, serviceProtocol, protocolData);
    m_serversRepository->addServer(QString(), apiV2ServerConfig.toJson(),
                                   serverConfigUtils::configTypeFromJson(apiV2ServerConfig.toJson()));
    return ErrorCode::NoError;
}

ErrorCode SubscriptionController::importServiceFromAppStore(const QString &userCountryCode, const QString &serviceType,
                                                            const QString &serviceProtocol, const ProtocolData &protocolData,
                                                            const QString &transactionId, bool isTestPurchase,
                                                            int *duplicateServerIndex)
{
    GatewayRequestData gatewayRequestData { QSysInfo::productType(),
                                            QString(APP_VERSION),
                                            m_appSettingsRepository->getAppLanguage().name().split("_").first(),
                                            m_appSettingsRepository->getInstallationUuid(true),
                                            userCountryCode,
                                            "",
                                            "",
                                            serviceType,
                                            serviceProtocol,
                                            QJsonObject() };

    QJsonObject apiPayload = gatewayRequestData.toJsonObject();
    appendProtocolDataToApiPayload(serviceProtocol, protocolData, apiPayload);
    apiPayload[apiDefs::key::transactionId] = transactionId;

    QByteArray responseBody;
    ErrorCode errorCode = executeRequest(QString("%1v1/subscriptions"), apiPayload, responseBody, isTestPurchase);
    if (errorCode != ErrorCode::NoError) {
        return errorCode;
    }

    // Parse the subscription response
    QJsonObject responseObject = QJsonDocument::fromJson(responseBody).object();
    QString key = responseObject.value(QStringLiteral("key")).toString();
    if (key.isEmpty()) {
        qWarning().noquote() << "[IAP] Subscription response does not contain a key field";
        return ErrorCode::ApiPurchaseError;
    }

    QString normalizedKey = key;
    normalizedKey.replace(QStringLiteral("vpn://"), QString());

    // Check if server with this VPN key already exists
    for (int i = 0; i < m_serversRepository->serversCount(); ++i) {
        const auto apiV2 = m_serversRepository->apiV2Config(m_serversRepository->serverIdAt(i));
        QString existingVpnKey = apiV2.has_value() ? apiV2->vpnKey() : QString();
        existingVpnKey.replace(QStringLiteral("vpn://"), QString());
        if (!existingVpnKey.isEmpty() && existingVpnKey == normalizedKey) {
            if (duplicateServerIndex) {
                *duplicateServerIndex = i;
            }
            qInfo().noquote() << "[IAP] Subscription config with the same vpn_key already exists";
            return ErrorCode::ApiConfigAlreadyAdded;
        }
    }

    QByteArray configString = QByteArray::fromBase64(normalizedKey.toUtf8(), QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals);
    QByteArray configUncompressed = qUncompress(configString);
    if (!configUncompressed.isEmpty()) {
        configString = configUncompressed;
    }

    if (configString.isEmpty()) {
        qWarning().noquote() << "[IAP] Subscription response config payload is empty";
        return ErrorCode::ApiPurchaseError;
    }

    QJsonObject configObject = QJsonDocument::fromJson(configString).object();

    quint16 crc = qChecksum(QJsonDocument(configObject).toJson());
    
    if (configObject.value(configKey::configVersion).toInt() != serverConfigUtils::ConfigSource::AmneziaGateway) {
        return ErrorCode::InternalError;
    }

    persistProtocolIdentity(configObject, serviceProtocol, protocolData);

    ApiV2ServerConfig apiV2ServerConfig = ApiV2ServerConfig::fromJson(configObject);
    ApiV2ServerConfig* apiV2 = &apiV2ServerConfig;
    applyProtocolIdentityToApiConfig(apiV2->apiConfig, serviceProtocol, protocolData);
    apiV2->apiConfig.vpnKey = normalizedKey;
    apiV2->apiConfig.isTestPurchase = isTestPurchase;
    apiV2->apiConfig.isInAppPurchase = true;
    apiV2->apiConfig.subscriptionExpiredByServer = false;
    apiV2->crc = crc;

    m_serversRepository->addServer(QString(), apiV2ServerConfig.toJson(),
                                   serverConfigUtils::configTypeFromJson(apiV2ServerConfig.toJson()));

    return ErrorCode::NoError;
}

ErrorCode SubscriptionController::importServiceFromGooglePlay(const QString &userCountryCode, const QString &serviceType,
                                                              const QString &serviceProtocol, const ProtocolData &protocolData,
                                                              const QString &userId,
                                                              const QString &obfuscatedAccountId,
                                                              const QString &purchaseToken, const QString &storeProductId,
                                                              const QString &storeProductType,
                                                              const QString &googlePlayBasePlanId,
                                                              const QString &orderId, int *duplicateServerIndex)
{
    QJsonObject authData;
    if (!userId.trimmed().isEmpty()) {
        authData[QStringLiteral("user_id")] = userId.trimmed();
    }
    if (!obfuscatedAccountId.trimmed().isEmpty()) {
        authData[QStringLiteral("obfuscated_account_id")] = obfuscatedAccountId.trimmed();
    }
    authData = authDataWithUserEmail(authData);

    GatewayRequestData gatewayRequestData { QSysInfo::productType(),
                                            QString(APP_VERSION),
                                            m_appSettingsRepository->getAppLanguage().name().split("_").first(),
                                            m_appSettingsRepository->getInstallationUuid(true),
                                            userCountryCode,
                                            "",
                                            "",
                                            serviceType,
                                            serviceProtocol,
                                            authData };

    QJsonObject apiPayload = gatewayRequestData.toJsonObject();
    appendProtocolDataToApiPayload(serviceProtocol, protocolData, apiPayload);
    apiPayload[apiDefs::key::transactionId] = purchaseToken;
    apiPayload[apiDefs::key::purchaseToken] = purchaseToken;
    if (!storeProductId.isEmpty()) {
        apiPayload[apiDefs::key::storeProductId] = storeProductId;
    }
    if (!storeProductType.isEmpty()) {
        apiPayload[apiDefs::key::storeProductType] = storeProductType;
    }
    if (!googlePlayBasePlanId.isEmpty()) {
        apiPayload[apiDefs::key::googlePlayBasePlanId] = googlePlayBasePlanId;
    }
    if (!orderId.isEmpty()) {
        apiPayload[apiDefs::key::orderId] = orderId;
    }

    QByteArray responseBody;
    ErrorCode errorCode = executeRequest(QString("%1v1/subscriptions/gpay"), apiPayload, responseBody, false,
                                         googlePlaySubscriptionRequestTimeoutMsecs);
    if (errorCode != ErrorCode::NoError) {
        qWarning().noquote() << "[GPAY] Subscription request failed. errorCode =" << static_cast<int>(errorCode)
                             << "responseBody =" << responseBody.left(2048);
        return errorCode;
    }

    QJsonObject responseObject = QJsonDocument::fromJson(responseBody).object();
    QString key = responseObject.value(QStringLiteral("key")).toString();
    if (key.isEmpty()) {
        qWarning().noquote() << "[GPAY] Purchase response does not contain a key field";
        return ErrorCode::ApiPurchaseError;
    }

    QString normalizedKey = key;
    normalizedKey.replace(QStringLiteral("vpn://"), QString());

    QByteArray configString = QByteArray::fromBase64(normalizedKey.toUtf8(), QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals);
    QByteArray configUncompressed = qUncompress(configString);
    if (!configUncompressed.isEmpty()) {
        configString = configUncompressed;
    }

    if (configString.isEmpty()) {
        qWarning().noquote() << "[GPAY] Purchase response config payload is empty";
        return ErrorCode::ApiPurchaseError;
    }

    QJsonObject configObject = QJsonDocument::fromJson(configString).object();
    quint16 crc = qChecksum(QJsonDocument(configObject).toJson());

    if (configObject.value(configKey::configVersion).toInt() != serverConfigUtils::ConfigSource::AmneziaGateway) {
        return ErrorCode::InternalError;
    }

    persistProtocolIdentity(configObject, serviceProtocol, protocolData);

    ApiV2ServerConfig apiV2ServerConfig = ApiV2ServerConfig::fromJson(configObject);
    ApiV2ServerConfig* apiV2 = &apiV2ServerConfig;
    applyProtocolIdentityToApiConfig(apiV2->apiConfig, serviceProtocol, protocolData);
    apiV2->apiConfig.vpnKey = normalizedKey;
    apiV2->apiConfig.isTestPurchase = false;
    apiV2->apiConfig.isInAppPurchase = true;
    apiV2->apiConfig.subscriptionExpiredByServer = false;
    apiV2->crc = crc;

    if (isWireGuardKeyExchangeProtocol(serviceProtocol)) {
        refreshWireGuardIdentityInExistingServerConfigs(m_serversRepository, serviceType, protocolData);
    }

    for (int i = 0; i < m_serversRepository->serversCount(); ++i) {
        const QString existingServerId = m_serversRepository->serverIdAt(i);
        const auto existingApiV2 = m_serversRepository->apiV2Config(existingServerId);
        QString existingVpnKey = existingApiV2.has_value() ? existingApiV2->vpnKey() : QString();
        existingVpnKey.replace(QStringLiteral("vpn://"), QString());
        if (!existingVpnKey.isEmpty() && existingVpnKey == normalizedKey) {
            if (duplicateServerIndex) {
                *duplicateServerIndex = i;
            }

            if (existingApiV2.has_value() && existingApiV2->nameOverriddenByUser) {
                apiV2->name = existingApiV2->name;
                apiV2->displayName = existingApiV2->displayName;
                apiV2->nameOverriddenByUser = true;
            }

            m_serversRepository->editServer(existingServerId, apiV2ServerConfig.toJson(),
                                           serverConfigUtils::configTypeFromJson(apiV2ServerConfig.toJson()));
            qInfo().noquote() << "[GPAY] Purchase config with the same vpn_key already exists; refreshed stored identity";
            return ErrorCode::ApiConfigAlreadyAdded;
        }
    }

    const QString renewalServerId = findMatchingGooglePlayRenewalServerId(m_serversRepository, serviceType);
    if (!renewalServerId.isEmpty()) {
        const auto existingApiV2 = m_serversRepository->apiV2Config(renewalServerId);
        if (existingApiV2.has_value()) {
            if (duplicateServerIndex) {
                *duplicateServerIndex = m_serversRepository->indexOfServerId(renewalServerId);
            }

            if (existingApiV2->nameOverriddenByUser) {
                apiV2->name = existingApiV2->name;
                apiV2->displayName = existingApiV2->displayName;
                apiV2->nameOverriddenByUser = true;
            }

            m_serversRepository->editServer(renewalServerId, apiV2ServerConfig.toJson(),
                                           serverConfigUtils::configTypeFromJson(apiV2ServerConfig.toJson()));
            qInfo().noquote() << "[GPAY] Refreshed existing in-app purchase server after renewal;"
                              << "serverId =" << renewalServerId
                              << "serviceProtocol =" << serviceProtocol
                              << "publicKey =" << protocolData.wireGuardClientPubKey;
            return ErrorCode::ApiConfigAlreadyAdded;
        }
    }

    m_serversRepository->addServer(QString(), apiV2ServerConfig.toJson(),
                                   serverConfigUtils::configTypeFromJson(apiV2ServerConfig.toJson()));

    return ErrorCode::NoError;
}

ErrorCode SubscriptionController::updateServiceFromGateway(const QString &serverId, const QString &newCountryCode, bool isConnectEvent,
                                                           const QString &newCityName,
                                                           const QString &serviceProtocolOverride, bool resetClientIdentity,
                                                           const QString &newCountryName)
{
    auto apiV2 = m_serversRepository->apiV2Config(serverId);
    if (!apiV2.has_value()) {
        return ErrorCode::InternalError;
    }

    // Always refresh from local storage right before preparing the /v1/config payload.
    // Other flows (for example GPay renewal/reset) may have just updated the stored
    // client identity, and /v1/config must use that latest persisted identity instead
    // of a stale copy kept by the caller.
    auto latestApiV2 = m_serversRepository->apiV2Config(serverId);
    if (!latestApiV2.has_value()) {
        return ErrorCode::InternalError;
    }
    apiV2 = latestApiV2;

    const bool isTestPurchase = apiV2->apiConfig.isTestPurchase;
    QString serviceProtocol = serviceProtocolOverride.trimmed().isEmpty()
            ? apiV2->serviceProtocol()
            : serviceProtocolOverride.trimmed().toLower();
    ProtocolData protocolData = resetClientIdentity ? ProtocolData{} : reusableProtocolIdentity(*apiV2, serviceProtocol);
    if (!hasReusableProtocolIdentity(serviceProtocol, protocolData)) {
        protocolData = generateProtocolData(serviceProtocol);
        applyProtocolIdentityToApiConfig(apiV2->apiConfig, serviceProtocol, protocolData);
        QJsonObject syncedConfig = apiV2->toJson();
        persistProtocolIdentity(syncedConfig, serviceProtocol, protocolData);
        m_serversRepository->editServer(serverId, syncedConfig, serverConfigUtils::configTypeFromJson(syncedConfig));

        latestApiV2 = m_serversRepository->apiV2Config(serverId);
        if (latestApiV2.has_value()) {
            apiV2 = latestApiV2;
        }
    }
    
    QJsonObject authDataJson = authDataWithUserEmail(apiV2->authData.toJson());
    GatewayRequestData gatewayRequestData { QSysInfo::productType(),
                                            QString(APP_VERSION),
                                            m_appSettingsRepository->getAppLanguage().name().split("_").first(),
                                            m_appSettingsRepository->getInstallationUuid(true),
                                            apiV2->apiConfig.userCountryCode,
                                            newCountryCode,
                                            newCityName,
                                            apiV2->serviceType(),
                                            serviceProtocol,
                                            authDataJson };

    QJsonObject apiPayload = gatewayRequestData.toJsonObject();
    appendProtocolDataToApiPayload(serviceProtocol, protocolData, apiPayload);

    if (isConnectEvent) {
        apiPayload[apiDefs::key::isConnectEvent] = true;
    }

    QByteArray responseBody;
    ErrorCode errorCode = executeRequest(QString("%1v1/config"), apiPayload, responseBody, isTestPurchase, configRequestTimeoutMsecs);
    if (errorCode != ErrorCode::NoError) {
        if (errorCode == ErrorCode::ApiSubscriptionExpiredError && !apiV2->apiConfig.isInAppPurchase) {
            ApiV2ServerConfig expiredApiV2 = *apiV2;
            expiredApiV2.apiConfig.subscriptionExpiredByServer = true;
            m_serversRepository->editServer(serverId, expiredApiV2.toJson(),
                                           serverConfigUtils::configTypeFromJson(expiredApiV2.toJson()));
        }
        return errorCode;
    }

    QJsonObject serverConfigJson;
    errorCode = extractServerConfigJsonFromResponse(responseBody, serviceProtocol, protocolData, serverConfigJson);
    if (errorCode != ErrorCode::NoError) {
        return errorCode;
    }
    
        const QString serverLocationName = newCityName.trimmed().isEmpty()
            ? (newCountryName.trimmed().isEmpty() ? apiV2->apiConfig.serverCountryName : newCountryName.trimmed())
            : newCityName.trimmed();
    updateApiConfigInJson(serverConfigJson, apiV2->apiConfig.serviceType, serviceProtocol, apiV2->apiConfig.userCountryCode,
                          responseBody, newCountryCode, serverLocationName);
    
    if (serverConfigJson.value(configKey::configVersion).toInt() != serverConfigUtils::ConfigSource::AmneziaGateway) {
        return ErrorCode::InternalError;
    }

    ApiV2ServerConfig newApiV2Config = ApiV2ServerConfig::fromJson(serverConfigJson);
    alignDefaultContainerWithServiceProtocol(newApiV2Config, serviceProtocol);
    ApiV2ServerConfig* newApiV2 = &newApiV2Config;
    
    newApiV2->apiConfig.vpnKey = apiV2->apiConfig.vpnKey;
    newApiV2->apiConfig.isTestPurchase = apiV2->apiConfig.isTestPurchase;
    newApiV2->apiConfig.isInAppPurchase = apiV2->apiConfig.isInAppPurchase;
    newApiV2->apiConfig.subscriptionExpiredByServer = false;
    newApiV2->apiConfig.clientIdentity = apiV2->apiConfig.clientIdentity;
    applyProtocolIdentityToApiConfig(newApiV2->apiConfig, serviceProtocol, protocolData);
    
    newApiV2->authData = apiV2->authData;
    newApiV2->crc = apiV2->crc;
    
    if (apiV2->nameOverriddenByUser) {
        newApiV2->name = apiV2->name;
        newApiV2->displayName = apiV2->displayName;
        newApiV2->nameOverriddenByUser = true;
    }

    m_serversRepository->editServer(serverId, newApiV2Config.toJson(),
                                   serverConfigUtils::configTypeFromJson(newApiV2Config.toJson()));
    return ErrorCode::NoError;
}

ErrorCode SubscriptionController::resetServiceClientIdentity(const QString &serverId, QString *serverMessage)
{
    auto apiV2 = m_serversRepository->apiV2Config(serverId);
    if (!apiV2.has_value()) {
        return ErrorCode::InternalError;
    }

    const ProtocolData wireGuardProtocolData = generateProtocolData(configKey::awg);
    const ProtocolData vlessProtocolData = generateProtocolData(configKey::vless);

    applyProtocolIdentityToApiConfig(apiV2->apiConfig, configKey::awg, wireGuardProtocolData);
    applyProtocolIdentityToApiConfig(apiV2->apiConfig, configKey::vless, vlessProtocolData);

    m_serversRepository->editServer(serverId, apiV2->toJson(),
                                    serverConfigUtils::configTypeFromJson(apiV2->toJson()));

    GatewayRequestData gatewayRequestData { QSysInfo::productType(),
                                            QString(APP_VERSION),
                                            m_appSettingsRepository->getAppLanguage().name().split("_").first(),
                                            m_appSettingsRepository->getInstallationUuid(true),
                                            "",
                                            "",
                                            "",
                                            "",
                                            "",
                                            authDataWithUserEmail(QJsonObject()) };

    QJsonObject apiPayload = gatewayRequestData.toJsonObject();
    if (apiV2->serviceProtocol() == configKey::vless) {
        apiPayload[apiDefs::key::publicKey] = vlessProtocolData.xrayUuid;
    } else {
        apiPayload[apiDefs::key::publicKey] = wireGuardProtocolData.wireGuardClientPubKey;
    }

    QByteArray responseBody;
    ErrorCode errorCode = executeRequest(QString("%1v1/subscriptions/reset"), apiPayload, responseBody,
                                         apiV2->apiConfig.isTestPurchase);
    if (errorCode != ErrorCode::NoError) {
        return errorCode;
    }

    const QJsonObject responseObject = QJsonDocument::fromJson(responseBody).object();
    const QString status = responseObject.value(QStringLiteral("status")).toString();
    const QString message = responseObject.value(QStringLiteral("message")).toString();
    if (serverMessage) {
        *serverMessage = message;
    }

    if (status == QStringLiteral("success")) {
        return ErrorCode::NoError;
    }

    if (status == QStringLiteral("error")) {
        return ErrorCode::ApiUpdateRequestError;
    }

    qWarning().noquote() << "Subscription reset response has unexpected status:" << status
                         << "responseBody =" << responseBody.left(2048);
    return ErrorCode::ApiUpdateRequestError;
}

ErrorCode SubscriptionController::deactivateDevice(const QString &serverId)
{
    auto apiV2 = m_serversRepository->apiV2Config(serverId);
    if (!apiV2.has_value()) {
        return ErrorCode::NoError;
    }
    
    if (!apiV2->isPremium() && !apiV2->isExternalPremium()) {
        return ErrorCode::NoError;
    }

    QJsonObject authDataJson = apiV2->authData.toJson();
    GatewayRequestData gatewayRequestData { QSysInfo::productType(),
                                            QString(APP_VERSION),
                                            m_appSettingsRepository->getAppLanguage().name().split("_").first(),
                                            m_appSettingsRepository->getInstallationUuid(true),
                                            apiV2->apiConfig.userCountryCode,
                                            apiV2->apiConfig.serverCountryCode,
                                            "",
                                            apiV2->serviceType(),
                                            "",
                                            authDataJson };

    QJsonObject apiPayload = gatewayRequestData.toJsonObject();

    const bool isTestPurchase = apiV2->apiConfig.isTestPurchase;
    QByteArray responseBody;
    ErrorCode errorCode = executeRequest(QString("%1v1/revoke_config"), apiPayload, responseBody, isTestPurchase);
    if (errorCode != ErrorCode::NoError && errorCode != ErrorCode::ApiNotFoundError) {
        return errorCode;
    }

    apiV2->containers.clear();
    m_serversRepository->editServer(serverId, apiV2->toJson(),
                                    serverConfigUtils::configTypeFromJson(apiV2->toJson()));
    return ErrorCode::NoError;
}

ErrorCode SubscriptionController::deactivateExternalDevice(const QString &serverId, const QString &uuid, const QString &serverCountryCode)
{
    auto apiV2 = m_serversRepository->apiV2Config(serverId);
    if (!apiV2.has_value()) {
        return ErrorCode::NoError;
    }
    
    if (!apiV2->isPremium() && !apiV2->isExternalPremium()) {
        return ErrorCode::NoError;
    }

    QJsonObject authDataJson = apiV2->authData.toJson();
    GatewayRequestData gatewayRequestData { QSysInfo::productType(),
                                            QString(APP_VERSION),
                                            m_appSettingsRepository->getAppLanguage().name().split("_").first(),
                                            uuid,
                                            apiV2->apiConfig.userCountryCode,
                                            serverCountryCode,
                                            "",
                                            apiV2->serviceType(),
                                            "",
                                            authDataJson };

    QJsonObject apiPayload = gatewayRequestData.toJsonObject();

    const bool isTestPurchase = apiV2->apiConfig.isTestPurchase;
    QByteArray responseBody;
    ErrorCode errorCode = executeRequest(QString("%1v1/revoke_config"), apiPayload, responseBody, isTestPurchase);
    if (errorCode != ErrorCode::NoError && errorCode != ErrorCode::ApiNotFoundError) {
        return errorCode;
    }

    if (uuid == m_appSettingsRepository->getInstallationUuid(true)) {
        apiV2->containers.clear();
        m_serversRepository->editServer(serverId, apiV2->toJson(),
                                        serverConfigUtils::configTypeFromJson(apiV2->toJson()));
    }

    return ErrorCode::NoError;
}

ErrorCode SubscriptionController::exportNativeConfig(const QString &serverId, const QString &serverCountryCode, QString &nativeConfig)
{
    auto apiV2 = m_serversRepository->apiV2Config(serverId);
    if (!apiV2.has_value()) {
        return ErrorCode::InternalError;
    }
    const bool isTestPurchase = apiV2->apiConfig.isTestPurchase;
    QString protocol = configKey::awg;
    ProtocolData protocolData = reusableProtocolIdentity(*apiV2, protocol);
    if (!hasReusableProtocolIdentity(protocol, protocolData)) {
        protocolData = generateProtocolData(protocol);
        applyProtocolIdentityToApiConfig(apiV2->apiConfig, protocol, protocolData);
        m_serversRepository->editServer(serverId, apiV2->toJson(),
                                        serverConfigUtils::configTypeFromJson(apiV2->toJson()));
    }

    QJsonObject authDataJson = apiV2->authData.toJson();
    GatewayRequestData gatewayRequestData { QSysInfo::productType(),
                                            QString(APP_VERSION),
                                            m_appSettingsRepository->getAppLanguage().name().split("_").first(),
                                            m_appSettingsRepository->getInstallationUuid(true),
                                            apiV2->apiConfig.userCountryCode,
                                            serverCountryCode,
                                            "",
                                            apiV2->serviceType(),
                                            protocol,
                                            authDataJson };

    QJsonObject apiPayload = gatewayRequestData.toJsonObject();
    appendProtocolDataToApiPayload(protocol, protocolData, apiPayload);

    QByteArray responseBody;
    ErrorCode errorCode = executeRequest(QString("%1v1/native_config"), apiPayload, responseBody, isTestPurchase);
    if (errorCode != ErrorCode::NoError) {
        return errorCode;
    }

    QJsonObject jsonConfig = QJsonDocument::fromJson(responseBody).object();
    nativeConfig = jsonConfig.value(configKey::config).toString();
    nativeConfig.replace("$WIREGUARD_CLIENT_PRIVATE_KEY", protocolData.wireGuardClientPrivKey);
    return ErrorCode::NoError;
}

ErrorCode SubscriptionController::revokeNativeConfig(const QString &serverId, const QString &serverCountryCode)
{
    auto apiV2 = m_serversRepository->apiV2Config(serverId);
    if (!apiV2.has_value()) {
        return ErrorCode::InternalError;
    }
    const bool isTestPurchase = apiV2->apiConfig.isTestPurchase;
    QString protocol = configKey::awg;

    QJsonObject authDataJson = apiV2->authData.toJson();
    GatewayRequestData gatewayRequestData { QSysInfo::productType(),
                                            QString(APP_VERSION),
                                            m_appSettingsRepository->getAppLanguage().name().split("_").first(),
                                            m_appSettingsRepository->getInstallationUuid(true),
                                            apiV2->apiConfig.userCountryCode,
                                            serverCountryCode,
                                            "",
                                            apiV2->serviceType(),
                                            protocol,
                                            authDataJson };

    QJsonObject apiPayload = gatewayRequestData.toJsonObject();

    QByteArray responseBody;
    ErrorCode errorCode = executeRequest(QString("%1v1/revoke_native_config"), apiPayload, responseBody, isTestPurchase);
    if (errorCode != ErrorCode::NoError && errorCode != ErrorCode::ApiNotFoundError) {
        return errorCode;
    }

    return ErrorCode::NoError;
}

ErrorCode SubscriptionController::prepareVpnKeyExport(const QString &serverId, QString &vpnKey)
{
    auto apiV2 = m_serversRepository->apiV2Config(serverId);
    if (!apiV2.has_value()) {
        return ErrorCode::ApiConfigEmptyError;
    }
    vpnKey = apiV2->vpnKey();
    if (vpnKey.isEmpty()) {
        vpnKey = apiUtils::getPremiumV2VpnKey(apiV2->toJson());
        if (vpnKey.isEmpty()) {
            return ErrorCode::ApiConfigEmptyError;
        }
        apiV2->apiConfig.vpnKey = vpnKey;
        m_serversRepository->editServer(serverId, apiV2->toJson(),
                                         serverConfigUtils::configTypeFromJson(apiV2->toJson()));
    }

    return ErrorCode::NoError;
}

ErrorCode SubscriptionController::validateAndUpdateConfig(const QString &serverId, bool hasInstalledContainers)
{
    const auto apiV2 = m_serversRepository->apiV2Config(serverId);
    if (!apiV2.has_value()) {
        return ErrorCode::NoError;
    }

    const QString serverCountryCode = apiV2->apiConfig.serverCountryCode;
    const QString serverLocationName = apiV2->apiConfig.serverCountryName;
    const QString serviceProtocol = apiV2->serviceProtocol();

    if (!hasInstalledContainers) {
        qDebug() << "validateAndUpdateConfig: installed containers missing, refreshing API config"
                 << "serverCountryCode=" << serverCountryCode
                 << "serverLocationName=" << serverLocationName
                 << "serviceProtocol=" << serviceProtocol;
        return updateServiceFromGateway(serverId, serverCountryCode, true,
                                        serverLocationName, serviceProtocol,
                                        false, serverLocationName);
    }

    if (isApiKeyExpired(serverId)) {
        qDebug() << "attempt to update api config by expires_at event";
        return updateServiceFromGateway(serverId, serverCountryCode, true,
                                        serverLocationName, serviceProtocol,
                                        false, serverLocationName);
    }

    return ErrorCode::NoError;
}

ErrorCode SubscriptionController::refreshWireGuardConfigForConnection(const QString &serverId)
{
    const auto apiV2 = m_serversRepository->apiV2Config(serverId);
    if (!apiV2.has_value()) {
        return ErrorCode::ApiConfigEmptyError;
    }

    const QString serviceProtocol = apiV2->serviceProtocol().trimmed().toLower();
    if (!isWireGuardKeyExchangeProtocol(serviceProtocol)) {
        return ErrorCode::InternalError;
    }

    const QString serverCountryCode = apiV2->apiConfig.serverCountryCode;
    const QString serverLocationName = apiV2->apiConfig.serverCountryName;
    const ErrorCode errorCode = updateServiceFromGateway(serverId,
                                                         serverCountryCode,
                                                         true,
                                                         serverLocationName,
                                                         serviceProtocol,
                                                         false,
                                                         serverLocationName);
    if (errorCode != ErrorCode::NoError) {
        return errorCode;
    }

    // Do not start the tunnel from an old or incomplete record if persistence
    // rejected the response for any reason. prepareConnection() will read this
    // same repository record again immediately before local tunnel startup.
    const auto persistedApiV2 = m_serversRepository->apiV2Config(serverId);
    if (!persistedApiV2.has_value()
            || persistedApiV2->serviceProtocol().trimmed().toLower() != serviceProtocol
            || persistedApiV2->defaultContainer == DockerContainer::None
            || !persistedApiV2->containers.contains(persistedApiV2->defaultContainer)) {
        return ErrorCode::ApiConfigEmptyError;
    }

    return ErrorCode::NoError;
}

ErrorCode SubscriptionController::buildWireGuardPeerRequest(const QString &serverId,
                                                             QJsonObject &apiPayload,
                                                             bool &isTestPurchase) const
{
    const auto apiV2 = m_serversRepository->apiV2Config(serverId);
    if (!apiV2.has_value()) {
        return ErrorCode::ApiConfigEmptyError;
    }

    const QString serviceProtocol = apiV2->serviceProtocol().trimmed().toLower();
    if (!isWireGuardKeyExchangeProtocol(serviceProtocol)) {
        return ErrorCode::InternalError;
    }

    const ProtocolData protocolData = reusableProtocolIdentity(*apiV2, serviceProtocol);
    if (!hasReusableProtocolIdentity(serviceProtocol, protocolData)) {
        return ErrorCode::ApiConfigEmptyError;
    }

    GatewayRequestData gatewayRequestData { QSysInfo::productType(),
                                            QString(APP_VERSION),
                                            m_appSettingsRepository->getAppLanguage().name().split("_").first(),
                                            m_appSettingsRepository->getInstallationUuid(true),
                                            apiV2->apiConfig.userCountryCode,
                                            apiV2->apiConfig.serverCountryCode,
                                            apiV2->apiConfig.serverCountryName,
                                            apiV2->serviceType(),
                                            serviceProtocol,
                                            authDataWithUserEmail(apiV2->authData.toJson()) };

    apiPayload = gatewayRequestData.toJsonObject();
    appendProtocolDataToApiPayload(serviceProtocol, protocolData, apiPayload);
    isTestPurchase = apiV2->apiConfig.isTestPurchase;
    return ErrorCode::NoError;
}

ErrorCode SubscriptionController::prepareWireGuardPeerConnection(const QString &serverId,
                                                                  bool &reuseExistingConfig)
{
    reuseExistingConfig = false;

    QJsonObject apiPayload;
    bool isTestPurchase = false;
    ErrorCode errorCode = buildWireGuardPeerRequest(serverId, apiPayload, isTestPurchase);
    if (errorCode != ErrorCode::NoError) {
        return errorCode;
    }

    QByteArray responseBody;
    errorCode = executeRequest(QStringLiteral("%1v1/peer/connect"), apiPayload, responseBody,
                               isTestPurchase, configRequestTimeoutMsecs);
    if (errorCode != ErrorCode::NoError) {
        return errorCode;
    }

    QJsonParseError parseError;
    const QJsonDocument responseDocument = QJsonDocument::fromJson(responseBody, &parseError);
    const QJsonObject responseObject = responseDocument.object();
    if (parseError.error != QJsonParseError::NoError
            || !responseDocument.isObject()
            || !responseObject.value(QStringLiteral("success")).isBool()
            || !responseObject.value(QStringLiteral("success")).toBool()
            || !responseObject.value(QStringLiteral("reuse_existing_config")).isBool()) {
        qWarning() << "SubscriptionController::prepareWireGuardPeerConnection: invalid response"
                   << "serverId=" << serverId
                   << "parseError=" << parseError.errorString();
        return ErrorCode::ApiUpdateRequestError;
    }

    reuseExistingConfig = responseObject.value(QStringLiteral("reuse_existing_config")).toBool();
    qInfo() << "SubscriptionController::prepareWireGuardPeerConnection: completed"
            << "serverId=" << serverId
            << "reuseExistingConfig=" << reuseExistingConfig;
    return ErrorCode::NoError;
}

ErrorCode SubscriptionController::notifyWireGuardPeerDisconnected(const QString &serverId)
{
    QJsonObject apiPayload;
    bool isTestPurchase = false;
    ErrorCode errorCode = buildWireGuardPeerRequest(serverId, apiPayload, isTestPurchase);
    if (errorCode != ErrorCode::NoError) {
        return errorCode;
    }

    QByteArray responseBody;
    errorCode = executeRequest(QStringLiteral("%1v1/peer/disconnect"), apiPayload, responseBody,
                               isTestPurchase, configRequestTimeoutMsecs);
    if (errorCode == ErrorCode::NoError) {
        qInfo() << "SubscriptionController::notifyWireGuardPeerDisconnected: completed"
                << "serverId=" << serverId;
    }
    return errorCode;
}

void SubscriptionController::removeApiConfig(const QString &serverId)
{
    auto apiV2 = m_serversRepository->apiV2Config(serverId);
    if (!apiV2.has_value()) {
        return;
    }

#if defined(Q_OS_IOS) || defined(MACOS_NE)
    QString description = apiV2->description;
    QString hostName = apiV2->hostName;
    QString vpncName = QString("%1 (%2) %3")
                               .arg(description)
                               .arg(hostName)
                               .arg("");

    AmneziaVPN::removeVPNC(vpncName.toStdString());
#endif

    apiV2->dns1.clear();
    apiV2->dns2.clear();
    apiV2->containers.clear();
    apiV2->hostName.clear();
    apiV2->defaultContainer = DockerContainer::None;
    apiV2->apiConfig.publicKey = ApiConfig::PublicKeyInfo{};

    m_serversRepository->editServer(serverId, apiV2->toJson(),
                                    serverConfigUtils::configTypeFromJson(apiV2->toJson()));
}

bool SubscriptionController::removeServer(const QString &serverId)
{
    if (serverId.isEmpty()) {
        return false;
    }

    if (!m_serversRepository->apiV2Config(serverId).has_value()) {
        qWarning().noquote() << "SubscriptionController::removeServer: not an Api V2 server, id" << serverId;
        return false;
    }

    const ErrorCode revokeError = deactivateDevice(serverId);
    if (revokeError != ErrorCode::NoError && revokeError != ErrorCode::ApiNotFoundError) {
        qWarning().noquote() << "SubscriptionController::removeServer: deactivateDevice failed (error"
                             << static_cast<int>(revokeError) << "); removing locally anyway.";
    }

    m_serversRepository->removeServer(serverId);
    return true;
}

bool SubscriptionController::isApiKeyExpired(const QString &serverId) const
{
    auto apiV2 = m_serversRepository->apiV2Config(serverId);
    if (!apiV2.has_value()) {
        return false;
    }
    const QString expiresAt = apiV2->apiConfig.publicKey.expiresAt;
    
    if (expiresAt.isEmpty()) {
        return false;
    }

    auto expiresAtDateTime = QDateTime::fromString(expiresAt, Qt::ISODate).toUTC();
    if (expiresAtDateTime < QDateTime::currentDateTimeUtc()) {
        return true;
    }
    
    return false;
}

void SubscriptionController::setCurrentProtocol(const QString &serverId, const QString &protocolName)
{
    auto apiV2 = m_serversRepository->apiV2Config(serverId);
    if (apiV2.has_value()) {
        apiV2->apiConfig.serviceProtocol = protocolName;
        m_serversRepository->editServer(serverId, apiV2->toJson(),
                                        serverConfigUtils::configTypeFromJson(apiV2->toJson()));
    }
}

bool SubscriptionController::isVlessProtocol(const QString &serverId) const
{
    auto apiV2 = m_serversRepository->apiV2Config(serverId);
    return apiV2.has_value() && apiV2->serviceProtocol() == "vless";
}

ErrorCode SubscriptionController::processAppStorePurchase(const QString &userCountryCode, const QString &serviceType,
                                                          const QString &serviceProtocol, const QString &productId,
                                                          int *duplicateServerIndex)
{
#if defined(Q_OS_IOS) || defined(MACOS_NE)
    bool purchaseOk = false;
    QString originalTransactionId;
    QString storeTransactionId;
    QString storeProductId;
    QString purchaseError;
    QEventLoop waitPurchase;

    IosController::Instance()->purchaseProduct(productId,
                                               [&](bool success, const QString &txId, const QString &purchasedProductId,
                                                   const QString &originalTxId, const QString &errorString) {
                                                   purchaseOk = success;
                                                   originalTransactionId = originalTxId;
                                                   storeTransactionId = txId;
                                                   storeProductId = purchasedProductId;
                                                   purchaseError = errorString;
                                                   waitPurchase.quit();
                                               });
    waitPurchase.exec();

    if (!purchaseOk || originalTransactionId.isEmpty()) {
        qDebug() << "IAP purchase failed:" << purchaseError;
        return ErrorCode::ApiPurchaseError;
    }
    qInfo().noquote() << "[IAP] Purchase success. transactionId =" << storeTransactionId
                      << "originalTransactionId =" << originalTransactionId << "productId =" << storeProductId;

    bool isTestPurchase = IosController::Instance()->isTestFlight();

    ProtocolData protocolData = generateProtocolData(serviceProtocol);
    return importServiceFromAppStore(userCountryCode, serviceType, serviceProtocol, protocolData,
                                     originalTransactionId, isTestPurchase, duplicateServerIndex);
#else
    Q_UNUSED(userCountryCode);
    Q_UNUSED(serviceType);
    Q_UNUSED(serviceProtocol);
    Q_UNUSED(productId);
    return ErrorCode::ApiPurchaseError;
#endif
}

ErrorCode SubscriptionController::processGooglePlayPurchase(const QString &userCountryCode, const QString &serviceType,
                                                            const QString &serviceProtocol, const QString &productId,
                                                            const QString &productType,
                                                            const QString &googlePlayBasePlanId,
                                                            int *duplicateServerIndex)
{
#ifdef Q_OS_ANDROID
    const QString userId = m_appSettingsRepository->getAuthUserId();
    const QString obfuscatedAccountId = makeGooglePlayObfuscatedAccountId(userId);
    QString purchaseToken;
    QString resolvedProductId;
    QString resolvedProductType;
    QString orderId;
    QString purchaseError;

    const bool purchaseOk = AndroidController::instance()->purchaseProduct(
        productId,
        productType,
        googlePlayBasePlanId,
        obfuscatedAccountId,
        &purchaseToken,
        &resolvedProductId,
        &resolvedProductType,
        &orderId,
        &purchaseError);

    if (!purchaseOk || purchaseToken.isEmpty()) {
        qWarning().noquote() << "[GPAY] Purchase failed:" << purchaseError;
        return ErrorCode::ApiPurchaseError;
    }

    qInfo().noquote() << "[GPAY] Purchase success. purchaseToken =" << purchaseToken
                      << "productId =" << resolvedProductId
                      << "productType =" << resolvedProductType
                      << "basePlanId =" << googlePlayBasePlanId
                      << "orderId =" << orderId;

    ProtocolData protocolData = generateProtocolData(serviceProtocol);
    return importServiceFromGooglePlay(userCountryCode, serviceType, serviceProtocol, protocolData,
                                       userId,
                                       obfuscatedAccountId,
                                       purchaseToken,
                                       resolvedProductId.isEmpty() ? productId : resolvedProductId,
                                       resolvedProductType.isEmpty() ? productType : resolvedProductType,
                                       googlePlayBasePlanId,
                                       orderId,
                                       duplicateServerIndex);
#else
    Q_UNUSED(userCountryCode);
    Q_UNUSED(serviceType);
    Q_UNUSED(serviceProtocol);
    Q_UNUSED(productId);
    Q_UNUSED(productType);
    Q_UNUSED(googlePlayBasePlanId);
    Q_UNUSED(duplicateServerIndex);
    return ErrorCode::ApiPurchaseError;
#endif
}

SubscriptionController::AppStoreRestoreResult SubscriptionController::processAppStoreRestore(const QString &userCountryCode, const QString &serviceType,
                                                                                             const QString &serviceProtocol)
{
    AppStoreRestoreResult result;

#if defined(Q_OS_IOS) || defined(MACOS_NE)
    bool restoreSuccess = false;
    QList<QVariantMap> restoredTransactions;
    QString restoreError;
    QEventLoop waitRestore;

    IosController::Instance()->restorePurchases([&](bool success, const QList<QVariantMap> &transactions, const QString &errorString) {
        restoreSuccess = success;
        restoredTransactions = transactions;
        restoreError = errorString;
        waitRestore.quit();
    });
    waitRestore.exec();

    if (!restoreSuccess) {
        qWarning().noquote() << "[IAP] Restore failed:" << restoreError;
        result.errorCode = ErrorCode::ApiPurchaseError;
        return result;
    }

    if (restoredTransactions.isEmpty()) {
        qInfo().noquote() << "[IAP] Restore completed, but no transactions were returned";
        result.errorCode = ErrorCode::ApiNoPurchasedSubscriptionsError;
        return result;
    }

    bool isTestPurchase = IosController::Instance()->isTestFlight();
    QSet<QString> processedTransactions;

    for (const QVariantMap &transaction : restoredTransactions) {
        const QString originalTransactionId = transaction.value(QStringLiteral("originalTransactionId")).toString();
        const QString transactionId = transaction.value(QStringLiteral("transactionId")).toString();
        const QString transactionProductId = transaction.value(QStringLiteral("productId")).toString();

        if (originalTransactionId.isEmpty()) {
            qWarning().noquote() << "[IAP] Skipping restored transaction without originalTransactionId" << transactionId;
            continue;
        }

        if (processedTransactions.contains(originalTransactionId)) {
            result.duplicateCount++;
            continue;
        }
        processedTransactions.insert(originalTransactionId);

        qInfo().noquote() << "[IAP] Restoring subscription. transactionId =" << transactionId
                          << "originalTransactionId =" << originalTransactionId << "productId =" << transactionProductId;

        ProtocolData protocolData = generateProtocolData(serviceProtocol);
        int currentDuplicateServerIndex = -1;
        ErrorCode errorCode = importServiceFromAppStore(userCountryCode, serviceType, serviceProtocol, protocolData,
                                                        originalTransactionId, isTestPurchase,
                                                        &currentDuplicateServerIndex);

        if (errorCode == ErrorCode::ApiConfigAlreadyAdded) {
            result.duplicateConfigAlreadyPresent = true;
            if (result.duplicateServerIndex < 0) {
                result.duplicateServerIndex = currentDuplicateServerIndex;
            }
            qInfo().noquote() << "[IAP] Skipping restored transaction" << originalTransactionId
                              << "because subscription config with the same vpn_key already exists";
        } else if (errorCode != ErrorCode::NoError) {
            qWarning().noquote() << "[IAP] Failed to process restored subscription response for transaction" << originalTransactionId;
            result.errorCode = errorCode;
        } else {
            result.hasInstalledConfig = true;
        }
    }

    if (!result.hasInstalledConfig) {
        result.errorCode = result.duplicateConfigAlreadyPresent ? ErrorCode::ApiConfigAlreadyAdded : ErrorCode::ApiPurchaseError;
    }

    return result;
#else
    Q_UNUSED(userCountryCode);
    Q_UNUSED(serviceType);
    Q_UNUSED(serviceProtocol);
    result.errorCode = ErrorCode::ApiPurchaseError;
    return result;
#endif
}

ErrorCode SubscriptionController::getAccountInfo(const QString &serverId, QJsonObject &accountInfo)
{
    auto apiV2 = m_serversRepository->apiV2Config(serverId);
    if (!apiV2.has_value()) {
        return ErrorCode::InternalError;
    }
    bool isTestPurchase = apiV2->apiConfig.isTestPurchase;

    const QString userEmail = m_appSettingsRepository->getAuthUserEmail();
    QJsonObject authDataJson = apiV2->authData.toJson();
    authDataJson[apiDefs::key::apiKey] = userEmail;
    authDataJson[apiDefs::key::email] = userEmail;
    GatewayRequestData gatewayRequestData { QSysInfo::productType(),
                                            QString(APP_VERSION),
                                            m_appSettingsRepository->getAppLanguage().name().split("_").first(),
                                            m_appSettingsRepository->getInstallationUuid(true),
                                            apiV2->apiConfig.userCountryCode,
                                            "",
                                            "",
                                            apiV2->serviceType(),
                                            "",
                                            authDataJson };

    QJsonObject apiPayload = gatewayRequestData.toJsonObject();
    apiPayload[apiDefs::key::cliVersion] = QString(APP_VERSION);
    apiPayload[apiDefs::key::subscriptionStatus] = getSubscriptionStatusForRenewal(apiV2->apiConfig);

    QByteArray responseBody;
    ErrorCode errorCode = executeRequest(QString("%1v1/account_info"), apiPayload, responseBody, isTestPurchase);
    if (errorCode != ErrorCode::NoError) {
        return errorCode;
    }

    accountInfo = QJsonDocument::fromJson(responseBody).object();

    ApiV2ServerConfig updatedApiV2 = *apiV2;
    bool configChanged = false;

    if (accountInfo.contains(apiDefs::key::subscriptionEndDate)) {
        updatedApiV2.apiConfig.subscription.endDate =
            accountInfo.value(apiDefs::key::subscriptionEndDate).toString();
        updatedApiV2.apiConfig.subscriptionExpiredByServer = false;
        configChanged = true;
    }

    if (accountInfo.contains(apiDefs::key::availableCountries)) {
        updatedApiV2.apiConfig.availableCountries = accountInfo.value(apiDefs::key::availableCountries).toArray();
        configChanged = true;
    }

    if (accountInfo.contains(apiDefs::key::supportedProtocols)) {
        updatedApiV2.apiConfig.supportedProtocols = accountInfo.value(apiDefs::key::supportedProtocols).toArray();
        configChanged = true;
    }

    if (configChanged) {
        m_serversRepository->editServer(serverId, updatedApiV2.toJson(),
                                       serverConfigUtils::configTypeFromJson(updatedApiV2.toJson()));
    }

    return ErrorCode::NoError;
}

SubscriptionController::AccountSubscriptionState SubscriptionController::accountSubscriptionState(
    const QJsonObject &accountInfo) const
{
    QString explicitStatus = accountInfo.value(apiDefs::key::subscriptionStatus)
                                 .toString().trimmed().toLower();
    if (explicitStatus.isEmpty()) {
        explicitStatus = accountInfo.value(apiDefs::key::subscriptionState)
                             .toString().trimmed().toLower();
    }
    if (explicitStatus.startsWith(QStringLiteral("subscription_state_"))) {
        explicitStatus.remove(0, QStringLiteral("subscription_state_").size());
    }

    if (explicitStatus == QStringLiteral("expired")
            || explicitStatus == QStringLiteral("inactive")) {
        return AccountSubscriptionState::Expired;
    }
    if (explicitStatus == QStringLiteral("active")
            || explicitStatus == QStringLiteral("expire_soon")) {
        return AccountSubscriptionState::Active;
    }

    const QString subscriptionEndDate = accountInfo.value(apiDefs::key::subscriptionEndDate)
                                            .toString().trimmed();
    if (subscriptionEndDate.isEmpty()) {
        return AccountSubscriptionState::NoSubscription;
    }
    return apiUtils::isSubscriptionExpired(subscriptionEndDate)
            ? AccountSubscriptionState::Expired
            : AccountSubscriptionState::Active;
}

ErrorCode SubscriptionController::restoreAccountConfigByEmail(const QString &email,
                                                               const QJsonObject &accountInfo,
                                                               QString &serverId,
                                                               bool &configRestored)
{
    configRestored = false;
    serverId.clear();

    QString serviceType = accountInfo.value(apiDefs::key::serviceType).toString().trimmed();
    if (serviceType.isEmpty()) {
        serviceType = QStringLiteral("amnezia-premium");
    }
    const QString subscriptionEndDate = accountInfo.value(apiDefs::key::subscriptionEndDate).toString();

    // Reuse an already restored account config instead of creating a duplicate on every login.
    for (int i = 0; i < m_serversRepository->serversCount(); ++i) {
        const QString existingServerId = m_serversRepository->serverIdAt(i);
        const auto existingApiV2 = m_serversRepository->apiV2Config(existingServerId);
        if (!existingApiV2.has_value()
            || existingApiV2->serviceType() != serviceType
            || existingApiV2->authData.apiKey.trimmed().compare(email, Qt::CaseInsensitive) != 0) {
            continue;
        }

        ApiV2ServerConfig updatedApiV2 = *existingApiV2;
        updatedApiV2.authData.apiKey = email;
        updatedApiV2.apiConfig.subscription.endDate = subscriptionEndDate;
        updatedApiV2.apiConfig.subscriptionExpiredByServer = false;
        if (accountInfo.contains(apiDefs::key::availableCountries)) {
            updatedApiV2.apiConfig.availableCountries =
                accountInfo.value(apiDefs::key::availableCountries).toArray();
        }
        if (accountInfo.contains(apiDefs::key::supportedProtocols)) {
            updatedApiV2.apiConfig.supportedProtocols =
                accountInfo.value(apiDefs::key::supportedProtocols).toArray();
        }
        m_serversRepository->editServer(existingServerId, updatedApiV2.toJson(),
                                        serverConfigUtils::configTypeFromJson(updatedApiV2.toJson()));
        serverId = existingServerId;
        return ErrorCode::NoError;
    }

    QString serviceProtocol = accountInfo.value(apiDefs::key::serviceProtocol).toString().trimmed().toLower();
    if (serviceProtocol.isEmpty()) {
        const QJsonArray supportedProtocols = accountInfo.value(apiDefs::key::supportedProtocols).toArray();
        for (const QJsonValue &protocolValue : supportedProtocols) {
            serviceProtocol = protocolValue.isString()
                    ? protocolValue.toString().trimmed().toLower()
                    : protocolValue.toObject().value(apiDefs::key::serviceProtocol)
                          .toString().trimmed().toLower();
            if (serviceProtocol.isEmpty()) {
                serviceProtocol = protocolValue.toObject().value(QStringLiteral("protocol"))
                                      .toString().trimmed().toLower();
            }
            if (!serviceProtocol.isEmpty()) {
                break;
            }
        }
    }
    if (serviceProtocol.isEmpty()) {
        qWarning().noquote() << "[ACCOUNT] Active subscription response has no service protocol; cannot restore config";
        return ErrorCode::ApiConfigEmptyError;
    }

    QString userCountryCode = accountInfo.value(apiDefs::key::userCountryCode).toString();
    if (userCountryCode.isEmpty()) {
        const QJsonArray availableCountries = accountInfo.value(apiDefs::key::availableCountries).toArray();
        if (!availableCountries.isEmpty()) {
            const QJsonValue countryValue = availableCountries.first();
            if (countryValue.isString()) {
                userCountryCode = countryValue.toString();
            } else {
                const QJsonObject countryObject = countryValue.toObject();
                userCountryCode = countryObject.value(apiDefs::key::serverCountryCode).toString();
                if (userCountryCode.isEmpty()) {
                    userCountryCode = countryObject.value(QStringLiteral("country_code")).toString();
                }
            }
        }
    }
    const ProtocolData protocolData = generateProtocolData(serviceProtocol);
    const QJsonObject authData {
        { apiDefs::key::apiKey, email },
        { apiDefs::key::email, email }
    };
    GatewayRequestData gatewayRequestData { QSysInfo::productType(),
                                            QString(APP_VERSION),
                                            m_appSettingsRepository->getAppLanguage().name().split("_").first(),
                                            m_appSettingsRepository->getInstallationUuid(true),
                                            userCountryCode,
                                            "",
                                            "",
                                            serviceType,
                                            serviceProtocol,
                                            authData };

    QJsonObject apiPayload = gatewayRequestData.toJsonObject();
    apiPayload[apiDefs::key::cliVersion] = QString(APP_VERSION);
    appendProtocolDataToApiPayload(serviceProtocol, protocolData, apiPayload);

    QByteArray responseBody;
    ErrorCode errorCode = executeRequest(QString("%1v1/config"), apiPayload, responseBody,
                                         false, configRequestTimeoutMsecs);
    if (errorCode != ErrorCode::NoError) {
        return errorCode;
    }

    QJsonObject serverConfigJson;
    errorCode = extractServerConfigJsonFromResponse(responseBody, serviceProtocol,
                                                    protocolData, serverConfigJson);
    if (errorCode != ErrorCode::NoError) {
        return errorCode;
    }

    updateApiConfigInJson(serverConfigJson, serviceType, serviceProtocol,
                          userCountryCode, responseBody);
    if (serverConfigJson.value(configKey::configVersion).toInt()
            != serverConfigUtils::ConfigSource::AmneziaGateway) {
        return ErrorCode::InternalError;
    }

    ApiV2ServerConfig apiV2 = ApiV2ServerConfig::fromJson(serverConfigJson);
    alignDefaultContainerWithServiceProtocol(apiV2, serviceProtocol);
    applyProtocolIdentityToApiConfig(apiV2.apiConfig, serviceProtocol, protocolData);
    apiV2.authData.apiKey = email;
    apiV2.apiConfig.subscription.endDate = subscriptionEndDate;
    apiV2.apiConfig.subscriptionExpiredByServer = false;
    if (accountInfo.contains(apiDefs::key::availableCountries)) {
        apiV2.apiConfig.availableCountries = accountInfo.value(apiDefs::key::availableCountries).toArray();
    }
    if (accountInfo.contains(apiDefs::key::supportedProtocols)) {
        apiV2.apiConfig.supportedProtocols = accountInfo.value(apiDefs::key::supportedProtocols).toArray();
    }

    const QJsonObject restoredConfig = apiV2.toJson();
    serverId = m_serversRepository->addServer(QString(), restoredConfig,
                                              serverConfigUtils::configTypeFromJson(restoredConfig));
    configRestored = !serverId.isEmpty();
    return configRestored ? ErrorCode::NoError : ErrorCode::InternalError;
}

ErrorCode SubscriptionController::getAccountInfoByEmail(const QString &email,
                                                        AccountLookupResult &result)
{
    result = AccountLookupResult{};
    const QString normalizedEmail = email.trimmed();
    if (normalizedEmail.isEmpty()) {
        return ErrorCode::InternalError;
    }

    const QJsonObject authData {
        { apiDefs::key::apiKey, normalizedEmail },
        { apiDefs::key::email, normalizedEmail }
    };
    GatewayRequestData gatewayRequestData { QSysInfo::productType(),
                                            QString(APP_VERSION),
                                            m_appSettingsRepository->getAppLanguage().name().split("_").first(),
                                            m_appSettingsRepository->getInstallationUuid(true),
                                            "",
                                            "",
                                            "",
                                            "",
                                            "",
                                            authData };

    QJsonObject apiPayload = gatewayRequestData.toJsonObject();
    apiPayload[apiDefs::key::cliVersion] = QString(APP_VERSION);

    QByteArray responseBody;
    const ErrorCode errorCode = executeRequest(QString("%1v1/account_info"),
                                               apiPayload, responseBody, false);
    if (errorCode == ErrorCode::ApiNoPurchasedSubscriptionsError
            || errorCode == ErrorCode::ApiSubscriptionNotActiveError) {
        result.state = AccountSubscriptionState::NoSubscription;
        return ErrorCode::NoError;
    }
    if (errorCode == ErrorCode::ApiSubscriptionExpiredError) {
        result.state = AccountSubscriptionState::Expired;
        return ErrorCode::NoError;
    }
    if (errorCode != ErrorCode::NoError) {
        return errorCode;
    }

    result.accountInfo = QJsonDocument::fromJson(responseBody).object();
    result.state = accountSubscriptionState(result.accountInfo);
    if (result.state == AccountSubscriptionState::Expired) {
        QString serviceType = result.accountInfo.value(apiDefs::key::serviceType).toString().trimmed();
        if (serviceType.isEmpty()) {
            serviceType = QStringLiteral("amnezia-premium");
        }
        for (int i = 0; i < m_serversRepository->serversCount(); ++i) {
            const QString existingServerId = m_serversRepository->serverIdAt(i);
            const auto existingApiV2 = m_serversRepository->apiV2Config(existingServerId);
            if (!existingApiV2.has_value()
                    || existingApiV2->serviceType() != serviceType
                    || existingApiV2->authData.apiKey.trimmed().compare(normalizedEmail, Qt::CaseInsensitive) != 0) {
                continue;
            }

            ApiV2ServerConfig updatedApiV2 = *existingApiV2;
            updatedApiV2.apiConfig.subscription.endDate =
                result.accountInfo.value(apiDefs::key::subscriptionEndDate).toString();
            updatedApiV2.apiConfig.subscriptionExpiredByServer = true;
            if (result.accountInfo.contains(apiDefs::key::availableCountries)) {
                updatedApiV2.apiConfig.availableCountries =
                    result.accountInfo.value(apiDefs::key::availableCountries).toArray();
            }
            if (result.accountInfo.contains(apiDefs::key::supportedProtocols)) {
                updatedApiV2.apiConfig.supportedProtocols =
                    result.accountInfo.value(apiDefs::key::supportedProtocols).toArray();
            }
            m_serversRepository->editServer(existingServerId, updatedApiV2.toJson(),
                                            serverConfigUtils::configTypeFromJson(updatedApiV2.toJson()));
            result.restoredServerId = existingServerId;
            break;
        }
        return ErrorCode::NoError;
    }
    if (result.state != AccountSubscriptionState::Active) {
        return ErrorCode::NoError;
    }

    return restoreAccountConfigByEmail(normalizedEmail, result.accountInfo,
                                       result.restoredServerId, result.configRestored);
}

QFuture<QPair<ErrorCode, QString>> SubscriptionController::getRenewalLink(const QString &serverId)
{
    auto promise = QSharedPointer<QPromise<QPair<ErrorCode, QString>>>::create();
    promise->start();

    auto apiV2 = m_serversRepository->apiV2Config(serverId);
    if (!apiV2.has_value()) {
        promise->addResult(qMakePair(ErrorCode::InternalError, QString()));
        promise->finish();
        return promise->future();
    }

    bool isTestPurchase = apiV2->apiConfig.isTestPurchase;
    QJsonObject authDataJson = apiV2->authData.toJson();
    GatewayRequestData gatewayRequestData { QSysInfo::productType(),
                                            QString(APP_VERSION),
                                            m_appSettingsRepository->getAppLanguage().name().split("_").first(),
                                            m_appSettingsRepository->getInstallationUuid(true),
                                            apiV2->apiConfig.userCountryCode,
                                            "",
                                            "",
                                            apiV2->serviceType(),
                                            "",
                                            authDataJson };

    QJsonObject apiPayload = gatewayRequestData.toJsonObject();
    apiPayload[apiDefs::key::cliVersion] = QString(APP_VERSION);
    apiPayload[apiDefs::key::subscriptionStatus] = getSubscriptionStatusForRenewal(apiV2->apiConfig);

    auto gatewayController = QSharedPointer<GatewayController>::create(m_appSettingsRepository->getGatewayEndpoint(isTestPurchase),
                                                                       m_appSettingsRepository->isDevGatewayEnv(isTestPurchase),
                                                                       apiDefs::requestTimeoutMsecs,
                                                                       m_appSettingsRepository->isStrictKillSwitchEnabled(),
                                                                       m_appSettingsRepository);
    auto postFuture = gatewayController->postAsync(QString("%1v1/renewal_link"), apiPayload);
    auto *watcher = new QFutureWatcher<QPair<ErrorCode, QByteArray>>();
    QObject::connect(watcher, &QFutureWatcher<QPair<ErrorCode, QByteArray>>::finished,
                     [promise, watcher, gatewayController]() {
                         const auto [errorCode, responseBody] = watcher->result();
                         watcher->deleteLater();
                         if (errorCode != ErrorCode::NoError) {
                             promise->addResult(qMakePair(errorCode, QString()));
                             promise->finish();
                             return;
                         }

                         QJsonObject responseJson = QJsonDocument::fromJson(responseBody).object();
                         const QString url = responseJson.value("renewal_url").toString();
                         promise->addResult(qMakePair(ErrorCode::NoError, url));
                         promise->finish();
                     });
    watcher->setFuture(postFuture);
    return promise->future();
}

ErrorCode SubscriptionController::resolveImportServiceCaptcha(const QString &userCountryCode,
                                                              const QString &serviceType,
                                                              const QString &serviceProtocol,
                                                              const ProtocolData &protocolData,
                                                              const QString &captchaId,
                                                              const QString &captchaSolution,
                                                              CaptchaInfo *retryCaptchaOut)
{
    GatewayRequestData gatewayRequestData{QSysInfo::productType(),
                                          QString(APP_VERSION),
                                          m_appSettingsRepository->getAppLanguage().name().split("_").first(),
                                          m_appSettingsRepository->getInstallationUuid(true),
                                          userCountryCode,
                                          "",
                                          "",
                                          serviceType,
                                          serviceProtocol,
                                          authDataWithUserEmail(QJsonObject())};

    QJsonObject apiPayload = gatewayRequestData.toJsonObject();
    appendProtocolDataToApiPayload(serviceProtocol, protocolData, apiPayload);

    apiPayload["captcha_id"] = captchaId;
    QString normalizedSolution;
    normalizedSolution.reserve(captchaSolution.size());
    for (const QChar &ch : captchaSolution) {
        const ushort u = ch.unicode();
        if (u >= '0' && u <= '9') {
            normalizedSolution += ch;
        } else if (u >= 0xFF10 && u <= 0xFF19) {
            normalizedSolution += QChar(static_cast<char16_t>(u - 0xFF10 + '0'));
        }
    }
    apiPayload["captcha_solution"] = normalizedSolution.isEmpty() ? captchaSolution.trimmed() : normalizedSolution;

    QByteArray responseBody;
    ErrorCode errorCode = executeRequest(QString("%1v1/config"), apiPayload, responseBody, false, configRequestTimeoutMsecs);
    if (errorCode != ErrorCode::NoError) {
        if (retryCaptchaOut
            && (errorCode == ErrorCode::ApiCaptchaInvalidError || errorCode == ErrorCode::ApiCaptchaRefreshError
                || errorCode == ErrorCode::ApiCaptchaRequiredError)) {
            const QJsonDocument jsonDoc = QJsonDocument::fromJson(responseBody);
            if (jsonDoc.isObject()) {
                const QJsonObject jsonObj = jsonDoc.object();
                if (jsonObj.contains(QStringLiteral("captcha_id")) && jsonObj.contains(QStringLiteral("captcha_image"))) {
                    retryCaptchaOut->captchaId = jsonObj.value(QStringLiteral("captcha_id")).toString();
                    retryCaptchaOut->captchaImageBase64 = jsonObj.value(QStringLiteral("captcha_image")).toString();
                    retryCaptchaOut->hint = jsonObj.value(QStringLiteral("hint")).toString();
                    retryCaptchaOut->isRequired = true;
                }
            }
        }
        return errorCode;
    }

    QJsonObject serverConfigJson;
    errorCode = extractServerConfigJsonFromResponse(responseBody, serviceProtocol, protocolData, serverConfigJson);
    if (errorCode != ErrorCode::NoError) {
        return errorCode;
    }

    updateApiConfigInJson(serverConfigJson, serviceType, serviceProtocol, userCountryCode, responseBody);

    if (serverConfigJson.value(configKey::configVersion).toInt() != serverConfigUtils::ConfigSource::AmneziaGateway) {
        return ErrorCode::InternalError;
    }

    ApiV2ServerConfig apiV2ServerConfig = ApiV2ServerConfig::fromJson(serverConfigJson);
    alignDefaultContainerWithServiceProtocol(apiV2ServerConfig, serviceProtocol);
    m_serversRepository->addServer(QString(), apiV2ServerConfig.toJson(),
                                   serverConfigUtils::configTypeFromJson(apiV2ServerConfig.toJson()));
    return ErrorCode::NoError;
}
