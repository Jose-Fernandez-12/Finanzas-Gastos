package com.example.gastos_e_ingresos

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class MainActivity : FlutterActivity() {

    companion object {
        private const val METHOD_CHANNEL   = "gastos_app/notification_control"
        private const val EVENT_CHANNEL    = "gastos_app/notification_events"
        private const val PREFS_NAME       = "gastos_notif_prefs"

        private var eventSink: EventChannel.EventSink? = null

        /** Llamado desde NotificationListener cuando se detecta una compra y la app esta abierta */
        fun sendNotificationEvent(
            context: Context,
            pkg: String, monto: Double, comercio: String,
            tipoTarjeta: String, timestamp: String
        ) {
            eventSink?.success(mapOf(
                "package_name" to pkg,
                "monto"        to monto,
                "comercio"     to comercio,
                "tipo_tarjeta" to tipoTarjeta,
                "timestamp"    to timestamp
            ))
        }
    }

    private lateinit var prefs: SharedPreferences

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        // ---- MethodChannel: control del listener ----
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isPermissionGranted" -> {
                        result.success(isNotificationServiceEnabled())
                    }
                    "openPermissionSettings" -> {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        result.success(null)
                    }
                    "isLoggingEnabled" -> {
                        result.success(prefs.getBoolean("logging_enabled", false))
                    }
                    "setLoggingEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        prefs.edit().putBoolean("logging_enabled", enabled).apply()
                        result.success(null)
                    }
                    "getPendingTransactions" -> {
                        val json = prefs.getString("pending_transactions", "[]") ?: "[]"
                        result.success(json)
                    }
                    "clearPendingTransactions" -> {
                        prefs.edit().putString("pending_transactions", "[]").apply()
                        result.success(null)
                    }
                    "getRawLogs" -> {
                        val json = prefs.getString("raw_logs", "[]") ?: "[]"
                        result.success(json)
                    }
                    "clearRawLogs" -> {
                        prefs.edit().putString("raw_logs", "[]").apply()
                        result.success(null)
                    }
                    "dismissPendingTransaction" -> {
                        val index = call.argument<Int>("index") ?: return@setMethodCallHandler
                        dismissPending(index)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // ---- EventChannel: stream en tiempo real ----
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val pkgName = packageName
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: return false
        if (flat.isEmpty()) return false
        val names = flat.split(":")
        for (name in names) {
            val componentName = ComponentName.unflattenFromString(name) ?: continue
            if (pkgName == componentName.packageName) return true
        }
        return false
    }

    private fun dismissPending(index: Int) {
        val json = prefs.getString("pending_transactions", "[]") ?: "[]"
        val arr = JSONArray(json)
        val newArr = JSONArray()
        for (i in 0 until arr.length()) {
            if (i != index) newArr.put(arr.getJSONObject(i))
        }
        prefs.edit().putString("pending_transactions", newArr.toString()).apply()
    }
}
