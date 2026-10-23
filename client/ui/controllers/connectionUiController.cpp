#include "connectionUiController.h"

#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS) || defined(MACOS_NE)
    #include <QGuiApplication>
#else
    #include <QApplication>
#endif

#include <QDateTime>

#include "amneziaApplication.h"
#include "core/controllers/serversController.h"
#include "core/models/containerConfig.h"
#include "core/utils/containerEnum.h"

ConnectionUiController::ConnectionUiController(ConnectionController* connectionController,
                                                ServersController* serversController,
                                                QObject *parent)
    : QObject(parent),
      m_connectionController(connectionController),
      m_serversController(serversController)
{
    connect(m_connectionController, &ConnectionController::connectionStateChanged, this, &ConnectionUiController::onConnectionStateChanged);
    connect(m_connectionController, &ConnectionController::bytesChanged, this, &ConnectionUiController::onBytesChanged);

    connect(this, &ConnectionUiController::connectButtonClicked, this, &ConnectionUiController::toggleConnection, Qt::QueuedConnection);

    m_connectionDurationTimer.setInterval(1000);
    connect(&m_connectionDurationTimer, &QTimer::timeout, this, &ConnectionUiController::updateConnectionDuration);

    m_state = Vpn::ConnectionState::Disconnected;
}

void ConnectionUiController::openConnection()
{
    const QString serverId = m_serversController->getDefaultServerId();
    openConnectionForServer(serverId);
}

void ConnectionUiController::openConnectionForServer(const QString &serverId)
{
    if (serverId.isEmpty()) {
        m_connectionController->setConnectionState(Vpn::ConnectionState::Disconnected);
        return;
    }

    m_connectionServerId = serverId;

    ErrorCode errorCode = m_connectionController->openConnection(serverId);

    if (errorCode != ErrorCode::NoError) {
        m_connectionServerId.clear();
        m_connectionController->setConnectionState(Vpn::ConnectionState::Disconnected);
        notifyConnectionBlocked(errorCode);
        return;
    }
}

void ConnectionUiController::closeConnection()
{
    // This is the single public/manual disconnect entry point, including calls
    // made directly from QML. Preserve the active session identity until the
    // local VPN reports Disconnected, then send the advisory peer cleanup.
    m_notifyPeerDisconnectOnDisconnected = !m_connectionServerId.isEmpty();
    qWarning() << "ConnectionUiController::closeConnection"
               << "serverId=" << m_connectionServerId
               << "notifyPeerDisconnect=" << m_notifyPeerDisconnectOnDisconnected;
    m_connectionController->closeConnection();
}

void ConnectionUiController::clearPendingConnectionServer()
{
    if (m_state == Vpn::ConnectionState::Preparing) {
        m_connectionServerId.clear();
    }
}

ErrorCode ConnectionUiController::getLastConnectionError()
{
    return m_connectionController->lastConnectionError();
}

