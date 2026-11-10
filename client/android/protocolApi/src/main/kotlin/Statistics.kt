package org.amnezia.vpn.protocol

import android.os.Bundle

private const val RX_BYTES_KEY = "rxBytes"
private const val TX_BYTES_KEY = "txBytes"
private const val RX_BYTES_PER_SECOND_KEY = "rxBytesPerSecond"
private const val TX_BYTES_PER_SECOND_KEY = "txBytesPerSecond"
private const val SESSION_RX_BYTES_KEY = "sessionRxBytes"
private const val SESSION_TX_BYTES_KEY = "sessionTxBytes"
private const val CONNECTED_SINCE_EPOCH_MS_KEY = "connectedSinceEpochMs"

@Suppress("DataClassPrivateConstructor")
data class Statistics private constructor(
    val rxBytes: Long = 0L,
    val txBytes: Long = 0L,
    val rxBytesPerSecond: Long = 0L,
    val txBytesPerSecond: Long = 0L,
    val sessionRxBytes: Long = 0L,
    val sessionTxBytes: Long = 0L,
    val connectedSinceEpochMs: Long = 0L
) {

    private constructor(builder: Builder) : this(
        builder.rxBytes,
        builder.txBytes,
        builder.rxBytesPerSecond,
        builder.txBytesPerSecond,
        builder.sessionRxBytes,
        builder.sessionTxBytes,
        builder.connectedSinceEpochMs
    )

    @Suppress("SuspiciousEqualsCombination")
    fun isEmpty(): Boolean = this === EMPTY_STATISTICS || this == EMPTY_STATISTICS

    class Builder {
        var rxBytes: Long = 0L
            private set
        var txBytes: Long = 0L
            private set
        var rxBytesPerSecond: Long = 0L
            private set
        var txBytesPerSecond: Long = 0L
            private set
        var sessionRxBytes: Long = 0L
            private set
        var sessionTxBytes: Long = 0L
            private set
        var connectedSinceEpochMs: Long = 0L
            private set

        fun setRxBytes(rxBytes: Long) = apply { this.rxBytes = rxBytes }
        fun setTxBytes(txBytes: Long) = apply { this.txBytes = txBytes }
        fun setRxBytesPerSecond(rxBytesPerSecond: Long) = apply { this.rxBytesPerSecond = rxBytesPerSecond }
        fun setTxBytesPerSecond(txBytesPerSecond: Long) = apply { this.txBytesPerSecond = txBytesPerSecond }
        fun setSessionRxBytes(sessionRxBytes: Long) = apply { this.sessionRxBytes = sessionRxBytes }
        fun setSessionTxBytes(sessionTxBytes: Long) = apply { this.sessionTxBytes = sessionTxBytes }
        fun setConnectedSinceEpochMs(connectedSinceEpochMs: Long) = apply {
            this.connectedSinceEpochMs = connectedSinceEpochMs
        }

        fun build(): Statistics = Statistics(this)
    }

    companion object {
        val EMPTY_STATISTICS: Statistics = Statistics()

        inline fun build(block: Builder.() -> Unit): Statistics = Builder().apply(block).build()
    }
}

fun Bundle.putStatistics(statistics: Statistics) {
    putLong(RX_BYTES_KEY, statistics.rxBytes)
    putLong(TX_BYTES_KEY, statistics.txBytes)
    putLong(RX_BYTES_PER_SECOND_KEY, statistics.rxBytesPerSecond)
    putLong(TX_BYTES_PER_SECOND_KEY, statistics.txBytesPerSecond)
    putLong(SESSION_RX_BYTES_KEY, statistics.sessionRxBytes)
    putLong(SESSION_TX_BYTES_KEY, statistics.sessionTxBytes)
    putLong(CONNECTED_SINCE_EPOCH_MS_KEY, statistics.connectedSinceEpochMs)
}

fun Bundle.getStatistics(): Statistics =
    Statistics.build {
        setRxBytes(getLong(RX_BYTES_KEY))
        setTxBytes(getLong(TX_BYTES_KEY))
        setRxBytesPerSecond(getLong(RX_BYTES_PER_SECOND_KEY))
        setTxBytesPerSecond(getLong(TX_BYTES_PER_SECOND_KEY))
        setSessionRxBytes(getLong(SESSION_RX_BYTES_KEY))
        setSessionTxBytes(getLong(SESSION_TX_BYTES_KEY))
        setConnectedSinceEpochMs(getLong(CONNECTED_SINCE_EPOCH_MS_KEY))
    }
