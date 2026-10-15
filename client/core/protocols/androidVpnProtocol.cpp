#include "androidVpnProtocol.h"

#include "platforms/android/android_controller.h"


AndroidVpnProtocol::AndroidVpnProtocol(const QJsonObject &configuration, QObject* parent)
    : VpnProtocol(configuration, parent)
{ }

ErrorCode AndroidVpnProtocol::start()
{
    qDebug() << "AndroidVpnProtocol::start()";
    return AndroidController::instance()->start(m_rawConfig);
}

void AndroidVpnProtocol::stop()
{
    qDebug() << "AndroidVpnProtocol::stop()";
    setConnectionState(Vpn::ConnectionState::Disconnecting);
    AndroidController::instance()->stop();
}

void AndroidVpnProtocol::setSpeedChanged(quint64 receivedBytesPerSecond, quint64 sentBytesPerSecond)
{
    emit bytesChanged(receivedBytesPerSecond, sentBytesPerSecond);
}
