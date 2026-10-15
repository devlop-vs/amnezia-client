package org.amnezia.vpn.protocol.wireguard

import android.net.VpnService.Builder
import android.os.SystemClock
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.amnezia.awg.GoBackend
import org.amnezia.vpn.protocol.Protocol
import org.amnezia.vpn.protocol.ProtocolState.CONNECTED
import org.amnezia.vpn.protocol.ProtocolState.DISCONNECTED
import org.amnezia.vpn.protocol.Statistics
import org.amnezia.vpn.protocol.VpnException
import org.amnezia.vpn.protocol.VpnStartException
import org.amnezia.vpn.util.LibraryLoader.loadSharedLibrary
import org.amnezia.vpn.util.Log
import org.amnezia.vpn.util.asSequence
import org.amnezia.vpn.util.net.InetEndpoint
import org.amnezia.vpn.util.net.InetNetwork
import org.amnezia.vpn.util.net.parseInetAddress
import org.amnezia.vpn.util.optStringOrNull
import org.json.JSONObject
import java.net.InetAddress
import java.net.UnknownHostException

private const val TAG = "Wireguard"
private const val STATUS_POLL_INTERVAL_MS = 1_000L
private const val HANDSHAKE_TIMEOUT_MS = 10_000L
private const val STATUS_LOG_INTERVAL_POLLS = 5

open class Wireguard : Protocol() {

    private var tunnelHandle: Int = -1
    private var config: WireguardConfig? = null // save config for reconnect
    protected open val ifName: String = "amn0"
    private lateinit var scope: CoroutineScope
    private var statusJob: Job? = null

    override val statistics: Statistics
        get() {
            if (tunnelHandle == -1) return Statistics.EMPTY_STATISTICS
            val config = GoBackend.awgGetConfig(tunnelHandle) ?: return Statistics.EMPTY_STATISTICS
            return Statistics.build {
                var optsCount = 0
                config.splitToSequence("\n").forEach { line ->
                    with(line) {
                        when {
                            startsWith("rx_bytes=") -> setRxBytes(substring(9).toLong()).also { ++optsCount }
                            startsWith("tx_bytes=") -> setTxBytes(substring(9).toLong()).also { ++optsCount }
                            else -> {}
                        }
                    }
                    if (optsCount == 2) return@forEach
                }
            }
        }

    override fun internalInit() {
        if (!isInitialized) loadSharedLibrary(context, "wg-go")
        if (this::scope.isInitialized) {
            scope.cancel()
        }
        scope = CoroutineScope(Dispatchers.IO)
    }

    override suspend fun startVpn(config: JSONObject, vpnBuilder: Builder, protect: (Int) -> Boolean) {
        val wireguardConfig = parseConfig(config)
        start(wireguardConfig, vpnBuilder, protect)
        this.config = wireguardConfig
    }

    protected open fun parseConfig(config: JSONObject): WireguardConfig {
        val configData = config.getJSONObject("wireguard_config_data")
        return WireguardConfig.build {
            configWireguard(config, configData)
            configSplitTunneling(config)
            configAppSplitTunneling(config)
        }
    }

    protected fun WireguardConfig.Builder.configWireguard(config: JSONObject, configData: JSONObject) {
        configData.getString("client_ip").split(",").map { address ->
            InetNetwork.parse(address.trim())
        }.forEach(::addAddress)

        config.optStringOrNull("dns1")?.let { dns ->
            addDnsServer(parseInetAddress(dns.trim()))
        }

        config.optStringOrNull("dns2")?.let { dns ->
            addDnsServer(parseInetAddress(dns.trim()))
        }

        val defRoutes = hashSetOf(
            InetNetwork("0.0.0.0", 0),
            InetNetwork("::", 0)
        )
        val routes = hashSetOf<InetNetwork>()
        configData.getJSONArray("allowed_ips").asSequence<String>().map { route ->
            InetNetwork.parse(route.trim())
        }.forEach(routes::add)
        // if the allowed IPs list contains at least one non-default route, disable global split tunneling
        if (routes.any { it !in defRoutes }) disableSplitTunneling()
        addRoutes(routes)

        configData.optStringOrNull("mtu")?.let { setMtu(it.toInt()) }

        val host = resolveEndpointHost(
            configData.getString("hostName").trim(),
            config.optStringOrNull("hostName")?.trim()
        )
        val port = configData.getInt("port")
        setEndpoint(InetEndpoint(host, port))

        if (configData.optBoolean("isObfuscationEnabled")) {
            setUseProtocolExtension(true)
            configExtensionParameters(configData)
        }

        configData.optStringOrNull("persistent_keep_alive")?.let { setPersistentKeepalive(it.toInt()) }
        configData.getString("client_priv_key").let { setPrivateKeyHex(it.base64ToHex()) }
        configData.getString("server_pub_key").let { setPublicKeyHex(it.base64ToHex()) }
        configData.optStringOrNull("psk_key")?.let { setPreSharedKeyHex(it.base64ToHex()) }
    }

