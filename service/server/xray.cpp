#include "xray.h"
#include "core/utils/networkUtilities.h"
#ifdef Q_OS_MAC
#include "router_mac.h"
#endif

#include <QDebug>
#include <QNetworkInterface>
#include <QCoreApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStringList>
#include <amnezia_xray.h>
#include <qdebug.h>

#ifdef Q_OS_DARWIN
    #include <arpa/inet.h>
    #include <cerrno>
    #include <cstddef>
    #include <cstdint>
    #include <cstring>
    #include <ifaddrs.h>
    #include <net/if.h>
    #include <netinet/in.h>
    #include <netinet/ip.h>
    #include <sys/socket.h>
#endif
#ifdef Q_OS_WIN
    #include <winsock2.h>
    #include <ws2tcpip.h>
#endif
#ifdef Q_OS_LINUX
    #include <sys/socket.h>
    #include "xray_defs.h"
#endif

namespace
{
void logOutboundSummary(const QString& cfg)
{
    const auto doc = QJsonDocument::fromJson(cfg.toUtf8());
    if (!doc.isObject()) {
        qWarning() << "[xray] unable to parse config for outbound diagnostics";
        return;
    }

    const auto root = doc.object();
    const auto outbounds = root.value(QStringLiteral("outbounds")).toArray();
    if (outbounds.isEmpty()) {
        qWarning() << "[xray] config contains no outbounds for diagnostics";
        return;
    }

    for (int i = 0; i < outbounds.size(); ++i) {
        const auto outbound = outbounds.at(i).toObject();
        const QString protocol = outbound.value(QStringLiteral("protocol")).toString();
        const QString tag = outbound.value(QStringLiteral("tag")).toString();
        const auto settings = outbound.value(QStringLiteral("settings")).toObject();

        QStringList endpoints;

        const auto vnext = settings.value(QStringLiteral("vnext")).toArray();
        for (const auto& item : vnext) {
            const auto server = item.toObject();
            endpoints << QStringLiteral("%1:%2")
                             .arg(server.value(QStringLiteral("address")).toString())
                             .arg(server.value(QStringLiteral("port")).toInt());
        }

        const auto servers = settings.value(QStringLiteral("servers")).toArray();
        for (const auto& item : servers) {
            const auto server = item.toObject();
            endpoints << QStringLiteral("%1:%2")
                             .arg(server.value(QStringLiteral("address")).toString())
                             .arg(server.value(QStringLiteral("port")).toInt());
        }

        if (endpoints.isEmpty()) {
            endpoints << QStringLiteral("<no direct address/port in settings>");
        }

        qDebug().noquote() << QStringLiteral("[xray] outbound[%1] protocol=%2 tag=%3 endpoints=%4")
                                  .arg(i)
                                  .arg(protocol.isEmpty() ? QStringLiteral("<empty>") : protocol)
                                  .arg(tag.isEmpty() ? QStringLiteral("<empty>") : tag)
                                  .arg(endpoints.join(QStringLiteral(", ")));
    }
}

QString socketAddressToString(const sockaddr_storage& storage, socklen_t len)
{
    Q_UNUSED(len);

    char host[INET6_ADDRSTRLEN] = {0};
    quint16 port = 0;

    if (storage.ss_family == AF_INET) {
        const auto* addr = reinterpret_cast<const sockaddr_in*>(&storage);
        inet_ntop(AF_INET, &addr->sin_addr, host, sizeof(host));
        port = ntohs(addr->sin_port);
    } else if (storage.ss_family == AF_INET6) {
        const auto* addr = reinterpret_cast<const sockaddr_in6*>(&storage);
        inet_ntop(AF_INET6, &addr->sin6_addr, host, sizeof(host));
        port = ntohs(addr->sin6_port);
    } else {
        return QStringLiteral("family=%1").arg(storage.ss_family);
    }

    return QStringLiteral("%1:%2").arg(QString::fromLatin1(host)).arg(port);
}

QString describeSocketEndpoints(uintptr_t fd)
{
    QStringList parts;

    sockaddr_storage localAddr {};
    socklen_t localLen = sizeof(localAddr);
    if (getsockname(fd, reinterpret_cast<sockaddr*>(&localAddr), &localLen) == 0) {
        parts << QStringLiteral("local=%1").arg(socketAddressToString(localAddr, localLen));
    } else {
        parts << QStringLiteral("local=<unavailable errno=%1>").arg(errno);
    }

    sockaddr_storage peerAddr {};
    socklen_t peerLen = sizeof(peerAddr);
    if (getpeername(fd, reinterpret_cast<sockaddr*>(&peerAddr), &peerLen) == 0) {
        parts << QStringLiteral("peer=%1").arg(socketAddressToString(peerAddr, peerLen));
    } else {
        parts << QStringLiteral("peer=<unconnected errno=%1>").arg(errno);
    }

    int socketType = 0;
    socklen_t socketTypeLen = sizeof(socketType);
    if (getsockopt(fd, SOL_SOCKET, SO_TYPE, reinterpret_cast<char*>(&socketType), &socketTypeLen) == 0) {
        parts << QStringLiteral("type=%1").arg(socketType);
    }

    return parts.join(QStringLiteral(", "));
}
}

