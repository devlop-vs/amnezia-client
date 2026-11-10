#ifndef APITEXTUTILS_H
#define APITEXTUTILS_H

#include <QJsonObject>
#include <QString>

namespace apiTextUtils
{
QString translate(const QString &value);
QString translateCity(const QString &cityCode, const QString &fallbackName = QString());
void setTextTranslations(const QJsonObject &translations);
void setCityTranslations(const QJsonObject &translations);
}

#endif // APITEXTUTILS_H
