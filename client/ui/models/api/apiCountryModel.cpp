#include "apiCountryModel.h"

#include <QCoreApplication>
#include <QHash>
#include <QJsonObject>
#include <QLocale>
#include <QStringList>

#include "core/utils/api/apiTextUtils.h"
#include "core/utils/serverConfigUtils.h"
#include "core/utils/constants/apiKeys.h"
#include "core/utils/constants/apiConstants.h"
#include "logger.h"

namespace
{
    Logger logger("ApiCountryModel");
    using CountryInfo = ApiCountryModel::CountryInfo;

    constexpr QLatin1String countryConfig("country_config");
    constexpr QLatin1String supportedProtocols("supported_protocols");
    constexpr QLatin1String protocols("protocols");
    constexpr QLatin1String serviceProtocols("service_protocols");

    QString normalizeProtocolName(const QString &protocolName)
    {
        const QString protocol = protocolName.trimmed().toLower();
        if (protocol == QLatin1String("wireguard") || protocol == QLatin1String("wg")
            || protocol == QLatin1String("awg") || protocol == QLatin1String("amneziawg")) {
            return QStringLiteral("awg");
        }
        if (protocol == QLatin1String("vless") || protocol == QLatin1String("xray")) {
            return QStringLiteral("vless");
        }
        if (protocol == QLatin1String("openvpn") || protocol == QLatin1String("ovpn")) {
            return QStringLiteral("openvpn");
        }
        return protocol;
    }

    QStringList protocolListFromJsonValue(const QJsonValue &value)
    {
        QStringList result;
        if (value.isArray()) {
            const QJsonArray array = value.toArray();
            for (const auto &item : array) {
                const QString normalized = normalizeProtocolName(item.toString());
                if (!normalized.isEmpty() && !result.contains(normalized)) {
                    result.push_back(normalized);
                }
            }
        } else if (value.isString()) {
            const QString raw = value.toString();
            for (const QString &item : raw.split(',', Qt::SkipEmptyParts)) {
                const QString normalized = normalizeProtocolName(item);
                if (!normalized.isEmpty() && !result.contains(normalized)) {
                    result.push_back(normalized);
                }
            }
        }
        return result;
    }

    QStringList countryProtocols(const QJsonObject &countryObject)
    {
        QStringList result = protocolListFromJsonValue(countryObject.value(supportedProtocols));
        if (result.isEmpty()) {
            result = protocolListFromJsonValue(countryObject.value(protocols));
        }
        if (result.isEmpty()) {
            result = protocolListFromJsonValue(countryObject.value(serviceProtocols));
        }
        return result;
    }

    QString localizedCountryName(const QString &countryCode)
    {
        static const QHash<QString, const char *> countryNames {
            { QStringLiteral("DE"), QT_TRANSLATE_NOOP("CountryName", "Germany") },
            { QStringLiteral("US"), QT_TRANSLATE_NOOP("CountryName", "United States") },
            { QStringLiteral("FR"), QT_TRANSLATE_NOOP("CountryName", "France") },
            { QStringLiteral("JP"), QT_TRANSLATE_NOOP("CountryName", "Japan") },
            { QStringLiteral("SG"), QT_TRANSLATE_NOOP("CountryName", "Singapore") },
        };

        const QString normalizedCountryCode = countryCode.trimmed().toUpper();
        const auto countryName = countryNames.constFind(normalizedCountryCode);
        if (countryName != countryNames.constEnd()) {
            return QCoreApplication::translate("CountryName", countryName.value());
        }

        const QLocale::Territory territory = QLocale::codeToTerritory(normalizedCountryCode);
        return territory == QLocale::AnyTerritory ? QString() : QLocale::territoryToString(territory);
    }

    QString localizedCityName(const QString &cityCode, const QString &fallbackName = QString())
    {
        return apiTextUtils::translateCity(cityCode, fallbackName);
    }