    private fun resolveEndpointHost(primaryHost: String, fallbackHost: String?): InetAddress {
        try {
            return parseInetAddress(primaryHost)
        } catch (e: UnknownHostException) {
            if (!fallbackHost.isNullOrEmpty() && fallbackHost != primaryHost) {
                Log.w(TAG, "WireGuard endpoint host '$primaryHost' cannot be resolved, try top-level hostName '$fallbackHost'")
                return parseInetAddress(fallbackHost)
            }
            throw e
        }
    }

    protected fun WireguardConfig.Builder.configExtensionParameters(configData: JSONObject) {
        configData.optStringOrNull("Jc")?.let { setJc(it.toInt()) }
        configData.optStringOrNull("Jmin")?.let { setJmin(it.toInt()) }
        configData.optStringOrNull("Jmax")?.let { setJmax(it.toInt()) }
        configData.optStringOrNull("S1")?.let { setS1(it.toInt()) }
        configData.optStringOrNull("S2")?.let { setS2(it.toInt()) }
        configData.optStringOrNull("S3")?.let { setS3(it.toInt()) }
        configData.optStringOrNull("S4")?.let { setS4(it.toInt()) }
        configData.optStringOrNull("H1")?.trim()?.let { if (it.isNotEmpty()) setH1(it) }
        configData.optStringOrNull("H2")?.trim()?.let { if (it.isNotEmpty()) setH2(it) }
        configData.optStringOrNull("H3")?.trim()?.let { if (it.isNotEmpty()) setH3(it) }
        configData.optStringOrNull("H4")?.trim()?.let { if (it.isNotEmpty()) setH4(it) }
        configData.optStringOrNull("I1")?.let { setI1(it) }
        configData.optStringOrNull("I2")?.let { setI2(it) }
        configData.optStringOrNull("I3")?.let { setI3(it) }
        configData.optStringOrNull("I4")?.let { setI4(it) }
        configData.optStringOrNull("I5")?.let { setI5(it) }
    }

    private fun start(
        config: WireguardConfig,
        vpnBuilder: Builder,
        protect: (Int) -> Boolean,
        stopExistingVpn: Boolean = false
    ) {
        if (!stopExistingVpn && tunnelHandle != -1) {
            Log.w(TAG, "Tunnel already up")
            return
        }

        Log.i(TAG, "Start tunnel: interface=$ifName, endpoint=${config.endpoint}, mtu=${config.mtu}")
        buildVpnInterface(config, vpnBuilder)

        vpnBuilder.establish().use { tunFd ->
            if (stopExistingVpn && tunnelHandle != -1) {
                turnOffVpn()
            }
            if (tunFd == null) {
                throw VpnStartException("Create VPN interface: permission not granted or revoked")
            }
            Log.i(TAG, "awg-go backend ${GoBackend.awgVersion()}")
            tunnelHandle = GoBackend.awgTurnOn(ifName, tunFd.detachFd(), config.toWgUserspaceString())
        }

        if (tunnelHandle < 0) {
            tunnelHandle = -1
            throw VpnStartException("Wireguard tunnel creation error")
        }

        val socketV4 = GoBackend.awgGetSocketV4(tunnelHandle)
        val socketV6 = GoBackend.awgGetSocketV6(tunnelHandle)
        val protectedV4 = protect(socketV4)
        val protectedV6 = protect(socketV6)
        Log.i(
            TAG,
            "Tunnel backend started: handle=$tunnelHandle, socketV4=$socketV4 protected=$protectedV4, " +
                "socketV6=$socketV6 protected=$protectedV6"
        )
        if (!protectedV4 || !protectedV6) {
            GoBackend.awgTurnOff(tunnelHandle)
            tunnelHandle = -1
            throw VpnStartException("Protect VPN interface: permission not granted or revoked")
        }
        launchStatusJob()
    }