void ConnectionUiController::onConnectionStateChanged(Vpn::ConnectionState state)
{
    qWarning() << "ConnectionUiController::onConnectionStateChanged state=" << static_cast<int>(state);
    m_state = state;

    m_isConnected = false;
    m_connectionStateText = tr("Connecting...");
    switch (state) {
    case Vpn::ConnectionState::Connected: {
        amnApp->networkManager()->clearConnectionCache();

        m_isConnectionInProgress = false;
        m_isConnected = true;
        m_connectionStateText = tr("Connected");
        resumeConnectionDuration();
        break;
    }
    case Vpn::ConnectionState::Connecting: {
        m_isConnectionInProgress = true;
        pauseConnectionDuration();
        m_downloadSpeedText = VpnConnection::bytesPerSecToText(0);
        m_uploadSpeedText = VpnConnection::bytesPerSecToText(0);
        emit speedChanged();
        break;
    }
    case Vpn::ConnectionState::Reconnecting: {
        m_isConnectionInProgress = true;
        m_connectionStateText = tr("Reconnecting...");
        pauseConnectionDuration();
        break;
    }
    case Vpn::ConnectionState::Disconnected: {
        m_isConnectionInProgress = false;
        m_connectionStateText = tr("Connect");
        pauseConnectionDuration();
        m_downloadSpeedText = VpnConnection::bytesPerSecToText(0);
        m_uploadSpeedText = VpnConnection::bytesPerSecToText(0);
        emit speedChanged();
        qWarning() << "ConnectionUiController::onConnectionStateChanged: disconnected"
                   << "serverId=" << m_connectionServerId
                   << "notifyPeerDisconnect=" << m_notifyPeerDisconnectOnDisconnected;
        if (m_notifyPeerDisconnectOnDisconnected && !m_connectionServerId.isEmpty()) {
            const QString disconnectedServerId = m_connectionServerId;
            m_notifyPeerDisconnectOnDisconnected = false;
            m_connectionServerId.clear();
            qWarning() << "ConnectionUiController::onConnectionStateChanged: requesting peer disconnect notification"
                       << "serverId=" << disconnectedServerId;
            emit peerDisconnectNotificationRequested(disconnectedServerId);
        }
        break;
    }
    case Vpn::ConnectionState::Disconnecting: {
        m_isConnectionInProgress = true;
        m_connectionStateText = tr("Disconnecting...");
        pauseConnectionDuration();
        break;
    }
    case Vpn::ConnectionState::Preparing: {
        m_isConnectionInProgress = true;
        m_connectionStateText = tr("Preparing...");
        pauseConnectionDuration();
        break;
    }
    case Vpn::ConnectionState::Error: {
        m_isConnectionInProgress = false;
        m_connectionStateText = tr("Connect");
        pauseConnectionDuration();
        m_downloadSpeedText = VpnConnection::bytesPerSecToText(0);
        m_uploadSpeedText = VpnConnection::bytesPerSecToText(0);
        emit speedChanged();
        emit connectionErrorOccurred(getLastConnectionError());
        break;
    }
    case Vpn::ConnectionState::Unknown: {
        m_isConnectionInProgress = false;
        m_connectionStateText = tr("Connect");
        pauseConnectionDuration();
        m_downloadSpeedText = VpnConnection::bytesPerSecToText(0);
        m_uploadSpeedText = VpnConnection::bytesPerSecToText(0);
        emit speedChanged();
        emit connectionErrorOccurred(getLastConnectionError());
        break;
    }
    }
    emit connectionStateChanged();
}

void ConnectionUiController::onBytesChanged(quint64 receivedBytes, quint64 sentBytes)
{
    m_downloadSpeedText = VpnConnection::bytesPerSecToText(receivedBytes);
    m_uploadSpeedText = VpnConnection::bytesPerSecToText(sentBytes);
    emit speedChanged();
}

void ConnectionUiController::updateConnectionDuration()
{
    const QString durationText = formatConnectionDuration(currentConnectionDurationMs());
    if (m_connectionDurationText == durationText) {
        return;
    }

    m_connectionDurationText = durationText;
    emit connectionDurationChanged();
}

void ConnectionUiController::onTranslationsUpdated()
{
    onConnectionStateChanged(getCurrentConnectionState());
}

Vpn::ConnectionState ConnectionUiController::getCurrentConnectionState()
{
    return m_state;
}

QString ConnectionUiController::connectionStateText() const
{
    return m_connectionStateText;
}

QString ConnectionUiController::downloadSpeedText() const
{
    return m_downloadSpeedText;
}

QString ConnectionUiController::uploadSpeedText() const
{
    return m_uploadSpeedText;
}

QString ConnectionUiController::connectionDurationText() const
{
    return m_connectionDurationText;
}

