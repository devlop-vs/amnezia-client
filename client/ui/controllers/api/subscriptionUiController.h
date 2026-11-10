#ifndef SUBSCRIPTIONUICONTROLLER_H
#define SUBSCRIPTIONUICONTROLLER_H

#include <QObject>
#include <QHash>
#include <QQueue>
#include <QSet>

class QAbstractSocket;

#include "core/controllers/serversController.h"
#include "core/controllers/settingsController.h"
#include "core/controllers/connectionController.h"
#include "core/controllers/api/servicesCatalogController.h"
#include "core/controllers/api/subscriptionController.h"
#include "ui/models/api/apiSubscriptionPlansModel.h"
#include "ui/models/api/apiBenefitsModel.h"
#include "ui/models/api/apiServicesModel.h"
#include "ui/models/api/apiAccountInfoModel.h"
#include "ui/models/api/apiCountryModel.h"
#include "ui/models/api/apiDevicesModel.h"

class SubscriptionUiController : public QObject
{
    Q_OBJECT
public:
    SubscriptionUiController(ServersController* serversController,
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
                         QObject *parent = nullptr);

    Q_PROPERTY(QList<QString> qrCodes READ getQrCodes NOTIFY vpnKeyExportReady)
    Q_PROPERTY(int qrCodesCount READ getQrCodesCount NOTIFY vpnKeyExportReady)
    Q_PROPERTY(QString vpnKey READ getVpnKey NOTIFY vpnKeyExportReady)
    Q_PROPERTY(QString loginAccountSubscriptionState READ loginAccountSubscriptionState
               NOTIFY loginAccountSubscriptionStateChanged)

public slots:
    bool exportNativeConfig(const QString &serverId, const QString &serverCountryCode, const QString &fileName);
    bool revokeNativeConfig(const QString &serverId, const QString &serverCountryCode);
    bool exportVpnKey(const QString &serverId, const QString &fileName);
    void prepareVpnKeyExport(const QString &serverId);
    void copyVpnKeyToClipboard();

    bool fillAvailableServices();
    bool importPremiumFromAppStore(const QString &storeProductId);
    bool importPremiumFromGooglePlay(const QString &storeProductId, const QString &storeProductType,
                                     const QString &googlePlayBasePlanId);
    bool importFreeFromGateway();
    bool restoreServiceFromAppStore();
    bool importTrialFromGateway(const QString &email);
    bool updateServiceFromGateway(const QString &serverId, const QString &newCountryCode, const QString &newCountryName,
                                  bool reloadServiceConfig = false, const QString &serviceProtocolOverride = QString(),
                                  const QString &newCityCode = QString(), const QString &newCityName = QString());
    bool resetServiceClientIdentity(const QString &serverId);
    bool deactivateDevice(const QString &serverId);
    bool deactivateExternalDevice(const QString &serverId, const QString &uuid, const QString &serverCountryCode);

    void validateConfig(const QString &serverId);
    void notifyWireGuardPeerDisconnected(const QString &serverId);

    void setCurrentProtocol(const QString &serverId, const QString &protocolName);
    bool isVlessProtocol(const QString &serverId);

    bool isCaptchaAwaitingUser() const;
    void onCaptchaSolved(const QString &captchaId, const QString &solution);
    void onRefreshCaptchaRequested();

    void removeApiConfig(const QString &serverId);

    void removeServer(const QString &serverId);

    bool getAccountInfo(const QString &serverId, bool reload);
    bool getAccountInfoByEmail(const QString &email);
    void getRenewalLink(const QString &serverId);

    void updateApiCountryModel();
    void refreshApiCountryModelFromServer(const QString &serverId);
    void updateApiDevicesModel();
    void refreshTextLocalizations();
    void refreshCityLocalizations();
    void refreshNodeQuality();
    void stopNodeQualityMonitoring();

signals:
    void configValidated(const QString &serverId, bool isValid);
    void errorOccurred(ErrorCode errorCode);
    void trialEmailError(const QString &message);
    void subscriptionExpiredOnServer();
    void renewalLinkReceived(const QString &url);

