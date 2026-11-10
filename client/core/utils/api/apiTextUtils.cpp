#include "apiTextUtils.h"

#include <QHash>
#include <QLoggingCategory>
#include <QReadLocker>
#include <QReadWriteLock>
#include <QWriteLocker>

namespace
{
Q_LOGGING_CATEGORY(apiTextLog, "amnezia.api.text")

QReadWriteLock textTranslationsLock;
QHash<QString, QString> textTranslations;
QReadWriteLock cityTranslationsLock;
QHash<QString, QString> cityTranslations;

QString formattedCityCode(const QString &cityCode)
{
    QString displayName = cityCode.trimmed();
    displayName.replace(QLatin1Char('_'), QLatin1Char(' '));

    bool capitalizeNext = true;
    for (QChar &character : displayName) {
        if (character.isSpace()) {
            capitalizeNext = true;
        } else if (capitalizeNext) {
            character = character.toUpper();
            capitalizeNext = false;
        }
    }
    return displayName;
}

}

QString apiTextUtils::translate(const QString &value)
{
    const QString trimmedValue = value.trimmed();
    if (!trimmedValue.startsWith(QLatin1String("id:"))) {
        return value;
    }

    const QString id = trimmedValue.mid(3);
    QReadLocker locker(&textTranslationsLock);
    const auto translation = textTranslations.constFind(id);
    if (translation == textTranslations.constEnd() || translation->isEmpty()) {
        qCWarning(apiTextLog).noquote() << "Unknown API text ID:" << id;
        return id;
    }

    return *translation;
}

QString apiTextUtils::translateCity(const QString &cityCode, const QString &fallbackName)
{
    QString normalizedCode = cityCode.trimmed();
    if (normalizedCode.startsWith(QLatin1String("id:"))) {
        normalizedCode = normalizedCode.mid(3);
    }

    {
        QReadLocker locker(&cityTranslationsLock);
        const auto translation = cityTranslations.constFind(normalizedCode);
        if (translation != cityTranslations.constEnd() && !translation->isEmpty()) {
            return *translation;
        }
    }

    if (!fallbackName.trimmed().isEmpty()) {
        return fallbackName;
    }

    const QString staticId = QStringLiteral("id:%1").arg(normalizedCode);
    const QString staticTranslation = translate(staticId);
    if (staticTranslation != normalizedCode) {
        return staticTranslation;
    }
    return formattedCityCode(normalizedCode);
}

void apiTextUtils::setTextTranslations(const QJsonObject &translations)
{
    QHash<QString, QString> newTranslations;
    for (auto it = translations.constBegin(); it != translations.constEnd(); ++it) {
        const QString id = it.key().trimmed();
        const QString displayText = it.value().toString().trimmed();
        if (!id.isEmpty() && !displayText.isEmpty()) {
            newTranslations.insert(id, displayText);
        }
    }

    QWriteLocker locker(&textTranslationsLock);
    textTranslations = std::move(newTranslations);
}

void apiTextUtils::setCityTranslations(const QJsonObject &translations)
{
    QHash<QString, QString> newTranslations;
    for (auto it = translations.constBegin(); it != translations.constEnd(); ++it) {
        const QString code = it.key().trimmed();
        const QString displayName = it.value().toString().trimmed();
        if (!code.isEmpty() && !displayName.isEmpty()) {
            newTranslations.insert(code, displayName);
        }
    }

    QWriteLocker locker(&cityTranslationsLock);
    cityTranslations = std::move(newTranslations);
}
