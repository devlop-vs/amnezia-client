#include "oauthlauncher.h"

#include <QDesktopServices>

#if defined(Q_OS_ANDROID)
#include "platforms/android/android_controller.h"
#elif defined(Q_OS_IOS)
#include "platforms/ios/ios_controller.h"
#endif

namespace
{
OAuthLauncher *s_instance = nullptr;
}

OAuthLauncher::OAuthLauncher(QObject *parent)
    : QObject(parent)
{
}

OAuthLauncher *OAuthLauncher::instance()
{
    if (!s_instance) {
        s_instance = new OAuthLauncher();
    }

    return s_instance;
}

bool OAuthLauncher::start(const QUrl &url, QString *errorMessage)
{
#if defined(Q_OS_ANDROID)
    return AndroidController::instance()->startOAuthLogin(url, errorMessage);
#elif defined(Q_OS_IOS) || defined(Q_OS_MACOS)
    return startAppleOAuthSession(this, url, errorMessage);
#else
    const bool ok = QDesktopServices::openUrl(url);
    if (!ok && errorMessage) {
        *errorMessage = QStringLiteral("Failed to open OAuth login page");
    }
    return ok;
#endif
}

void OAuthLauncher::notifyCallbackReceived(const QString &url)
{
    emit callbackReceived(url);
}

void OAuthLauncher::notifyCanceled()
{
    emit loginCanceled();
}

void OAuthLauncher::notifyLaunchFailed(const QString &errorMessage)
{
    emit launchFailed(errorMessage);
}