    void installServerFromApiFinished(const QString &message, int preferredDefaultServerIndex = -1);
    void changeApiCountryFinished(const QString &message);
    void reloadServerFromApiFinished(const QString &message);
    void resetServiceClientIdentityFailed(const QString &message);
    void updateServerFromApiFinished();
    void subscriptionRefreshNeeded();
    void loginAccountSubscriptionStateChanged();
    void accountInfoByEmailFinished();

    void apiConfigRemoved(const QString &message);
    void apiServerRemoved(const QString &message);

    void vpnKeyExportReady();
    void captchaRequired(const QString &captchaId, const QString &captchaImageBase64, const QString &hint);
    void captchaFlowDismissRequested();

    void unsupportedConnectDrawerRequested();

private:
    struct CaptchaState {
        QString userCountryCode;
        QString serviceType;
        QString serviceProtocol;
        QString openvpnPrivKey;
        QString wireguardClientPrivKey;
        QString wireguardClientPubKey;
        QString xrayUuid;
        bool isPending = false;
    } m_captchaState;

private:
    QList<QString> getQrCodes();
    int getQrCodesCount();
    QString getVpnKey();
    QString loginAccountSubscriptionState() const;
    void setLoginAccountSubscriptionState(const QString &state);
    void handleAccountLookupFinished(
        ErrorCode errorCode,
        const SubscriptionController::AccountLookupResult &result);
    QString googlePlayPlanKey(const QString &productId, const QString &productType, const QString &googlePlayBasePlanId) const;
    void refreshGooglePlayMinPriceLabel();
    struct GooglePlayMonthlyQuote {
        QString label;
        qlonglong amountMicros = 0;
    };

    struct NodeProbeJob {
        SubscriptionController::NodeHealthInfo health;
        int attempt = 0;
        quint64 generation = 0;
        QList<int> successfulLatencies;
    };

    struct NodeQualityHistory {
        double emaScore = -1.0;
        int signalBars = 0;
        int consecutiveFailedBatches = 0;
    };

    QString nodeQualityKey(const SubscriptionController::NodeHealthInfo &health) const;
    int signalBarsWithHysteresis(double score, int currentBars) const;
    void startPendingNodeProbes();
    void probeNode(const NodeProbeJob &job);
    void probeTcpNode(const NodeProbeJob &job);
    void probeUdpNode(const NodeProbeJob &job);
    void completeNodeProbe(NodeProbeJob job, int latencyMs);
    void publishNodeQuality(const NodeProbeJob &job);

    QList<QString> m_qrCodes;
    QString m_vpnKey;
    QHash<QString, GooglePlayMonthlyQuote> m_googlePlayMonthlyPriceLabels;
    QString m_loginAccountSubscriptionState = QStringLiteral("unknown");
    QQueue<NodeProbeJob> m_nodeProbeQueue;
    QSet<QAbstractSocket *> m_activeNodeProbeSockets;
    QHash<QString, NodeQualityHistory> m_nodeQualityHistory;
    int m_activeNodeProbes = 0;
    quint64 m_nodeProbeGeneration = 0;

    ServersController* m_serversController;
    ApiServicesModel* m_apiServicesModel;
    ServicesCatalogController* m_servicesCatalogController;
    SubscriptionController* m_subscriptionController;
    ApiSubscriptionPlansModel* m_apiSubscriptionPlansModel;
    ApiBenefitsModel* m_apiBenefitsModel;
    ApiAccountInfoModel* m_apiAccountInfoModel;
    ApiCountryModel* m_apiCountryModel;
    ApiDevicesModel* m_apiDevicesModel;
    SettingsController* m_settingsController;
    ConnectionController* m_connectionController;
};

#endif // SUBSCRIPTIONUICONTROLLER_H