    private fun launchStatusJob() {
        Log.d(TAG, "Launch status job")
        statusJob = scope.launch {
            val startedAt = SystemClock.elapsedRealtime()
            var pollCount = 0
            while (true) {
                val tunnelStatus = getTunnelStatus()
                val lastHandshake = tunnelStatus.lastHandshake
                val elapsed = SystemClock.elapsedRealtime() - startedAt
                ++pollCount
                if (lastHandshake == 0L) {
                    if (pollCount == 1 || pollCount % STATUS_LOG_INTERVAL_POLLS == 0) {
                        Log.i(
                            TAG,
                            "Waiting for handshake: elapsedMs=$elapsed, rxBytes=${tunnelStatus.rxBytes}, " +
                                "txBytes=${tunnelStatus.txBytes}"
                        )
                    }
                    if (elapsed >= HANDSHAKE_TIMEOUT_MS) {
                        Log.e(
                            TAG,
                            "WireGuard handshake timeout: elapsedMs=$elapsed, rxBytes=${tunnelStatus.rxBytes}, " +
                                "txBytes=${tunnelStatus.txBytes}"
                        )
                        onError("WireGuard handshake timed out after ${HANDSHAKE_TIMEOUT_MS / 1000} seconds")
                        turnOffVpn()
                        state.value = DISCONNECTED
                        break
                    }
                    delay(STATUS_POLL_INTERVAL_MS)
                    continue
                }
                if (lastHandshake > 0L) {
                    Log.i(
                        TAG,
                        "Handshake detected: lastHandshake=$lastHandshake, elapsedMs=$elapsed, " +
                            "rxBytes=${tunnelStatus.rxBytes}, txBytes=${tunnelStatus.txBytes}"
                    )
                    state.value = CONNECTED
                } else if (lastHandshake == -2L) {
                    onError("Failed to read WireGuard tunnel status")
                    turnOffVpn()
                    state.value = DISCONNECTED
                } else if (lastHandshake == -1L) {
                    state.value = DISCONNECTED
                }
                statusJob = null
                break
            }
        }
    }

    private data class TunnelStatus(
        val lastHandshake: Long,
        val rxBytes: Long,
        val txBytes: Long
    )

    private fun getTunnelStatus(): TunnelStatus {
        if (tunnelHandle == -1) {
            Log.e(TAG, "Trying to get config of a non-existent tunnel")
            return TunnelStatus(-1, 0, 0)
        }
        val config = GoBackend.awgGetConfig(tunnelHandle)
        if (config == null) {
            Log.e(TAG, "Failed to get tunnel config")
            return TunnelStatus(-2, 0, 0)
        }
        var lastHandshake: Long? = null
        var rxBytes = 0L
        var txBytes = 0L
        config.lineSequence().forEach { line ->
            when {
                line.startsWith("last_handshake_time_sec=") ->
                    lastHandshake = line.substringAfter('=').toLongOrNull()
                line.startsWith("rx_bytes=") -> rxBytes = line.substringAfter('=').toLongOrNull() ?: 0
                line.startsWith("tx_bytes=") -> txBytes = line.substringAfter('=').toLongOrNull() ?: 0
            }
        }
        if (lastHandshake == null) {
            Log.e(TAG, "Failed to get last_handshake_time_sec")
            return TunnelStatus(-2, rxBytes, txBytes)
        }
        return TunnelStatus(lastHandshake!!, rxBytes, txBytes)
    }

    private fun turnOffVpn() {
        statusJob?.cancel()
        statusJob = null
        val handleToClose = tunnelHandle
        tunnelHandle = -1
        GoBackend.awgTurnOff(handleToClose)
    }

    override fun stopVpn() {
        if (tunnelHandle == -1) {
            Log.w(TAG, "Tunnel already down")
            return
        }
        turnOffVpn()
        state.value = DISCONNECTED
    }

    override fun reconnectVpn(vpnBuilder: Builder, protect: (Int) -> Boolean) {
        val config = this.config ?: throw VpnException("Reconnect config is empty")
        start(config, vpnBuilder, protect, true)
    }
}
