#include "authController.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QRandomGenerator>
#include <QUrl>
#include <QUrlQuery>
#include <QDebug>

#include "secureQSettings.h"

const QString AuthController::kAuthBaseUrl = QStringLiteral("http://104.160.47.217:38080");
const QString AuthController::kClientId = QStringLiteral("amnezia-vpn-client");
const QString AuthController::kRedirectUri = QStringLiteral("amnezia://oauth/callback");
const QString AuthController::kState = QStringLiteral("1001");

AuthController::AuthController(SecureQSettings *settings, QNetworkAccessManager *nam, QObject *parent)
    : QObject(parent), m_settings(settings), m_nam(nam)
{
    // Restore saved login state
    m_accessToken = m_settings->value("Auth/accessToken").toString();
    m_refreshToken = m_settings->value("Auth/refreshToken").toString();
    m_userEmail = m_settings->value("Auth/userEmail").toString();
    m_userId = m_settings->value("Auth/userId").toString();
}

bool AuthController::isLoggedIn() const
{
    return !m_accessToken.isEmpty() && !m_userEmail.isEmpty();
}

QString AuthController::userEmail() const
{
    return m_userEmail;
}

QString AuthController::userId() const
{
    return m_userId;
}

QString AuthController::generateCodeVerifier()
{
    const QString chars = QStringLiteral("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~");
    QString verifier;
    verifier.reserve(64);
    auto *rng = QRandomGenerator::global();
    for (int i = 0; i < 64; ++i) {
        verifier.append(chars.at(rng->bounded(chars.length())));
    }
    return verifier;
}

QString AuthController::getLoginUrl()
{
    m_codeVerifier = generateCodeVerifier();

    QUrl url(kAuthBaseUrl + "/static/native-callback-login.html");
    QUrlQuery query;
    query.addQueryItem("state", kState);
    query.addQueryItem("client_id", kClientId);
    query.addQueryItem("redirect_uri", kRedirectUri);
    query.addQueryItem("code_verifier", m_codeVerifier);
    url.setQuery(query);

    return url.toString();
}

void AuthController::handleOAuthCallback(const QString &urlString)
{
    qDebug() << "AuthController::handleOAuthCallback url:" << urlString;

    QUrl url(urlString);
    QUrlQuery query(url.query());

    QString code = query.queryItemValue("code");
    QString state = query.queryItemValue("state");
    QString codeVerifier = query.queryItemValue("code_verifier");

    qDebug() << "OAuth callback parsed - code:" << code << "state:" << state
             << "codeVerifier from URL:" << codeVerifier << "stored verifier:" << m_codeVerifier;

    if (code.isEmpty()) {
        emit loginFailed("No authorization code received");
        return;
    }

    // Use the code_verifier from callback if present, otherwise use stored one
    if (codeVerifier.isEmpty()) {
        codeVerifier = m_codeVerifier;
    }

    exchangeCodeForToken(code, state, codeVerifier);
}

void AuthController::handleDeepLink(const QUrl &url)
{
    qDebug() << "AuthController::handleDeepLink - scheme:" << url.scheme()
             << "host:" << url.host() << "path:" << url.path() << "full:" << url.toString();

    if (url.scheme() == "amnezia" && url.host() == "oauth" && url.path() == "/callback") {
        handleOAuthCallback(url.toString());
    } else {
        qWarning() << "handleDeepLink: URL did not match expected pattern";
    }
}

void AuthController::exchangeCodeForToken(const QString &code, const QString &state, const QString &codeVerifier)
{
    QUrl url(kAuthBaseUrl + "/v1/auth/token");
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    QJsonObject body;
    body["code"] = code;
    body["state"] = state;
    body["code_verifier"] = codeVerifier;
    body["client_id"] = kClientId;
    body["redirect_uri"] = kRedirectUri;
    body["grant_type"] = "authorization_code";

    QNetworkReply *reply = m_nam->post(request, QJsonDocument(body).toJson());
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            qWarning() << "Token exchange failed:" << reply->errorString();
            emit loginFailed(reply->errorString());
            return;
        }

        QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        QJsonObject obj = doc.object();

        m_accessToken = obj["access_token"].toString();
        m_refreshToken = obj["refresh_token"].toString();
        QString tokenType = obj["token_type"].toString();
        int expiresIn = obj["expires_in"].toInt();

        if (m_accessToken.isEmpty()) {
            emit loginFailed("No access token in response");
            return;
        }

        // Save tokens
        m_settings->setValue("Auth/accessToken", m_accessToken);
        m_settings->setValue("Auth/refreshToken", m_refreshToken);
        m_settings->setValue("Auth/tokenType", tokenType);
        m_settings->setValue("Auth/expiresIn", expiresIn);

        emit loginStateChanged();

        // Fetch user info
        fetchUserInfo(m_accessToken);
    });
}

void AuthController::fetchUserInfo(const QString &accessToken)
{
    QUrl url(kAuthBaseUrl + "/v1/auth/userinfo");
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setRawHeader("Authorization", ("Bearer " + accessToken).toUtf8());

    QJsonObject body;
    body["access_token"] = accessToken;

    QNetworkReply *reply = m_nam->post(request, QJsonDocument(body).toJson());
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            qWarning() << "Userinfo request failed:" << reply->errorString();
            emit loginFailed(reply->errorString());
            return;
        }

        QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        QJsonObject obj = doc.object();

        m_userId = obj["user_id"].toString();
        m_userEmail = obj["email"].toString();

        if (m_userEmail.isEmpty()) {
            emit loginFailed("No email in userinfo response");
            return;
        }

        // Save user info
        m_settings->setValue("Auth/userId", m_userId);
        m_settings->setValue("Auth/userEmail", m_userEmail);

        emit userInfoChanged();
        emit loginSuccess(m_userEmail);
    });
}

void AuthController::logout()
{
    m_accessToken.clear();
    m_refreshToken.clear();
    m_userEmail.clear();
    m_userId.clear();

    m_settings->remove("Auth/accessToken");
    m_settings->remove("Auth/refreshToken");
    m_settings->remove("Auth/tokenType");
    m_settings->remove("Auth/expiresIn");
    m_settings->remove("Auth/userId");
    m_settings->remove("Auth/userEmail");

    emit loginStateChanged();
    emit userInfoChanged();
}
