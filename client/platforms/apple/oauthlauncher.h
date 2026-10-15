#ifndef OAUTHLAUNCHER_H
#define OAUTHLAUNCHER_H

#include <QObject>
#include <QUrl>

class QString;

class OAuthLauncher : public QObject
{
    Q_OBJECT

public:
    static OAuthLauncher *instance();

    bool start(const QUrl &url, QString *errorMessage = nullptr);

    void notifyCallbackReceived(const QString &url);
    void notifyCanceled();
    void notifyLaunchFailed(const QString &errorMessage);

signals:
    void callbackReceived(const QString &url);
    void loginCanceled();
    void launchFailed(const QString &errorMessage);

private:
    explicit OAuthLauncher(QObject *parent = nullptr);
};

#if defined(Q_OS_IOS) || defined(Q_OS_MACOS)
bool startAppleOAuthSession(OAuthLauncher *launcher, const QUrl &url, QString *errorMessage);
#endif

#endif // OAUTHLAUNCHER_H
