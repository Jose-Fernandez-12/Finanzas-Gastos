package com.example.gastos_e_ingresos

import android.app.Notification
import android.content.SharedPreferences
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class NotificationListener : NotificationListenerService() {

    companion object {
        private const val TAG = "GastosNotifListener"
        private const val PREFS_NAME = "gastos_notif_prefs"
        private const val KEY_LOGGING_ENABLED = "logging_enabled"
        private const val KEY_RAW_LOGS = "raw_logs"
        private const val KEY_PENDING_TRANSACTIONS = "pending_transactions"
        private const val MAX_LOGS = 100

        // Packages de apps financieras soportadas
        val SUPPORTED_PACKAGES = mapOf(
            "com.google.android.apps.walletnfcrel" to "Google Pay",
            "com.nu.production"                   to "Nu",
            "com.bancolombia.smv"                 to "Bancolombia",
            "com.rappi.pay"                       to "Rappi Pay",
            "com.nequi.mobilebanking"             to "Nequi",
            "co.com.davivienda.mobileapp"         to "Davivienda"
        )

        // Patrones regex para extraer monto y comercio por app
        // Formato: list de pares (montoRegex, comercioRegex, tipoTarjeta)
        val PARSERS = mapOf(
            "com.google.android.apps.walletnfcrel" to listOf(
                // "Pagaste $150.000 en Éxito con Tu Nu"
                Triple(
                    Regex("""[\$\$]\s*([\d.,]+)"""),
                    Regex("""en\s+(.+?)(?:\s+con|\s*$)""", RegexOption.IGNORE_CASE),
                    "credito"
                ),
                // "Compra aprobada: $150.000"
                Triple(
                    Regex("""[\$\$]\s*([\d.,]+)"""),
                    Regex("""en\s+(.+?)(?:\s+con|\s*$)""", RegexOption.IGNORE_CASE),
                    "desconocido"
                )
            ),
            "com.nu.production" to listOf(
                // "Compra de $150.000 en Éxito aprobada"
                Triple(
                    Regex("""[\$\$]\s*([\d.,]+)"""),
                    Regex("""en\s+(.+?)\s+aprobada""", RegexOption.IGNORE_CASE),
                    "credito"
                ),
                // "Avance de efectivo: $150.000"
                Triple(
                    Regex("""[\$\$]\s*([\d.,]+)"""),
                    Regex("""avance de efectivo""", RegexOption.IGNORE_CASE),
                    "credito_avance"
                )
            ),
            "com.bancolombia.smv" to listOf(
                // "Compra por $150,000 en EXITO con tu tarjeta"
                Triple(
                    Regex("""[\$\$]\s*([\d.,]+)"""),
                    Regex("""en\s+(.+?)\s+con\s+tu""", RegexOption.IGNORE_CASE),
                    "credito"
                ),
                // "Retiro $150,000 — debito"
                Triple(
                    Regex("""[\$\$]\s*([\d.,]+)"""),
                    Regex("""Retiro|ATM""", RegexOption.IGNORE_CASE),
                    "debito"
                )
            ),
            "com.rappi.pay" to listOf(
                Triple(
                    Regex("""[\$\$]\s*([\d.,]+)"""),
                    Regex("""en\s+(.+?)(?:\s+con|\s*$)""", RegexOption.IGNORE_CASE),
                    "credito"
                )
            ),
            "com.nequi.mobilebanking" to listOf(
                // "Transferencia de $50.000 a Juan"
                Triple(
                    Regex("""[\$\$]\s*([\d.,]+)"""),
                    Regex("""a\s+(.+?)(?:\.|$)""", RegexOption.IGNORE_CASE),
                    "debito"
                )
            ),
            "co.com.davivienda.mobileapp" to listOf(
                Triple(
                    Regex("""[\$\$]\s*([\d.,]+)"""),
                    Regex("""en\s+(.+?)(?:\s+con|\s*$)""", RegexOption.IGNORE_CASE),
                    "credito"
                )
            )
        )

        fun parseAmount(raw: String): Double? {
            // Limpia el monto: "1.500.000" o "1,500,000" o "150000" → 150000.0
            val cleaned = raw.replace(".", "").replace(",", "").trim()
            return cleaned.toDoubleOrNull()
        }
    }

    private lateinit var prefs: SharedPreferences
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())

    override fun onCreate() {
        super.onCreate()
        prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        Log.d(TAG, "NotificationListenerService creado")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn ?: return
        val pkg = sbn.packageName ?: return
        val appLabel = SUPPORTED_PACKAGES[pkg] ?: return // Solo apps soportadas

        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return

        val titulo = extras.getString(Notification.EXTRA_TITLE) ?: ""
        val cuerpo  = extras.getString(Notification.EXTRA_TEXT)
                    ?: extras.getString(Notification.EXTRA_BIG_TEXT)
                    ?: ""
        val timestamp = dateFormat.format(Date(sbn.postTime))

        Log.d(TAG, "Notificacion de $appLabel: titulo=$titulo, cuerpo=$cuerpo")

        val loggingEnabled = prefs.getBoolean(KEY_LOGGING_ENABLED, false)

        // 1. Intentar parsear la notificacion
        val parsed = tryParse(pkg, titulo, cuerpo)

        // 2. Si logging habilitado, guardar el raw log siempre
        if (loggingEnabled) {
            saveRawLog(
                pkg        = pkg,
                appLabel   = appLabel,
                titulo     = titulo,
                cuerpo     = cuerpo,
                timestamp  = timestamp,
                monto      = parsed?.first,
                comercio   = parsed?.second,
                tipoTarjeta= parsed?.third,
                parseado   = parsed != null
            )
        }

        // 3. Si se parseo exitosamente, guardar como transaccion pendiente
        if (parsed != null) {
            savePendingTransaction(
                appLabel   = appLabel,
                pkg        = pkg,
                titulo     = titulo,
                cuerpo     = cuerpo,
                monto      = parsed.first,
                comercio   = parsed.second,
                tipoTarjeta= parsed.third,
                timestamp  = timestamp
            )
            // Notificar a Flutter si esta corriendo via EventChannel handler en MainActivity
            MainActivity.sendNotificationEvent(this, pkg, parsed.first, parsed.second, parsed.third, timestamp)
        }
    }

    private fun tryParse(pkg: String, titulo: String, cuerpo: String): Triple<Double, String, String>? {
        val texto = "$titulo $cuerpo"
        val parsers = PARSERS[pkg] ?: return null

        for ((montoRegex, comercioRegex, tipo) in parsers) {
            val montoMatch = montoRegex.find(texto) ?: continue
            val montoRaw = montoMatch.groupValues.getOrNull(1) ?: continue
            val monto = parseAmount(montoRaw) ?: continue
            if (monto <= 0) continue

            // Comercio puede no encontrarse (queda como vacío)
            val comercioMatch = comercioRegex.find(texto)
            val comercio = comercioMatch?.groupValues?.getOrNull(1)?.trim() ?: ""

            // Detectar tipo según keywords en el texto
            val tipoFinal = when {
                texto.contains("avance", ignoreCase = true) -> "credito_avance"
                texto.contains("débito", ignoreCase = true) ||
                texto.contains("debito", ignoreCase = true) ||
                texto.contains("retiro", ignoreCase = true) -> "debito"
                else -> tipo
            }

            return Triple(monto, comercio, tipoFinal)
        }
        return null
    }

    private fun saveRawLog(
        pkg: String, appLabel: String, titulo: String, cuerpo: String,
        timestamp: String, monto: Double?, comercio: String?,
        tipoTarjeta: String?, parseado: Boolean
    ) {
        val logsJson = prefs.getString(KEY_RAW_LOGS, "[]")
        val logs = JSONArray(logsJson)

        val entry = JSONObject().apply {
            put("package_name", pkg)
            put("app_label", appLabel)
            put("titulo", titulo)
            put("cuerpo", cuerpo)
            put("timestamp", timestamp)
            put("monto_detectado", monto ?: JSONObject.NULL)
            put("comercio_detectado", comercio ?: JSONObject.NULL)
            put("tipo_tarjeta", tipoTarjeta ?: JSONObject.NULL)
            put("parseado", parseado)
        }

        // Insertar al inicio (mas recientes primero) y limitar a MAX_LOGS
        val newLogs = JSONArray()
        newLogs.put(entry)
        for (i in 0 until minOf(logs.length(), MAX_LOGS - 1)) {
            newLogs.put(logs.getJSONObject(i))
        }

        prefs.edit().putString(KEY_RAW_LOGS, newLogs.toString()).apply()
    }

    private fun savePendingTransaction(
        appLabel: String, pkg: String, titulo: String, cuerpo: String,
        monto: Double, comercio: String, tipoTarjeta: String, timestamp: String
    ) {
        val pendingJson = prefs.getString(KEY_PENDING_TRANSACTIONS, "[]")
        val pending = JSONArray(pendingJson)

        // Evitar duplicados: misma app + mismo monto + misma fecha (hasta minuto)
        val timestampMin = timestamp.substring(0, 16) // "yyyy-MM-dd HH:mm"
        for (i in 0 until pending.length()) {
            val p = pending.getJSONObject(i)
            if (p.optString("timestamp").startsWith(timestampMin) &&
                p.optDouble("monto") == monto &&
                p.optString("app_label") == appLabel) {
                Log.d(TAG, "Transaccion duplicada ignorada: $monto en $comercio")
                return
            }
        }

        val entry = JSONObject().apply {
            put("app_label", appLabel)
            put("package_name", pkg)
            put("titulo", titulo)
            put("cuerpo", cuerpo)
            put("monto", monto)
            put("comercio", comercio)
            put("tipo_tarjeta", tipoTarjeta)
            put("timestamp", timestamp)
        }
        pending.put(entry)
        prefs.edit().putString(KEY_PENDING_TRANSACTIONS, pending.toString()).apply()
        Log.d(TAG, "Transaccion pendiente guardada: $monto en $comercio ($tipoTarjeta)")
    }
}
