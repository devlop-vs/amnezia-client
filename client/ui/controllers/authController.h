#ifndef AUTHCONTROLLER_H
#define AUTHCONTROLLER_H

#include <QObject>
#include <QNetworkAccessManager>

class SecureQSettings;

class AuthController : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool isLoggedIn READ isLoggedIn NOTIFY loginStateChanged)
    Q_PROPERTY(QString userEmail READ userEmail NOTIFY userInfoChanged)
    Q_PROPERTY(QString userId READ userId NOTIFY userInfoChanged)

public:
    explicit AuthController(SecureQSettings *settings, QNetworkAccessManager *nam,
                            QObject *parent = nullptr);

    bool isLoggedIn() const;
    QString userEmail() const;
    QString userId() const;

    Q_INVOKABLE QString getLoginUrl();
    Q_INVOKABLE void handleOAuthCallback(const QString &url);
    Q_INVOKABLE void logout();

    void handleDeepLink(const QUrl &url);

signals:
    void loginStateChanged();
    void userInfoChanged();
    void loginSuccess(const QString &email);
    void loginFailed(const QString &error);

private:
    void exchangeCodeForToken(const QString &code, const QString &state, const QString &codeVerifier);
    void fetchUserInfo(const QString &accessToken);
    QString generateCodeVerifier();

    SecureQSettings *m_settings;
    QNetworkAccessManager *m_nam;

    QString m_codeVerifier;
    QString m_accessToken;
    QString m_refreshToken;
    QString m_userEmail;
    QString m_userId;

    static const QString kAuthBaseUrl;
    static const QString kClientId;
    static const QString kRedirectUri;
    static const QString kState;
};

#endif // AUTHCONTROLLER_H
