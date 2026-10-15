#import "oauthlauncher.h"

#if defined(Q_OS_IOS) || defined(Q_OS_MACOS)

#import <Foundation/Foundation.h>
#import <AuthenticationServices/AuthenticationServices.h>

#if defined(Q_OS_IOS)
#import <UIKit/UIKit.h>
#elif defined(Q_OS_MACOS)
#import <AppKit/AppKit.h>
#endif

#include <QPointer>
#include <QDebug>

@class OAuthSessionBridge;

static OAuthSessionBridge *s_bridge = nil;

@interface OAuthSessionBridge : NSObject
#if defined(Q_OS_IOS) || defined(Q_OS_MACOS)
    <ASWebAuthenticationPresentationContextProviding>
#endif
@property (nonatomic, assign) QPointer<OAuthLauncher> launcher;
@property (nonatomic, strong) ASWebAuthenticationSession *session;
@end

@implementation OAuthSessionBridge
#if defined(Q_OS_IOS)
- (ASPresentationAnchor)presentationAnchorForWebAuthenticationSession:(ASWebAuthenticationSession *)session
{
    (void)session;
    UIApplication *application = [UIApplication sharedApplication];
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in application.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }

            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow) {
                    return window;
                }
            }
        }
    }

    return application.windows.firstObject;
}
#elif defined(Q_OS_MACOS)
- (ASPresentationAnchor)presentationAnchorForWebAuthenticationSession:(ASWebAuthenticationSession *)session
{
    (void)session;

    NSApplication *application = [NSApplication sharedApplication];
    for (NSWindow *window in application.windows) {
        if (window.isVisible) {
            return window;
        }
    }

    return application.keyWindow ?: application.mainWindow;
}
#endif
@end

NSString *toNSString(const QString &value)
{
    return [NSString stringWithUTF8String:value.toUtf8().constData()];
}

bool startAppleOAuthSession(OAuthLauncher *launcher, const QUrl &url, QString *errorMessage)
{
    qDebug() << "startAppleOAuthSession called with URL:" << url;

    if (!launcher) {
        if (errorMessage) {
            *errorMessage = QStringLiteral("OAuth launcher is unavailable");
        }
        qWarning() << "startAppleOAuthSession aborted: launcher is null";
        return false;
    }

    if (!s_bridge) {
        s_bridge = [OAuthSessionBridge new];
    }

    if (s_bridge.session) {
        [s_bridge.session cancel];
        s_bridge.session = nil;
    }

    s_bridge.launcher = launcher;

    NSURL *authUrl = [NSURL URLWithString:toNSString(url.toString())];
    if (!authUrl) {
        if (errorMessage) {
            *errorMessage = QStringLiteral("Invalid OAuth login URL");
        }
        qWarning() << "startAppleOAuthSession aborted: invalid auth URL" << url;
        return false;
    }

    qDebug() << "Creating ASWebAuthenticationSession with callback scheme amnezia";

    ASWebAuthenticationSession *session = [[ASWebAuthenticationSession alloc]
        initWithURL:authUrl
        callbackURLScheme:@"amnezia"
        completionHandler:^(NSURL * _Nullable callbackURL, NSError * _Nullable error) {
            OAuthLauncher *target = s_bridge.launcher;
            s_bridge.session = nil;

            if (callbackURL) {
                qDebug() << "ASWebAuthenticationSession completed with callback URL:"
                         << QString::fromUtf8(callbackURL.absoluteString.UTF8String);
            }

            if (error) {
                qWarning() << "ASWebAuthenticationSession finished with error code" << error.code
                           << ":" << QString::fromUtf8(error.localizedDescription.UTF8String);
            }

            if (!target) {
                qWarning() << "ASWebAuthenticationSession completion ignored: launcher target lost";
                return;
            }

            if (callbackURL) {
                target->notifyCallbackReceived(QString::fromUtf8(callbackURL.absoluteString.UTF8String));
                return;
            }

            if (error && error.code == ASWebAuthenticationSessionErrorCodeCanceledLogin) {
                target->notifyCanceled();
                return;
            }

            const QString message = error
                ? QString::fromUtf8(error.localizedDescription.UTF8String)
                : QStringLiteral("OAuth login failed");
            target->notifyLaunchFailed(message);
        }];

#if defined(Q_OS_IOS)
    if (@available(iOS 13.0, *)) {
        session.presentationContextProvider = s_bridge;
    }
#elif defined(Q_OS_MACOS)
    if (@available(macOS 10.15, *)) {
        session.presentationContextProvider = s_bridge;
    }
#endif

    if (@available(iOS 13.0, macOS 10.15, *)) {
        session.prefersEphemeralWebBrowserSession = NO;
    }

#if defined(Q_OS_MACOS)
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    qDebug() << "Activated macOS application before starting ASWebAuthenticationSession";
#endif

    s_bridge.session = session;
    const BOOL started = [session start];
    qDebug() << "ASWebAuthenticationSession start returned:" << started;
    if (!started) {
        s_bridge.session = nil;
        if (errorMessage) {
            *errorMessage = QStringLiteral("Failed to start native OAuth session");
        }
        qWarning() << "ASWebAuthenticationSession failed to start";
        return false;
    }

    return true;
}

#endif
