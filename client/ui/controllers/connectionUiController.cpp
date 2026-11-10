#include "connectionUiController.h"

#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS) || defined(MACOS_NE)
    #include <QGuiApplication>
#else
    #include <QApplication>
#endif

#include <QDateTime>
#include <QTimeZone>

#include <limits>

#include "amneziaApplication.h"
#include "core/controllers/serversController.h"
#include "core/models/containerConfig.h"
#include "core/utils/containerEnum.h"

ConnectionUiController::ConnectionUiController(ConnectionController* connectionController,
                                                ServersController* serversController,
                                                SecureAppSettingsRepository *appSettingsRepository,
                                                QObject *parent)
    : QObject(parent),
      m_connectionController(connectionController),
      m_serversController(serversController),
      m_appSettingsRepository(appSettingsRepository)
{
    connect(m_connectionController, &ConnectionController::connectionStateChanged, this, &ConnectionUiController::onConnectionStateChanged);
    connect(m_connectionController, &ConnectionController::trafficUpdated, this, &ConnectionUiController::onTrafficUpdated);

    connect(this, &ConnectionUiController::connectButtonClicked, this, &ConnectionUiController::toggleConnection, Qt::QueuedConnection);

    m_connectionDurationTimer.setInterval(1000);
    connect(&m_connectionDurationTimer, &QTimer::timeout, this, &ConnectionUiController::updateConnectionDuration);
    connect(qApp, &QCoreApplication::aboutToQuit, this, [this]() {
        if (m_isConnectionDurationActive) {
            updateConnectionDuration();
        }
        persistUsageStats(true);
    });
    connect(qGuiApp, &QGuiApplication::applicationStateChanged, this,
            [this](Qt::ApplicationState state) {
        if (state == Qt::ApplicationInactive || state == Qt::ApplicationSuspended) {
            if (m_isConnectionDurationActive) {
                updateConnectionDuration();
            }
            persistUsageStats(true);
        }
    });

    loadUsageStats(QDateTime::currentDateTime());
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

void ConnectionUiController::onTrafficUpdated(quint64 receivedDeltaBytes, quint64 sentDeltaBytes,
                                              quint64 receivedBytesPerSecond, quint64 sentBytesPerSecond)
{
    rollUsagePeriods(QDateTime::currentDateTime());
    const quint64 totalDelta = std::numeric_limits<quint64>::max() - receivedDeltaBytes < sentDeltaBytes
        ? std::numeric_limits<quint64>::max() : receivedDeltaBytes + sentDeltaBytes;
    m_dailyUsage.trafficBytes = std::numeric_limits<quint64>::max() - m_dailyUsage.trafficBytes < totalDelta
        ? std::numeric_limits<quint64>::max() : m_dailyUsage.trafficBytes + totalDelta;
    m_monthlyUsage.trafficBytes = std::numeric_limits<quint64>::max() - m_monthlyUsage.trafficBytes < totalDelta
        ? std::numeric_limits<quint64>::max() : m_monthlyUsage.trafficBytes + totalDelta;
    m_usageStatsDirty = m_usageStatsDirty || totalDelta > 0;

    const QString downloadSpeedText = VpnConnection::bytesPerSecToText(receivedBytesPerSecond);
    const QString uploadSpeedText = VpnConnection::bytesPerSecToText(sentBytesPerSecond);
    if (m_downloadSpeedText != downloadSpeedText || m_uploadSpeedText != uploadSpeedText) {
        m_downloadSpeedText = downloadSpeedText;
        m_uploadSpeedText = uploadSpeedText;
        emit speedChanged();
    }
    if (totalDelta > 0) {
        emit usageStatsChanged();
        persistUsageStats();
    }
}

void ConnectionUiController::updateConnectionDuration()
{
    if (m_isConnectionDurationActive) {
        const qint64 nowEpochMs = QDateTime::currentMSecsSinceEpoch();
        addProtectedDuration(m_lastUsageUpdateEpochMs, nowEpochMs);
        m_lastUsageUpdateEpochMs = nowEpochMs;
    }

    const QString durationText = formatConnectionDuration(currentConnectionDurationMs());
    if (m_connectionDurationText != durationText) {
        m_connectionDurationText = durationText;
        emit connectionDurationChanged();
    }

    if (m_isConnectionDurationActive) {
        emit usageStatsChanged();
        persistUsageStats();
    }
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

QString ConnectionUiController::connectionServerId() const
{
    return m_connectionServerId;
}

QString ConnectionUiController::todayProtectedDurationText() const
{
    return formatProtectedDuration(m_dailyUsage.durationMs);
}

QString ConnectionUiController::todayProtectedVolumeText() const
{
    return formatProtectedVolume(m_dailyUsage.trafficBytes);
}

QString ConnectionUiController::monthProtectedDurationText() const
{
    return formatProtectedDuration(m_monthlyUsage.durationMs);
}

QString ConnectionUiController::monthProtectedVolumeText() const
{
    return formatProtectedVolume(m_monthlyUsage.trafficBytes);
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

    const qint64 nowEpochMs = QDateTime::currentMSecsSinceEpoch();
    m_isConnectionDurationActive = true;
    m_connectionDurationStartedAtMs = nowEpochMs;
    m_lastUsageUpdateEpochMs = nowEpochMs;
    rollUsagePeriods(QDateTime::fromMSecsSinceEpoch(nowEpochMs));
    m_connectionDurationTimer.start();
    updateConnectionDuration();
}

void ConnectionUiController::pauseConnectionDuration()
{
    if (!m_isConnectionDurationActive) {
        updateConnectionDuration();
        return;
    }

    updateConnectionDuration();
    m_accumulatedConnectionDurationMs = currentConnectionDurationMs();
    m_isConnectionDurationActive = false;
    m_connectionDurationStartedAtMs = 0;
    m_lastUsageUpdateEpochMs = 0;
    m_connectionDurationTimer.stop();
    persistUsageStats(true);
}

void ConnectionUiController::loadUsageStats(const QDateTime &now)
{
    m_usageDate = now.date();
    m_usageMonth = monthKey(m_usageDate);
    if (!m_appSettingsRepository) {
        return;
    }
    m_dailyUsage = m_appSettingsRepository->vpnUsageForDate(m_usageDate);
    m_monthlyUsage = m_appSettingsRepository->vpnUsageForMonth(m_usageMonth);
    m_lastUsagePersistenceEpochMs = now.toMSecsSinceEpoch();
}

void ConnectionUiController::rollUsagePeriods(const QDateTime &now)
{
    if (m_usageDate == now.date() && m_usageMonth == monthKey(now.date())) {
        return;
    }

    const QString newMonth = monthKey(now.date());
    if (m_appSettingsRepository && m_usageStatsDirty) {
        if (m_usageDate.isValid()) {
            m_appSettingsRepository->setVpnUsageForDate(m_usageDate, m_dailyUsage);
        }
        if (!m_usageMonth.isEmpty()) {
            m_appSettingsRepository->setVpnUsageForMonth(m_usageMonth, m_monthlyUsage);
        }
        m_lastUsagePersistenceEpochMs = QDateTime::currentMSecsSinceEpoch();
        m_usageStatsDirty = false;
    }
    if (m_usageDate != now.date()) {
        m_usageDate = now.date();
        m_dailyUsage = m_appSettingsRepository
            ? m_appSettingsRepository->vpnUsageForDate(m_usageDate) : VpnUsagePeriod {};
    }
    if (m_usageMonth != newMonth) {
        m_usageMonth = newMonth;
        m_monthlyUsage = m_appSettingsRepository
            ? m_appSettingsRepository->vpnUsageForMonth(m_usageMonth) : VpnUsagePeriod {};
    }
    emit usageStatsChanged();
}

void ConnectionUiController::addProtectedDuration(qint64 fromEpochMs, qint64 toEpochMs)
{
    if (fromEpochMs <= 0 || toEpochMs <= fromEpochMs) {
        return;
    }

    qint64 cursor = fromEpochMs;
    while (cursor < toEpochMs) {
        const QDateTime cursorTime = QDateTime::fromMSecsSinceEpoch(cursor);
        rollUsagePeriods(cursorTime);
        const QDateTime nextMidnight(cursorTime.date().addDays(1), QTime(0, 0), cursorTime.timeZone());
        const qint64 segmentEnd = qMin(toEpochMs, nextMidnight.toMSecsSinceEpoch());
        const qint64 durationMs = segmentEnd - cursor;
        m_dailyUsage.durationMs = std::numeric_limits<qint64>::max() - m_dailyUsage.durationMs < durationMs
            ? std::numeric_limits<qint64>::max() : m_dailyUsage.durationMs + durationMs;
        m_monthlyUsage.durationMs = std::numeric_limits<qint64>::max() - m_monthlyUsage.durationMs < durationMs
            ? std::numeric_limits<qint64>::max() : m_monthlyUsage.durationMs + durationMs;
        m_usageStatsDirty = true;
        cursor = segmentEnd;
    }
}

void ConnectionUiController::persistUsageStats(bool force)
{
    if (!m_appSettingsRepository || !m_usageStatsDirty) {
        return;
    }
    const qint64 nowEpochMs = QDateTime::currentMSecsSinceEpoch();
    rollUsagePeriods(QDateTime::fromMSecsSinceEpoch(nowEpochMs));
    if (!m_usageStatsDirty || (!force && nowEpochMs - m_lastUsagePersistenceEpochMs < 15000)) {
        return;
    }

    m_appSettingsRepository->setVpnUsageForDate(m_usageDate, m_dailyUsage);
    m_appSettingsRepository->setVpnUsageForMonth(m_usageMonth, m_monthlyUsage);
    m_lastUsagePersistenceEpochMs = nowEpochMs;
    m_usageStatsDirty = false;
}

QString ConnectionUiController::formatProtectedDuration(qint64 durationMs) const
{
    const qint64 totalSeconds = qMax<qint64>(0, durationMs) / 1000;
    if (totalSeconds < 60) {
        return QStringLiteral("%1 sec").arg(totalSeconds);
    }
    const qint64 totalMinutes = totalSeconds / 60;
    if (totalMinutes < 60) {
        return QStringLiteral("%1 min").arg(totalMinutes);
    }
    return QStringLiteral("%1h %2m").arg(totalMinutes / 60).arg(totalMinutes % 60);
}

QString ConnectionUiController::formatProtectedVolume(quint64 bytes) const
{
    static constexpr quint64 KiB = 1024;
    static constexpr quint64 MiB = KiB * 1024;
    static constexpr quint64 GiB = MiB * 1024;
    if (bytes < KiB) {
        return QStringLiteral("%1 B").arg(bytes);
    }

    quint64 unit = KiB;
    QString suffix = QStringLiteral("KiB");
    int precision = 1;
    if (bytes >= GiB) {
        unit = GiB;
        suffix = QStringLiteral("GiB");
        precision = 2;
    } else if (bytes >= MiB) {
        unit = MiB;
        suffix = QStringLiteral("MiB");
        precision = bytes % unit == 0 ? 0 : 1;
    }
    const double value = static_cast<double>(bytes) / static_cast<double>(unit);
    return QStringLiteral("%1 %2").arg(QString::number(value, 'f', precision), suffix);
}

QString ConnectionUiController::monthKey(const QDate &date) const
{
    return date.toString(QStringLiteral("yyyy-MM"));
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