    QString countryNameToCode(const QString &countryName)
    {
        const QString normalizedCountryName = countryName.trimmed();
        if (normalizedCountryName.isEmpty()) {
            return {};
        }

        for (int territory = QLocale::AnyTerritory + 1; territory <= QLocale::LastTerritory; ++territory) {
            const auto localeTerritory = static_cast<QLocale::Territory>(territory);
            if (QLocale::territoryToString(localeTerritory).compare(normalizedCountryName, Qt::CaseInsensitive) == 0) {
                return QLocale::territoryToCode(localeTerritory).toUpper();
            }
        }

        return {};
    }

    void addCity(CountryInfo &countryInfo, const QString &cityName, const QString &cityRequestName,
                 const QString &cityFallbackName = QString())
    {
        const QString normalizedCityName = cityName.trimmed();
        const QString normalizedCityRequestName = cityRequestName.trimmed();
        if (normalizedCityName.isEmpty()) {
            return;
        }
        if ((!normalizedCityRequestName.isEmpty() && countryInfo.cityRequestNames.contains(normalizedCityRequestName))
            || (normalizedCityRequestName.isEmpty() && countryInfo.cityNames.contains(normalizedCityName))) {
            return;
        }
        countryInfo.cityNames.push_back(normalizedCityName);
        countryInfo.cityRequestNames.push_back(normalizedCityRequestName);
        countryInfo.cityFallbackNames.push_back(cityFallbackName.trimmed());
        countryInfo.cityQualities.push_back({});
    }

    void mergeProtocols(CountryInfo &countryInfo, const QStringList &protocols)
    {
        for (const QString &protocol : protocols) {
            if (!protocol.isEmpty() && !countryInfo.supportedProtocols.contains(protocol)) {
                countryInfo.supportedProtocols.push_back(protocol);
            }
        }
    }

    int countryIndexByCode(const QVector<CountryInfo> &countries, const QString &countryCode)
    {
        for (int i = 0; i < countries.size(); ++i) {
            if (countries.at(i).countryCode == countryCode) {
                return i;
            }
        }
        return -1;
    }

    CountryInfo countryInfoFromObject(const QJsonObject &countryObject)
    {
        CountryInfo countryInfo;

        QString countryCode = countryObject.value(apiDefs::key::countryCode).toString().trimmed().toUpper();
        if (countryCode.isEmpty()) {
            countryCode = countryObject.value(apiDefs::key::serverCountryCode).toString().trimmed().toUpper();
        }

        QString countryName = countryObject.value(apiDefs::key::serverCountryName).toString().trimmed();
        if (!countryCode.isEmpty()) {
            const QString displayName = localizedCountryName(countryCode);
            if (!displayName.isEmpty()) {
                countryName = displayName;
            }
        }

        QString cityCode = countryObject.value(apiDefs::key::cityCode).toString().trimmed();
        if (cityCode.isEmpty()) {
            cityCode = countryObject.value(apiDefs::key::serverCityCode).toString().trimmed();
        }

        const QString serverCityName = countryObject.value(apiDefs::key::serverCityName).toString().trimmed();
        const bool hasCityCode = !cityCode.isEmpty();

        QString cityName = serverCityName;
        if (hasCityCode) {
            cityName = localizedCityName(cityCode, serverCityName);
        }

        countryInfo.countryName = countryName;
        countryInfo.countryCode = countryCode;
        countryInfo.defaultCountryCode = countryCode;
        countryInfo.supportedProtocols = countryProtocols(countryObject);
        addCity(countryInfo, cityName.isEmpty() ? QStringLiteral("Default") : cityName, cityCode, serverCityName);

        return countryInfo;
    }
}

ApiCountryModel::ApiCountryModel(QObject *parent) : QAbstractListModel(parent)
{
}

int ApiCountryModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent)
    return m_countries.size();
}

