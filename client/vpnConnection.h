#ifndef VPNCONNECTION_H
#define VPNCONNECTION_H

#include <QElapsedTimer>
#include <QObject>
#include <QMetaObject>
#include <QString>
#include <QScopedPointer>
#include <QRemoteObjectNode>
#include <QTimer>

#include "core/protocols/vpnProtocol.h"
#include "core/utils/errorCodes.h"
#include "core/utils/routeModes.h"
#include "core/utils/commonStructs.h"
#include "core/repositories/secureServersRepository.h"
#include "core/repositories/secureAppSettingsRepository.h"

#ifdef AMNEZIA_DESKTOP
#include "core/utils/ipcClient.h"
#endif

#ifdef Q_OS_ANDROID
#include "core/protocols/androidVpnProtocol.h"
#endif

using namespace amnezia;

class VpnConnection : public QObject
{
    Q_OBJECT

public:
    explicit VpnConnection(SecureServersRepository* serversRepository, SecureAppSettingsRepository* appSettingsRepository, QObject* parent = nullptr);
    ~VpnConnection() override;

    static QString bytesPerSecToText(quint64 bytes);

    ErrorCode lastError() const;
    Vpn::ConnectionState connectionState() const;

    QSharedPointer<VpnProtocol> vpnProtocol() const;

    const QString &remoteAddress() const;
    void addSitesRoutes(const QString &gw, amnezia::RouteMode mode);

#ifdef Q_OS_ANDROID
    void restoreConnection();
#endif

public slots:
    void setRepositories(SecureServersRepository* serversRepository, SecureAppSettingsRepository* appSettingsRepository);
    void connectToVpn(const QString &serverId, DockerContainer container, const QJsonObject &vpnConfiguration);
    void reconnectToVpn();
    void disconnectFromVpn();

    void onKillSwitchModeChanged(bool enabled);
    void disconnectSlots();

    void setConnectionState(Vpn::ConnectionState state);

signals:
    void trafficUpdated(quint64 receivedDeltaBytes, quint64 sentDeltaBytes,
                        quint64 receivedBytesPerSecond, quint64 sentBytesPerSecond);
    void connectionStateChanged(Vpn::ConnectionState state);
    void vpnProtocolError(amnezia::ErrorCode error);

    void serviceIsNotReady();

protected slots:
    void onTrafficUpdated(quint64 receivedDeltaBytes, quint64 sentDeltaBytes,
                          quint64 receivedBytesPerSecond, quint64 sentBytesPerSecond);
#ifdef Q_OS_ANDROID
    void onAndroidStatisticsUpdated(quint64 receivedDeltaBytes, quint64 sentDeltaBytes,
                                    quint64 receivedBytesPerSecond, quint64 sentBytesPerSecond,
                                    quint64 sessionReceivedBytes, quint64 sessionSentBytes,
                                    qint64 connectedSinceEpochMs);
#endif
    void onConnectionStateChanged(Vpn::ConnectionState state);

protected:
    QSharedPointer<VpnProtocol> m_vpnProtocol;

private:
    SecureServersRepository* m_serversRepository;
    SecureAppSettingsRepository* m_appSettingsRepository;

    QJsonObject m_vpnConfiguration;
    QJsonObject m_routeMode;
    QString m_remoteAddress;

    // Only for iOS for now, check counters
    QTimer m_checkTimer;
    QElapsedTimer m_iosTrafficUpdateTimer;

#ifdef Q_OS_ANDROID
    qint64 m_androidConnectedSinceEpochMs = 0;
    quint64 m_androidAccountedSessionRxBytes = 0;
    quint64 m_androidAccountedSessionTxBytes = 0;
    AndroidVpnProtocol* createDefaultAndroidVpnProtocol();
#endif

    Vpn::ConnectionState m_connectionState = Vpn::ConnectionState::Disconnected;

   void createProtocolConnections();

   void appendSplitTunnelingConfig();
   void appendKillSwitchConfig();
};

#endif // VPNCONNECTION_H
