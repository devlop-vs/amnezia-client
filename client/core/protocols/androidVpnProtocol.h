#ifndef ANDROID_VPNPROTOCOL_H
#define ANDROID_VPNPROTOCOL_H

#include "vpnProtocol.h"

using namespace amnezia;

class AndroidVpnProtocol : public VpnProtocol
{
    Q_OBJECT

public:
    explicit AndroidVpnProtocol(const QJsonObject& configuration, QObject* parent = nullptr);
    ~AndroidVpnProtocol() override = default;

    ErrorCode start() override;
    void stop() override;

public slots:
    void setSpeedChanged(quint64 receivedBytesPerSecond, quint64 sentBytesPerSecond);
};

#endif // ANDROID_VPNPROTOCOL_H
