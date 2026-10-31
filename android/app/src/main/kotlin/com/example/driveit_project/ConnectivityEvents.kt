package com.example.driveit_project

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

/** A validated default network is a retry hint, not proof the backend works. */
class ConnectivityEvents(context: Context, messenger: BinaryMessenger) : EventChannel.StreamHandler {
    private val manager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private val channel = EventChannel(messenger, "driveit/connectivity")
    private val handler = Handler(Looper.getMainLooper())
    private var callback: ConnectivityManager.NetworkCallback? = null
    private var sink: EventChannel.EventSink? = null
    private var lastValue: Boolean? = null

    init { channel.setStreamHandler(this) }

    private fun publishCurrent() {
        handler.post {
            val currentSink = sink ?: return@post
            val capabilities = manager.getNetworkCapabilities(manager.activeNetwork)
            val validated = capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true &&
                capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
            if (validated != lastValue) {
                lastValue = validated
                currentSink.success(validated)
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        stop()
        sink = events
        val observer = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) = publishCurrent()
            override fun onLost(network: Network) = publishCurrent()
            override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) = publishCurrent()
        }
        try {
            manager.registerDefaultNetworkCallback(observer)
            callback = observer
            publishCurrent()
        } catch (error: RuntimeException) {
            sink = null
            events.error("network_monitor_unavailable", "Network monitoring unavailable", null)
        }
    }

    override fun onCancel(arguments: Any?) = stop()

    private fun stop() {
        sink = null
        lastValue = null
        callback?.let { manager.unregisterNetworkCallback(it) }
        callback = null
    }

    fun close() {
        stop()
        channel.setStreamHandler(null)
    }
}
