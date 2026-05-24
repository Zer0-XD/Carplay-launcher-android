package com.zero.dashflow_launcher

import android.appwidget.AppWidgetHost
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.AdaptiveIconDrawable
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.media.AudioManager
import android.net.ConnectivityManager
import android.net.ConnectivityManager.NetworkCallback
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.TrafficStats
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.net.wifi.WifiInfo
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.os.Build
import android.os.Debug
import android.provider.Settings
import android.view.WindowManager
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : FlutterActivity() {

    private val APP_CHANNEL    = "com.zero.dashflow_launcher/apps"
    private val SYS_CHANNEL    = "com.zero.dashflow_launcher/system"
    private val WIFI_CHANNEL   = "com.zero.dashflow_launcher/wifi"
    private val BT_CHANNEL     = "com.zero.dashflow_launcher/bluetooth"
    private val MEDIA_CHANNEL  = "com.zero.dashflow_launcher/media"
    private val QUICK_CHANNEL  = "com.zero.dashflow_launcher/quick_controls"
    private val POWER_CHANNEL  = "com.zero.dashflow_launcher/power_events"

    private lateinit var appWidgetHost: AppWidgetHost
    private lateinit var widgetChannel: AppWidgetChannel

    // Power event EventChannel sink — null when Flutter is not listening
    private var powerEventSink: EventChannel.EventSink? = null
    private var powerReceiver: BroadcastReceiver? = null

    // WiFi TX/RX tracking (per-interface via /sys/class/net)
    private var lastTxBytes = 0L
    private var lastRxBytes = 0L
    private var lastTrafficTime = 0L
    // Cached scan results and connected SSID from callbacks
    private var cachedScanResults: List<android.net.wifi.ScanResult> = emptyList()
    private var connectedSsidFromCallback: String? = null
    private var connectedBssid: String? = null
    private var scanReceiver: BroadcastReceiver? = null
    private var wifiNetworkCallback: NetworkCallback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // App widget host — start listening for updates
        appWidgetHost = AppWidgetHost(this, WIDGET_HOST_ID)
        appWidgetHost.startListening()

        // Register the PlatformView factory so Flutter can embed widget views
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "com.zero.dashflow_launcher/widget_view",
            AppWidgetHostViewFactory(this, appWidgetHost),
        )

        // Register the widget management method channel
        widgetChannel = AppWidgetChannel(this, appWidgetHost, flutterEngine)

        registerAppChannel(flutterEngine)
        registerSystemChannel(flutterEngine)
        registerWifiChannel(flutterEngine)
        registerBluetoothChannel(flutterEngine)
        registerMediaChannel(flutterEngine)
        registerQuickControlsChannel(flutterEngine)
        registerPowerChannel(flutterEngine)
        registerScanReceiver()
        registerWifiNetworkCallback()
    }

    override fun onStart() {
        super.onStart()
        appWidgetHost.startListening()
    }

    override fun onStop() {
        super.onStop()
        appWidgetHost.stopListening()
    }

    override fun onDestroy() {
        super.onDestroy()
        scanReceiver?.let { unregisterReceiver(it) }
        powerReceiver?.let { unregisterReceiver(it) }
        wifiNetworkCallback?.let {
            (getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager)
                .unregisterNetworkCallback(it)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        widgetChannel.onActivityResult(requestCode, resultCode, data)
    }

    // ── Power events channel ──────────────────────────────────────────────────
    // Emits "screen_off", "screen_on", or "shutdown" strings to Flutter.
    // On ACTION_SHUTDOWN we also send a media pause before the sink fires so
    // music stops even if Flutter doesn't process the event in time.
    private fun registerPowerChannel(engine: FlutterEngine) {
        EventChannel(engine.dartExecutor.binaryMessenger, POWER_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    powerEventSink = events
                    val filter = IntentFilter().apply {
                        addAction(Intent.ACTION_SCREEN_OFF)
                        addAction(Intent.ACTION_SCREEN_ON)
                        addAction(Intent.ACTION_SHUTDOWN)
                    }
                    powerReceiver = object : BroadcastReceiver() {
                        override fun onReceive(ctx: Context, intent: Intent) {
                            when (intent.action) {
                                Intent.ACTION_SHUTDOWN -> {
                                    // Pause immediately — don't wait for Flutter
                                    try {
                                        MediaSessionService.sendCommand(ctx, "pause")
                                    } catch (_: Exception) {}
                                    events.success("shutdown")
                                }
                                Intent.ACTION_SCREEN_OFF -> events.success("screen_off")
                                Intent.ACTION_SCREEN_ON  -> events.success("screen_on")
                            }
                        }
                    }
                    registerReceiver(powerReceiver, filter)
                }

                override fun onCancel(arguments: Any?) {
                    powerReceiver?.let { unregisterReceiver(it) }
                    powerReceiver = null
                    powerEventSink = null
                }
            })
    }

    // ── App list / launch channel ─────────────────────────────────────────────

    private fun registerAppChannel(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, APP_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps" -> {
                        try {
                            result.success(getInstalledApps())
                        } catch (e: Exception) {
                            result.error("APPS_ERROR", e.message, null)
                        }
                    }
                    "launchApp" -> {
                        val pkg = call.argument<String>("packageName")
                        if (pkg == null) {
                            result.error("INVALID_ARG", "packageName required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            launchApp(pkg)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("LAUNCH_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getInstalledApps(): List<Map<String, Any?>> {
        val pm = packageManager
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }

        @Suppress("DEPRECATION")
        val activities = pm.queryIntentActivities(intent, 0)

        return activities
            .filter { it.activityInfo.packageName != packageName }
            .sortedBy { it.loadLabel(pm).toString().lowercase() }
            .map { info ->
                val pkg = info.activityInfo.packageName
                val label = info.loadLabel(pm).toString()
                val icon = try { encodeIcon(info.loadIcon(pm)) } catch (e: Exception) { null }
                mapOf("packageName" to pkg, "label" to label, "icon" to icon)
            }
    }

    private fun encodeIcon(drawable: Drawable): ByteArray? {
        val size = 96
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        when {
            drawable is BitmapDrawable -> {
                drawable.setBounds(0, 0, size, size)
                drawable.draw(canvas)
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                    drawable is AdaptiveIconDrawable -> {
                drawable.setBounds(0, 0, size, size)
                drawable.draw(canvas)
            }
            else -> {
                drawable.setBounds(0, 0, size, size)
                drawable.draw(canvas)
            }
        }
        return ByteArrayOutputStream(4096).use { stream ->
            val compressed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                bitmap.compress(Bitmap.CompressFormat.WEBP_LOSSY, 80, stream)
            } else {
                @Suppress("DEPRECATION")
                bitmap.compress(Bitmap.CompressFormat.WEBP, 80, stream)
            }
            bitmap.recycle()
            if (compressed) stream.toByteArray() else null
        }
    }

    private fun launchApp(packageName: String) {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
            ?: throw IllegalArgumentException("No launch intent for $packageName")
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    // ── System stats channel ──────────────────────────────────────────────────

    private val BT_PERMISSION_REQUEST_CODE = 1001

    private fun registerSystemChannel(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, SYS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSystemStats" -> result.success(getSystemStats())
                    "isBluetoothPermissionGranted" -> {
                        result.success(isBluetoothPermissionGranted())
                    }
                    "requestBluetoothPermission" -> {
                        requestBluetoothPermissions()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isBluetoothPermissionGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            checkSelfPermission(android.Manifest.permission.BLUETOOTH_CONNECT) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            checkSelfPermission(android.Manifest.permission.BLUETOOTH) ==
                PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestBluetoothPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            requestPermissions(
                arrayOf(
                    android.Manifest.permission.BLUETOOTH_CONNECT,
                    android.Manifest.permission.BLUETOOTH_SCAN,
                ),
                BT_PERMISSION_REQUEST_CODE,
            )
        } else {
            requestPermissions(
                arrayOf(android.Manifest.permission.BLUETOOTH),
                BT_PERMISSION_REQUEST_CODE,
            )
        }
    }

    private fun getSystemStats(): Map<String, Any> {
        val memInfo = Debug.MemoryInfo()
        Debug.getMemoryInfo(memInfo)
        val memUsedMb = memInfo.totalPss / 1024.0
        val hasNetwork = checkNetworkConnectivity()
        return mapOf(
            "speedKmh" to 0.0,
            "cpuPercent" to readCpuUsage(),
            "memUsedMb" to memUsedMb,
            "hasNetwork" to hasNetwork,
            "hasGps" to true,
            "signalBars" to getSignalBars(),
        )
    }

    private fun checkNetworkConnectivity(): Boolean {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val network = cm.activeNetwork ?: return false
            val caps = cm.getNetworkCapabilities(network) ?: return false
            caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        } else {
            @Suppress("DEPRECATION")
            cm.activeNetworkInfo?.isConnected == true
        }
    }

    private fun readCpuUsage(): Double {
        return try {
            val stat = java.io.File("/proc/stat").bufferedReader().readLine()
            val tokens = stat.split("\\s+".toRegex()).drop(1).map { it.toLong() }
            val idle = tokens[3]
            val total = tokens.sum()
            if (total == 0L) 0.0 else ((total - idle).toDouble() / total) * 100
        } catch (e: Exception) {
            0.0
        }
    }

    private fun getSignalBars(): Int = 3

    // ── WiFi channel ──────────────────────────────────────────────────────────

    private fun registerWifiChannel(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, WIFI_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanWifi" -> {
                        try {
                            triggerScan()
                            result.success(buildScanResults())
                        } catch (e: Exception) {
                            result.error("WIFI_ERROR", e.message, null)
                        }
                    }
                    "connectWifi" -> {
                        val ssid = call.argument<String>("ssid")
                        val password = call.argument<String>("password") ?: ""
                        if (ssid == null) {
                            result.error("INVALID_ARG", "ssid required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            connectWifi(ssid, password)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("WIFI_ERROR", e.message, null)
                        }
                    }
                    "disconnectWifi" -> {
                        try {
                            disconnectWifi()
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("WIFI_ERROR", e.message, null)
                        }
                    }
                    "getWifiStatus" -> {
                        try {
                            result.success(getWifiStatus())
                        } catch (e: Exception) {
                            result.error("WIFI_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Register a BroadcastReceiver so we get scan results as soon as they arrive.
    private fun registerScanReceiver() {
        scanReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                if (intent.action != WifiManager.SCAN_RESULTS_AVAILABLE_ACTION) return
                val wm = ctx.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                @Suppress("DEPRECATION")
                cachedScanResults = wm.scanResults ?: emptyList()
            }
        }
        registerReceiver(
            scanReceiver,
            IntentFilter(WifiManager.SCAN_RESULTS_AVAILABLE_ACTION),
        )
        // Seed with whatever is already cached
        val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        @Suppress("DEPRECATION")
        cachedScanResults = wm.scanResults ?: emptyList()
    }

    // On API 31+ wm.connectionInfo() always returns <unknown ssid> without a
    // NetworkCallback.  Register one so we always have the real SSID.
    private fun registerWifiNetworkCallback() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .build()
        wifiNetworkCallback = object : NetworkCallback(FLAG_INCLUDE_LOCATION_INFO) {
            override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
                val info = caps.transportInfo as? WifiInfo
                connectedSsidFromCallback = info?.ssid
                    ?.takeIf { it != "<unknown ssid>" }
                    ?.removePrefix("\"")?.removeSuffix("\"")
                connectedBssid = info?.bssid
            }
            override fun onLost(network: Network) {
                connectedSsidFromCallback = null
                connectedBssid = null
            }
        }
        cm.registerNetworkCallback(request, wifiNetworkCallback!!)
    }

    private fun triggerScan() {
        val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        @Suppress("DEPRECATION")
        wm.startScan()
        // Also refresh from current cached list in case receiver fired already
        @Suppress("DEPRECATION")
        cachedScanResults = wm.scanResults ?: cachedScanResults
    }

    private fun buildScanResults(): List<Map<String, Any?>> {
        val connectedSsid = resolveConnectedSsid()
        return cachedScanResults
            .filter { it.SSID.isNotBlank() }
            .distinctBy { it.SSID }
            .sortedByDescending { it.level }
            .map { sr ->
                val isConnected = connectedSsid != null && sr.SSID == connectedSsid
                mapOf(
                    "ssid" to sr.SSID,
                    "level" to sr.level,
                    "bars" to WifiManager.calculateSignalLevel(sr.level, 4),
                    "secured" to sr.capabilities.contains("WPA", ignoreCase = true),
                    "connected" to isConnected,
                )
            }
    }

    // Returns the plain SSID (no quotes) of the currently connected network.
    private fun resolveConnectedSsid(): String? {
        // API 31+: use the value from our NetworkCallback
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return connectedSsidFromCallback
        }
        // API < 31: connectionInfo still works
        val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        @Suppress("DEPRECATION")
        val info = wm.connectionInfo ?: return null
        val raw = info.ssid ?: return null
        return if (raw == "<unknown ssid>") null
        else raw.removePrefix("\"").removeSuffix("\"")
    }

    @Suppress("DEPRECATION")
    private fun connectWifi(ssid: String, password: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            connectWifiModern(ssid, password)
        } else {
            val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val conf = WifiConfiguration().apply {
                SSID = "\"$ssid\""
                if (password.isNotEmpty()) {
                    preSharedKey = "\"$password\""
                } else {
                    allowedKeyManagement.set(WifiConfiguration.KeyMgmt.NONE)
                }
            }
            val netId = wm.addNetwork(conf)
            wm.disconnect()
            wm.enableNetwork(netId, true)
            wm.reconnect()
        }
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun connectWifiModern(ssid: String, password: String) {
        val specifier = if (password.isNotEmpty()) {
            WifiNetworkSpecifier.Builder().setSsid(ssid).setWpa2Passphrase(password).build()
        } else {
            WifiNetworkSpecifier.Builder().setSsid(ssid).build()
        }
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .setNetworkSpecifier(specifier)
            .build()
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val cb = object : NetworkCallback() {
            override fun onAvailable(network: Network) {
                cm.bindProcessToNetwork(network)
            }
        }
        // Keep reference so we don't leak the old one
        wifiNetworkCallback?.let { cm.unregisterNetworkCallback(it) }
        wifiNetworkCallback = cb
        cm.requestNetwork(request, cb)
    }

    @Suppress("DEPRECATION")
    private fun disconnectWifi() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // For API 29+: release the requested network
            wifiNetworkCallback?.let {
                val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                try { cm.unregisterNetworkCallback(it) } catch (_: Exception) {}
            }
            wifiNetworkCallback = null
            connectedSsidFromCallback = null
            // Re-register the passive observer
            registerWifiNetworkCallback()
        } else {
            val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            wm.disconnect()
        }
    }

    private fun getWifiStatus(): Map<String, Any?> {
        val ssid = resolveConnectedSsid()
        val isConnected = ssid != null

        // Read per-WiFi-interface byte counters from sysfs (more accurate than TrafficStats total)
        val ifaceBytes = readWifiIfaceBytes()
        val now = System.currentTimeMillis()

        var txKbps = 0.0
        var rxKbps = 0.0
        if (lastTrafficTime > 0 && now > lastTrafficTime && ifaceBytes != null) {
            val dt = (now - lastTrafficTime) / 1000.0
            txKbps = ((ifaceBytes.first - lastTxBytes) / 1024.0) / dt
            rxKbps = ((ifaceBytes.second - lastRxBytes) / 1024.0) / dt
        }
        if (ifaceBytes != null) {
            lastTxBytes = ifaceBytes.first
            lastRxBytes = ifaceBytes.second
        }
        lastTrafficTime = now

        // RSSI
        val rssi: Int
        val bars: Int
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Get from cached scan result that matches connected BSSID
            val sr = cachedScanResults.firstOrNull { it.BSSID == connectedBssid }
            rssi = sr?.level ?: -100
            bars = WifiManager.calculateSignalLevel(rssi, 4)
        } else {
            val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            @Suppress("DEPRECATION")
            val info = wm.connectionInfo
            rssi = info?.rssi ?: -100
            bars = WifiManager.calculateSignalLevel(rssi, 4)
        }

        return mapOf(
            "connected" to isConnected,
            "ssid" to (ssid ?: ""),
            "txKbps" to txKbps.coerceAtLeast(0.0),
            "rxKbps" to rxKbps.coerceAtLeast(0.0),
            "bars" to bars,
            "rssi" to rssi,
        )
    }

    // Returns Pair(txBytes, rxBytes) for the first active WiFi interface found in sysfs.
    private fun readWifiIfaceBytes(): Pair<Long, Long>? {
        return try {
            val netDir = File("/sys/class/net")
            val wifiIface = netDir.listFiles()
                ?.map { it.name }
                ?.firstOrNull { name ->
                    name.startsWith("wlan") ||
                    File("/sys/class/net/$name/wireless").exists()
                } ?: return null
            val tx = File("/sys/class/net/$wifiIface/statistics/tx_bytes").readText().trim().toLong()
            val rx = File("/sys/class/net/$wifiIface/statistics/rx_bytes").readText().trim().toLong()
            Pair(tx, rx)
        } catch (_: Exception) {
            Pair(TrafficStats.getTotalTxBytes(), TrafficStats.getTotalRxBytes())
        }
    }

    // ── Bluetooth channel ─────────────────────────────────────────────────────

    private fun registerBluetoothChannel(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, BT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBluetoothStatus" -> {
                        try {
                            result.success(getBluetoothStatus())
                        } catch (e: Exception) {
                            result.error("BT_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getBluetoothStatus(): Map<String, Any?> {
        val bm = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = bm?.adapter

        if (adapter == null || !adapter.isEnabled) {
            return mapOf("enabled" to false, "connected" to false, "devices" to emptyList<Any>())
        }

        // Collect connected devices across A2DP (audio), HFP (headset/hands-free), HID (input)
        val connectedDevices = mutableListOf<Map<String, Any?>>()

        // getConnectedDevices is the simplest approach and covers most car use cases
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // API 31+: only query if BLUETOOTH_CONNECT is granted
                if (checkSelfPermission(android.Manifest.permission.BLUETOOTH_CONNECT)
                        != PackageManager.PERMISSION_GRANTED) {
                    return mapOf("enabled" to true, "connected" to false, "devices" to emptyList<Any>())
                }
                val profileIds = listOf(
                    BluetoothProfile.A2DP,
                    BluetoothProfile.HEADSET,
                )
                for (profileId in profileIds) {
                    adapter.getProfileProxy(this, object : BluetoothProfile.ServiceListener {
                        override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                            try {
                                for (dev in proxy.connectedDevices) {
                                    if (connectedDevices.none { it["address"] == dev.address }) {
                                        connectedDevices.add(deviceToMap(dev))
                                    }
                                }
                            } catch (_: SecurityException) {}
                            adapter.closeProfileProxy(profile, proxy)
                        }
                        override fun onServiceDisconnected(profile: Int) {}
                    }, profileId)
                }
            } else {
                @Suppress("DEPRECATION")
                val bonded = adapter.bondedDevices ?: emptySet<BluetoothDevice>()
                for (dev in bonded) {
                    try {
                        val method = dev.javaClass.getMethod("isConnected")
                        val isConn = method.invoke(dev) as? Boolean ?: false
                        if (isConn) connectedDevices.add(deviceToMap(dev))
                    } catch (_: Exception) {}
                }
            }
        } catch (_: SecurityException) {
            // Permission not granted yet — return safe empty state
        }

        return mapOf(
            "enabled" to true,
            "connected" to connectedDevices.isNotEmpty(),
            "devices" to connectedDevices,
        )
    }

    private fun deviceToMap(dev: BluetoothDevice): Map<String, Any?> {
        val name = try { dev.name } catch (_: SecurityException) { null }
        val address = try { dev.address } catch (_: SecurityException) { "unknown" }
        return mapOf(
            "name" to (name ?: "Unknown"),
            "address" to address,
            "type" to dev.type,
        )
    }

    // ── Media channel ─────────────────────────────────────────────────────────

    private fun registerMediaChannel(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, MEDIA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getMediaInfo" -> {
                        try {
                            result.success(MediaSessionService.getMediaInfo(this))
                        } catch (e: Exception) {
                            result.error("MEDIA_ERROR", e.message, null)
                        }
                    }
                    "mediaCommand" -> {
                        val cmd = call.argument<String>("command") ?: ""
                        val positionMs = call.argument<Long>("positionMs") ?: -1L
                        try {
                            MediaSessionService.sendCommand(this, cmd, positionMs)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("MEDIA_ERROR", e.message, null)
                        }
                    }
                    "isNotificationListenerGranted" -> {
                        result.success(isNotificationListenerGranted())
                    }
                    "openNotificationListenerSettings" -> {
                        try {
                            startActivity(Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS").apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            })
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("SETTINGS_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isNotificationListenerGranted(): Boolean {
        val flat = android.provider.Settings.Secure.getString(
            contentResolver, "enabled_notification_listeners"
        ) ?: return false
        // Each entry is "package/ComponentName"; split on ":" to get packages
        return flat.split(":").any { entry ->
            entry.trim().substringBefore("/") == packageName
        }
    }

    // ── Quick controls channel (volume, brightness, wifi/bt toggle) ───────────

    private fun registerQuickControlsChannel(engine: FlutterEngine) {
        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        MethodChannel(engine.dartExecutor.binaryMessenger, QUICK_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        // Volume ─────────────────────────────────────────────
                        "getVolume" -> {
                            val stream = call.argument<Int>("stream") ?: AudioManager.STREAM_MUSIC
                            val current = audio.getStreamVolume(stream)
                            val max = audio.getStreamMaxVolume(stream)
                            result.success(mapOf("current" to current, "max" to max))
                        }
                        "setVolume" -> {
                            val stream = call.argument<Int>("stream") ?: AudioManager.STREAM_MUSIC
                            val value = call.argument<Int>("value") ?: 0
                            val maxVol = audio.getStreamMaxVolume(stream)
                            val clamped = value.coerceIn(0, maxVol)
                            // FLAG_SHOW_UI (1) is required on many headunits — without it
                            // setStreamVolume is silently ignored by the audio policy service.
                            audio.setStreamVolume(stream, clamped, AudioManager.FLAG_SHOW_UI)
                            result.success(null)
                        }
                        // Brightness ─────────────────────────────────────────
                        "getBrightness" -> {
                            val bright = Settings.System.getInt(
                                contentResolver, Settings.System.SCREEN_BRIGHTNESS, 128
                            )
                            result.success(bright) // 0-255
                        }
                        "setBrightness" -> {
                            val value = call.argument<Int>("value") ?: 128
                            // Write system setting (requires WRITE_SETTINGS permission)
                            Settings.System.putInt(
                                contentResolver, Settings.System.SCREEN_BRIGHTNESS, value
                            )
                            // Also apply to current window immediately
                            val lp = window.attributes
                            lp.screenBrightness = value / 255f
                            window.attributes = lp
                            result.success(null)
                        }
                        // WiFi toggle ────────────────────────────────────────
                        "setWifiEnabled" -> {
                            val enabled = call.argument<Boolean>("enabled") ?: true
                            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                                @Suppress("DEPRECATION")
                                val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                                @Suppress("DEPRECATION")
                                wm.isWifiEnabled = enabled
                            } else {
                                // API 29+: direct toggle removed by Android; open settings panel
                                startActivity(Intent(Settings.Panel.ACTION_WIFI).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                })
                            }
                            result.success(null)
                        }
                        "getWifiEnabled" -> {
                            val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                            result.success(wm.isWifiEnabled)
                        }
                        // Bluetooth toggle ───────────────────────────────────
                        "setBluetoothEnabled" -> {
                            val enabled = call.argument<Boolean>("enabled") ?: true
                            val bm = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                            val adapter = bm?.adapter
                            if (adapter != null) {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                    // API 33+: must use intent
                                    startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS).apply {
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    })
                                } else {
                                    @Suppress("DEPRECATION")
                                    if (enabled) adapter.enable() else adapter.disable()
                                }
                            }
                            result.success(null)
                        }
                        "getBluetoothEnabled" -> {
                            val bm = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                            result.success(bm?.adapter?.isEnabled ?: false)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("QUICK_ERROR", e.message, null)
                }
            }
    }
}
