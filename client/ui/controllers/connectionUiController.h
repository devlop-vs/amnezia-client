#ifndef CONNECTIONUICONTROLLER_H
#define CONNECTIONUICONTROLLER_H

#include <QDate>
#include <QDateTime>
#include <QObject>
#include <QTimer>

#include "core/controllers/connectionController.h"
#include "core/repositories/secureAppSettingsRepository.h"
#include "core/utils/errorCodes.h"
#include "core/utils/routeModes.h"
#include "core/utils/commonStructs.h"
#include "core/protocols/vpnProtocol.h"
#include "core/controllers/serversController.h"

class ConnectionUiController : public QObject
{
    Q_OBJECT

public:
    Q_PROPERTY(bool isConnected READ isConnected NOTIFY connectionStateChanged)
    Q_PROPERTY(bool isConnectionInProgress READ isConnectionInProgress NOTIFY connectionStateChanged)
    Q_PROPERTY(QString connectionStateText READ connectionStateText NOTIFY connectionStateChanged)
    Q_PROPERTY(QString downloadSpeedText READ downloadSpeedText NOTIFY speedChanged)
    Q_PROPERTY(QString uploadSpeedText READ uploadSpeedText NOTIFY speedChanged)
    Q_PROPERTY(QString connectionDurationText READ connectionDurationText NOTIFY connectionDurationChanged)
    Q_PROPERTY(QString connectionServerId READ connectionServerId NOTIFY connectionStateChanged)
    Q_PROPERTY(QString todayProtectedDurationText READ todayProtectedDurationText NOTIFY usageStatsChanged)
    Q_PROPERTY(QString todayProtectedVolumeText READ todayProtectedVolumeText NOTIFY usageStatsChanged)
    Q_PROPERTY(QString monthProtectedDurationText READ monthProtectedDurationText NOTIFY usageStatsChanged)
    Q_PROPERTY(QString monthProtectedVolumeText READ monthProtectedVolumeText NOTIFY usageStatsChanged)

    explicit ConnectionUiController(ConnectionController* connectionController,
                                    ServersController* serversController,
                                    SecureAppSettingsRepository* appSettingsRepository,
                                    QObject *parent = nullptr);

    ~ConnectionUiController() = default;

    bool isConnected() const;
    bool isConnectionInProgress() const;
    QString connectionStateText() const;
    QString downloadSpeedText() const;
    QString uploadSpeedText() const;
    QString connectionDurationText() const;
    QString connectionServerId() const;
    QString todayProtectedDurationText() const;
    QString todayProtectedVolumeText() const;
    QString monthProtectedDurationText() const;
    QString monthProtectedVolumeText() const;

public slots:
    void toggleConnection();

    void openConnection();
    void openConnectionForServer(const QString &serverId);
    void closeConnection();
    void clearPendingConnectionServer();

    bool isRevokeBlockedDuringActiveConnection(const QString &serverId, int containerIndex, const QString &clientId) const;

    ErrorCode getLastConnectionError();
    void onConnectionStateChanged(Vpn::ConnectionState state);
    void onTrafficUpdated(quint64 receivedDeltaBytes, quint64 sentDeltaBytes,
                          quint64 receivedBytesPerSecond, quint64 sentBytesPerSecond);
    void updateConnectionDuration();

    void onTranslationsUpdated();

signals:
    void connectionStateChanged();
    void speedChanged();
    void connectionDurationChanged();
    void usageStatsChanged();

    void connectionErrorOccurred(ErrorCode errorCode);

    void connectButtonClicked();
    void preparingConfig();
    void prepareConfig(const QString &serverId);
    void peerDisconnectNotificationRequested(const QString &serverId);
    void unsupportedConnectDrawerRequested();
    void noInstalledContainers();

private:
    Vpn::ConnectionState getCurrentConnectionState();
    void notifyConnectionBlocked(ErrorCode errorCode);
    QString formatConnectionDuration(qint64 durationMs) const;
    qint64 currentConnectionDurationMs() const;
    void resumeConnectionDuration();
    void pauseConnectionDuration();
    void loadUsageStats(const QDateTime &now);
    void rollUsagePeriods(const QDateTime &now);
    void addProtectedDuration(qint64 fromEpochMs, qint64 toEpochMs);
    void persistUsageStats(bool force = false);
    QString formatProtectedDuration(qint64 durationMs) const;
    QString formatProtectedVolume(quint64 bytes) const;
    QString monthKey(const QDate &date) const;

    ConnectionController* m_connectionController;
    ServersController* m_serversController;
    SecureAppSettingsRepository* m_appSettingsRepository;

    bool m_isConnected = false;
    bool m_isConnectionInProgress = false;
    QString m_connectionStateText = tr("Connect");
    QString m_downloadSpeedText = QStringLiteral("0 Mbps");
    QString m_uploadSpeedText = QStringLiteral("0 Mbps");
    QString m_connectionDurationText = QStringLiteral("00:00:00");
    QTimer m_connectionDurationTimer;
    qint64 m_accumulatedConnectionDurationMs = 0;
    qint64 m_connectionDurationStartedAtMs = 0;
    bool m_isConnectionDurationActive = false;
    QDate m_usageDate;
    QString m_usageMonth;
    VpnUsagePeriod m_dailyUsage;
    VpnUsagePeriod m_monthlyUsage;
    qint64 m_lastUsageUpdateEpochMs = 0;
    qint64 m_lastUsagePersistenceEpochMs = 0;
    bool m_usageStatsDirty = false;
    QString m_connectionServerId;
    bool m_notifyPeerDisconnectOnDisconnected = false;

    Vpn::ConnectionState m_state;
};

#endif