QVariant ApiCountryModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= static_cast<int>(rowCount()))
        return QVariant();

    CountryInfo countryInfo = m_countries.at(index.row());
    IssuedConfigInfo issuedConfigInfo = m_issuedConfigs.value(countryInfo.countryCode);
    bool isIssued = issuedConfigInfo.sourceType == countryConfig;

    switch (role) {
    case CountryCodeRole: {
        return countryInfo.countryCode;
    }
    case DefaultCountryCodeRole: {
        return countryInfo.defaultCountryCode;
    }
    case CountryNameRole: {
        return countryInfo.countryName;
    }
    case CountryImageCodeRole: {
        return countryInfo.countryCode.toUpper();
    }
    case IsIssuedRole: {
        return isIssued;
    }
    case IsWorkerExpiredRole: {
        return issuedConfigInfo.lastDownloaded < issuedConfigInfo.workerLastUpdated;
    }
    case SupportedProtocolsRole: {
        return countryInfo.supportedProtocols;
    }
    case CityNamesRole: {
        return countryInfo.cityNames;
    }
    case CityRequestNamesRole: {
        return countryInfo.cityRequestNames;
    }
    case CityFallbackNamesRole: {
        return countryInfo.cityFallbackNames;
    }
    case CityCountRole: {
        return countryInfo.cityNames.size();
    }
    case CountryLatencyMsRole: {
        return countryInfo.cityQualities.value(0).latencyMs;
    }
    case CountryLatencyTextRole: {
        const int latencyMs = countryInfo.cityQualities.value(0).latencyMs;
        return latencyMs >= 0 ? QStringLiteral("%1 ms").arg(latencyMs) : QStringLiteral("-- ms");
    }
    case CountrySignalBarsRole: {
        return countryInfo.cityQualities.value(0).signalBars;
    }
    case CountryQualityStatusRole: {
        return countryInfo.cityQualities.value(0).status;
    }
    case CountryQualityLabelRole: {
        return countryInfo.cityQualities.value(0).label;
    }
    case CityQualitiesRole: {
        QVariantList result;
        result.reserve(countryInfo.cityQualities.size());
        for (const NodeQuality &quality : countryInfo.cityQualities) {
            QVariantMap item;
            item.insert(QStringLiteral("latencyMs"), quality.latencyMs);
            item.insert(QStringLiteral("latencyText"), quality.latencyMs >= 0
                        ? QStringLiteral("%1 ms").arg(quality.latencyMs) : QStringLiteral("-- ms"));
            item.insert(QStringLiteral("signalBars"), quality.signalBars);
            item.insert(QStringLiteral("score"), quality.score);
            item.insert(QStringLiteral("status"), quality.status);
            item.insert(QStringLiteral("label"), quality.label);
            result.append(item);
        }
        return result;
    }
    }

    return QVariant();
}