bool Xray::startXray(const QString &cfg)
{
    qDebug() << "Xray::startXray()";
    logOutboundSummary(cfg);

    const auto gatewayAndIface = NetworkUtilities::getGatewayAndIface();
    const QString defaultGateway = gatewayAndIface.first;
    const QNetworkInterface defaultIface = gatewayAndIface.second;
#ifdef Q_OS_LINUX
    m_defaultIfaceName = defaultIface.name().toUtf8();
#else
    m_defaultIfaceIdx = defaultIface.index();
#endif
    if (defaultIface.index() > 0) {
        qDebug() << "[xray] using uplink interface:" << defaultIface.name() << "(" << defaultIface.index() << ")";
    }

#ifdef Q_OS_MAC
    m_uplinkIfaceName = defaultIface.name();
    m_uplinkGateway = defaultGateway;
    if (!m_uplinkIfaceName.isEmpty()) {
        const bool installed = RouterMac::Instance().routeAddXray(m_uplinkIfaceName, m_uplinkGateway);
        if (!installed) {
            qWarning() << "[xray] failed to install xray routes on" << m_uplinkIfaceName;
        }
    }
#endif

    if (auto err = amnezia_xray_setsockcallback(ctxSockCallback, this); err != nullptr) {
        qDebug() << "[xray] sockopt failed: " << err;
        amnezia_xray_free(err);
        return false;
    }

    amnezia_xray_setloghandler(ctxLogHandler, this);

    QByteArray bytes = cfg.toUtf8();
    if (auto err = amnezia_xray_configure(bytes.data()); err != nullptr) {
        qDebug() << "[xray] configuration failed: " << err;
        amnezia_xray_free(err);
        return false;
    }

    if (auto err = amnezia_xray_start(); err != nullptr) {
        qDebug() << "[xray] failed to start: " << err;
        amnezia_xray_free(err);
        return false;
    }

    return true;
}

bool Xray::stopXray()
{
    qDebug() << "Xray::stopXray()";
    bool success = true;
    if (auto err = amnezia_xray_stop(); err != nullptr) {
        qDebug() << "[xray] failed to stop: " << err;
        amnezia_xray_free(err);
        success = false;
    }

#ifdef Q_OS_MAC
    if (!m_uplinkIfaceName.isEmpty()) {
        RouterMac::Instance().routeDeleteXray(m_uplinkIfaceName, m_uplinkGateway);
    }
    m_uplinkIfaceName.clear();
    m_uplinkGateway.clear();
#endif

    return success;
}

void Xray::logHandler(char* str)
{
    QMetaObject::invokeMethod(qApp, [str = QString::fromUtf8(str)] {
        qDebug() << "[xray]" << str;
    }, Qt::QueuedConnection);
}

void Xray::sockCallback(uintptr_t fd)
{
    qDebug().noquote() << QStringLiteral("[xray] sockCallback fd=%1 before bind: %2")
                              .arg(qulonglong(fd))
                              .arg(describeSocketEndpoints(fd));

#ifdef Q_OS_MAC
    if (m_defaultIfaceIdx > 0) {
        const int ipv4Ret = setsockopt(fd, IPPROTO_IP, IP_BOUND_IF, &m_defaultIfaceIdx, sizeof(m_defaultIfaceIdx));
        const int ipv4Err = errno;
        const int ipv6Ret = setsockopt(fd, IPPROTO_IPV6, IPV6_BOUND_IF, &m_defaultIfaceIdx, sizeof(m_defaultIfaceIdx));
        const int ipv6Err = errno;
        qDebug().noquote() << QStringLiteral("[xray] sockCallback fd=%1 bind-if mac idx=%2 ipv4Ret=%3 ipv4Err=%4 ipv6Ret=%5 ipv6Err=%6")
                                  .arg(qulonglong(fd))
                                  .arg(m_defaultIfaceIdx)
                                  .arg(ipv4Ret)
                                  .arg(ipv4Err)
                                  .arg(ipv6Ret)
                                  .arg(ipv6Err);
    }
#endif
#ifdef Q_OS_WIN
    if (DWORD idx = m_defaultIfaceIdx; idx > 0) {
        const int ipv6Ret = setsockopt(fd, IPPROTO_IPV6, IPV6_UNICAST_IF, reinterpret_cast<char *>(&idx), sizeof(idx));
        const int ipv6Err = WSAGetLastError();
        idx = htonl(idx); // IP_UNICAST_IF expects index in network byte order
        const int ipv4Ret = setsockopt(fd, IPPROTO_IP, IP_UNICAST_IF, reinterpret_cast<char *>(&idx), sizeof(idx));
        const int ipv4Err = WSAGetLastError();
        qDebug().noquote() << QStringLiteral("[xray] sockCallback fd=%1 bind-if win idx=%2 ipv6Ret=%3 ipv6Err=%4 ipv4Ret=%5 ipv4Err=%6")
                                  .arg(qulonglong(fd))
                                  .arg(m_defaultIfaceIdx)
                                  .arg(ipv6Ret)
                                  .arg(ipv6Err)
                                  .arg(ipv4Ret)
                                  .arg(ipv4Err);
    }
#endif
#ifdef Q_OS_LINUX
    if (!m_defaultIfaceName.isEmpty()) {
        const int bindRet = setsockopt(fd, SOL_SOCKET, SO_BINDTODEVICE, m_defaultIfaceName.data(), m_defaultIfaceName.size());
        const int bindErr = errno;
        const int markRet = setsockopt(fd, SOL_SOCKET, SO_MARK, &amnezia::xray::xrayTrafficMark, sizeof(amnezia::xray::xrayTrafficMark));
        const int markErr = errno;
        qDebug().noquote() << QStringLiteral("[xray] sockCallback fd=%1 bind-if linux if=%2 bindRet=%3 bindErr=%4 markRet=%5 markErr=%6")
                                  .arg(qulonglong(fd))
                                  .arg(QString::fromUtf8(m_defaultIfaceName))
                                  .arg(bindRet)
                                  .arg(bindErr)
                                  .arg(markRet)
                                  .arg(markErr);
    }
#endif

    qDebug().noquote() << QStringLiteral("[xray] sockCallback fd=%1 after bind: %2")
                              .arg(qulonglong(fd))
                              .arg(describeSocketEndpoints(fd));
}