QString ConnectionUiController::formatConnectionDuration(qint64 durationMs) const
{
    const qint64 totalSeconds = durationMs / 1000;
    const qint64 hours = totalSeconds / 3600;
    const qint64 minutes = (totalSeconds % 3600) / 60;
    const qint64 seconds = totalSeconds % 60;

    return QStringLiteral("%1:%2:%3")
            .arg(hours, 2, 10, QLatin1Char('0'))
            .arg(minutes, 2, 10, QLatin1Char('0'))
            .arg(seconds, 2, 10, QLatin1Char('0'));
}

qint64 ConnectionUiController::currentConnectionDurationMs() const
{
    if (!m_isConnectionDurationActive) {
        return m_accumulatedConnectionDurationMs;
    }

    return m_accumulatedConnectionDurationMs
            + QDateTime::currentMSecsSinceEpoch() - m_connectionDurationStartedAtMs;
}

void ConnectionUiController::resumeConnectionDuration()
{
    if (m_isConnectionDurationActive) {
        return;
    }

    m_isConnectionDurationActive = true;
    m_connectionDurationStartedAtMs = QDateTime::currentMSecsSinceEpoch();
    m_connectionDurationTimer.start();
    updateConnectionDuration();
}

void ConnectionUiController::pauseConnectionDuration()
{
    if (!m_isConnectionDurationActive) {
        updateConnectionDuration();
        return;
    }

    m_accumulatedConnectionDurationMs = currentConnectionDurationMs();
    m_isConnectionDurationActive = false;
    m_connectionDurationStartedAtMs = 0;
    m_connectionDurationTimer.stop();
    updateConnectionDuration();
}

void ConnectionUiController::toggleConnection()
{
    qWarning() << "ConnectionUiController::toggleConnection ENTER m_state=" << static_cast<int>(m_state);
    if (m_state == Vpn::ConnectionState::Preparing) {
        clearPendingConnectionServer();
        emit preparingConfig();
        return;
    }

    if (isConnectionInProgress()) {
        closeConnection();
    } else if (isConnected()) {
        closeConnection();
    } else {
        const QString serverId = m_serversController->getDefaultServerId();
        if (serverId.isEmpty()) {
            return;
        }

        const ErrorCode errorCode = m_connectionController->isConnectionSupported(serverId);
        if (errorCode != ErrorCode::NoError) {
            notifyConnectionBlocked(errorCode);
            return;
        }

        m_notifyPeerDisconnectOnDisconnected = false;
        m_connectionServerId = serverId;
        emit prepareConfig(serverId);
    }
}

void ConnectionUiController::notifyConnectionBlocked(ErrorCode errorCode)
{
    qWarning() << "ConnectionUiController::notifyConnectionBlocked errorCode=" << static_cast<int>(errorCode);
    if (errorCode == ErrorCode::LegacyApiV1NotSupportedError) {
        emit unsupportedConnectDrawerRequested();
        return;
    }

    if (errorCode == ErrorCode::NoInstalledContainersError) {
        emit noInstalledContainers();
        return;
    }

    emit connectionErrorOccurred(errorCode);
}

bool ConnectionUiController::isConnectionInProgress() const
{
    return m_isConnectionInProgress;
}

bool ConnectionUiController::isConnected() const
{
    return m_isConnected;
}

bool ConnectionUiController::isRevokeBlockedDuringActiveConnection(const QString &serverId, int containerIndex,
                                                                   const QString &clientId) const
{
    if (clientId.isEmpty() || (!isConnected() && !isConnectionInProgress())) {
        return false;
    }

    if (m_serversController->getDefaultServerId() != serverId) {
        return false;
    }

    if (static_cast<int>(m_serversController->getDefaultContainer(serverId)) != containerIndex) {
        return false;
    }

    const auto adminConfig = m_serversController->selfHostedAdminConfig(serverId);
    if (!adminConfig.has_value()) {
        return false;
    }

    const QString connectionClientId =
            adminConfig->containerConfig(static_cast<DockerContainer>(containerIndex)).protocolConfig.clientId();
    if (connectionClientId.isEmpty()) {
        return false;
    }

    return connectionClientId == clientId || connectionClientId.contains(clientId);
}