void ApiCountryModel::updateModel(const QJsonArray &countries, const QString &currentCountryCode)
{
    beginResetModel();

    m_countries.clear();
    m_currentIndex = -1;
    for (int i = 0; i < countries.size(); i++) {
        CountryInfo countryInfo;
        const QJsonValue countryValue = countries.at(i);

        if (countryValue.isString()) {
            countryInfo.countryName = countryValue.toString().trimmed();
            countryInfo.countryCode = countryNameToCode(countryInfo.countryName);
            countryInfo.defaultCountryCode = countryInfo.countryCode;
            addCity(countryInfo, QStringLiteral("Default"), QString());
        } else {
            countryInfo = countryInfoFromObject(countryValue.toObject());
        }

        if (countryInfo.countryCode.isEmpty() && countryInfo.countryName.size() == 2) {
            countryInfo.countryCode = countryInfo.countryName.toUpper();
        }
        if (countryInfo.defaultCountryCode.isEmpty()) {
            countryInfo.defaultCountryCode = countryInfo.countryCode;
        }
        if (countryInfo.countryName.isEmpty() && !countryInfo.countryCode.isEmpty()) {
            countryInfo.countryName = localizedCountryName(countryInfo.countryCode);
        }
        if (countryInfo.countryCode.isEmpty()) {
            qWarning().noquote() << "[ApiCountryModel] Skip country without server_country_code:" << countryValue;
            continue;
        }

        countryInfo.countryCode = countryInfo.countryCode.toUpper();
        countryInfo.defaultCountryCode = countryInfo.defaultCountryCode.toUpper();

        const int existingIndex = countryIndexByCode(m_countries, countryInfo.countryCode);
        if (existingIndex >= 0) {
            CountryInfo &existingCountryInfo = m_countries[existingIndex];
            for (int cityIndex = 0; cityIndex < countryInfo.cityNames.size(); ++cityIndex) {
                addCity(existingCountryInfo, countryInfo.cityNames.value(cityIndex), countryInfo.cityRequestNames.value(cityIndex),
                        countryInfo.cityFallbackNames.value(cityIndex));
            }
            mergeProtocols(existingCountryInfo, countryInfo.supportedProtocols);
        } else {
            m_countries.push_back(countryInfo);
        }
    }

    const QString normalizedCurrentCountryCode = currentCountryCode.trimmed().toUpper();
    for (int i = 0; i < m_countries.size(); ++i) {
        const CountryInfo &countryInfo = m_countries.at(i);
        if (countryInfo.countryCode == normalizedCurrentCountryCode
            || countryInfo.defaultCountryCode == normalizedCurrentCountryCode) {
            m_currentIndex = i;
            break;
        }
    }
    endResetModel();

    emit currentIndexChanged(m_currentIndex);
}

void ApiCountryModel::refreshTranslations()
{
    if (m_countries.isEmpty()) {
        return;
    }

    for (CountryInfo &countryInfo : m_countries) {
        const QString countryName = localizedCountryName(countryInfo.countryCode);
        if (!countryName.isEmpty()) {
            countryInfo.countryName = countryName;
        }

        for (qsizetype cityIndex = 0; cityIndex < countryInfo.cityRequestNames.size(); ++cityIndex) {
            const QString cityCode = countryInfo.cityRequestNames.at(cityIndex);
            if (!cityCode.isEmpty()) {
                countryInfo.cityNames[cityIndex] = localizedCityName(cityCode, countryInfo.cityFallbackNames.value(cityIndex));
            }
        }
    }

    emit dataChanged(index(0, 0), index(m_countries.size() - 1, 0),
                     { CountryNameRole, CityNamesRole });
}

void ApiCountryModel::resetNodeQualities()
{
    if (m_countries.isEmpty()) {
        return;
    }
    for (CountryInfo &country : m_countries) {
        for (NodeQuality &quality : country.cityQualities) {
            quality = {};
        }
    }
    emit dataChanged(index(0, 0), index(m_countries.size() - 1, 0),
                     { CountryLatencyMsRole, CountryLatencyTextRole, CountrySignalBarsRole,
                       CountryQualityStatusRole, CountryQualityLabelRole, CityQualitiesRole });
}

void ApiCountryModel::setNodeQuality(const QString &countryCode, const QString &cityCode, int latencyMs,
                                     int signalBars, int score, const QString &status, const QString &label)
{
    const QString normalizedCountry = countryCode.trimmed().toUpper();
    const QString normalizedCity = cityCode.trimmed();
    for (int countryIndex = 0; countryIndex < m_countries.size(); ++countryIndex) {
        CountryInfo &country = m_countries[countryIndex];
        if (country.countryCode != normalizedCountry) {
            continue;
        }
        int cityIndex = country.cityRequestNames.indexOf(normalizedCity);
        if (cityIndex < 0 && country.cityRequestNames.size() == 1) {
            cityIndex = 0;
        }
        if (cityIndex < 0 || cityIndex >= country.cityQualities.size()) {
            return;
        }
        NodeQuality &quality = country.cityQualities[cityIndex];
        quality.latencyMs = latencyMs;
        quality.signalBars = qBound(0, signalBars, 4);
        quality.score = score;
        quality.status = status.trimmed().toLower();
        quality.label = label;
        emit dataChanged(index(countryIndex, 0), index(countryIndex, 0),
                         { CountryLatencyMsRole, CountryLatencyTextRole, CountrySignalBarsRole,
                           CountryQualityStatusRole, CountryQualityLabelRole, CityQualitiesRole });
        return;
    }
}

void ApiCountryModel::updateIssuedConfigsInfo(const QJsonArray &issuedConfigs)
{
    beginResetModel();

    m_issuedConfigs.clear();
    for (int i = 0; i < issuedConfigs.size(); i++) {
        IssuedConfigInfo issuedConfigInfo;
        QJsonObject issuedConfigObject = issuedConfigs.at(i).toObject();

        if (issuedConfigObject.value(apiDefs::key::sourceType).toString() != countryConfig) {
            continue;
        }

        issuedConfigInfo.installationUuid = issuedConfigObject.value(apiDefs::key::installationUuid).toString();
        issuedConfigInfo.workerLastUpdated = issuedConfigObject.value(apiDefs::key::workerLastUpdated).toString();
        issuedConfigInfo.lastDownloaded = issuedConfigObject.value(apiDefs::key::lastDownloaded).toString();
        issuedConfigInfo.sourceType = issuedConfigObject.value(apiDefs::key::sourceType).toString();
        issuedConfigInfo.osVersion = issuedConfigObject.value(apiDefs::key::osVersion).toString();

        m_issuedConfigs.insert(issuedConfigObject.value(apiDefs::key::serverCountryCode).toString(), issuedConfigInfo);
    }

    endResetModel();
}

int ApiCountryModel::getCurrentIndex()
{
    return m_currentIndex;
}

void ApiCountryModel::setCurrentIndex(const int i)
{
    m_currentIndex = i;
    emit currentIndexChanged(m_currentIndex);
}

bool ApiCountryModel::supportsProtocol(int index, const QString &protocolName) const
{
    if (index < 0 || index >= m_countries.size()) {
        return false;
    }

    const QString normalizedProtocol = normalizeProtocolName(protocolName);
    if (normalizedProtocol.isEmpty()) {
        return true;
    }

    const QStringList protocols = m_countries.at(index).supportedProtocols;
    if (protocols.isEmpty()) {
        // Older API responses only return a plain country list. In that case the
        // client cannot know per-country protocol availability, so keep the
        // country visible and let the server validate the selected protocol.
        return true;
    }
    return protocols.contains(normalizedProtocol);
}

QHash<int, QByteArray> ApiCountryModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[CountryNameRole] = "countryName";
    roles[CountryCodeRole] = "countryCode";
    roles[DefaultCountryCodeRole] = "defaultCountryCode";
    roles[CountryImageCodeRole] = "countryImageCode";
    roles[IsIssuedRole] = "isIssued";
    roles[IsWorkerExpiredRole] = "isWorkerExpired";
    roles[SupportedProtocolsRole] = "supportedProtocols";
    roles[CityNamesRole] = "cityNames";
    roles[CityRequestNamesRole] = "cityRequestNames";
    roles[CityFallbackNamesRole] = "cityFallbackNames";
    roles[CityCountRole] = "cityCount";
    roles[CountryLatencyMsRole] = "countryLatencyMs";
    roles[CountryLatencyTextRole] = "countryLatencyText";
    roles[CountrySignalBarsRole] = "countrySignalBars";
    roles[CountryQualityStatusRole] = "countryQualityStatus";
    roles[CountryQualityLabelRole] = "countryQualityLabel";
    roles[CityQualitiesRole] = "cityQualities";
    return roles;
}
