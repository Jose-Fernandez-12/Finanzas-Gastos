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
        var instance: NotificationListener? = null
        private const val TAG = "GastosNotifListener"
        private const val PREFS_NAME = "gastos_notif_prefs"
        private const val KEY_LOGGING_ENABLED = "logging_enabled"
        private const val KEY_RAW_LOGS = "raw_logs"
        private const val KEY_PENDING_TRANSACTIONS = "pending_transactions"
        private const val MAX_LOGS = 100

        // Packages de apps financieras soportadas
        val SUPPORTED_PACKAGES = mapOf(
            "com.google.android.apps.walletnfcrel" to "Google Pay",
            "com.google.android.gms"              to "Google Pay",
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
                Triple(
                    Regex("""(?:[\$\$]|COP[\$\s]*)\s*([\d.,]+)""", RegexOption.IGNORE_CASE),
                    Regex("""en\s+(.+?)(?:\s+con|\s*$)""", RegexOption.IGNORE_CASE),
                    "credito"
                )
            ),
            "com.google.android.gms" to listOf(
                Triple(
                    Regex("""(?:[\$\$]|COP[\$\s]*)\s*([\d.,]+)""", RegexOption.IGNORE_CASE),
                    Regex("""en\s+(.+?)(?:\s+con|\s*$)""", RegexOption.IGNORE_CASE),
                    "credito"
                )
            ),
            "com.nu.production" to listOf(
                // "Recibiste 13.000,00 en tu cuenta"
                Triple(
                    Regex("""(?:recibiste|llegó|transferencia|abono|consignación)[:\s]+(?:[\$\$]|COP[\$\s]*)?([\d.,]+)""", RegexOption.IGNORE_CASE),
                    Regex("""(?:dinero|transferencia)\s+de\s+(.+?)(?:\s+con|\s*\.|$)""", RegexOption.IGNORE_CASE),
                    "ingreso"
                ),
                // "Compra de $150.000 en Éxito aprobada"
                Triple(
                    Regex("""(?:[\$\$]|COP[\$\s]*)\s*([\d.,]+)""", RegexOption.IGNORE_CASE),
                    Regex("""en\s+(.+?)\s+aprobada""", RegexOption.IGNORE_CASE),
                    "credito"
                ),
                // "Avance de efectivo: $150.000"
                Triple(
                    Regex("""(?:[\$\$]|COP[\$\s]*)\s*([\d.,]+)""", RegexOption.IGNORE_CASE),
                    Regex("""avance de efectivo""", RegexOption.IGNORE_CASE),
                    "credito_avance"
                )
            ),
            "com.bancolombia.smv" to listOf(
                // "Compra por $150,000 en EXITO con tu tarjeta"
                Triple(
                    Regex("""(?:[\$\$]|COP[\$\s]*)\s*([\d.,]+)""", RegexOption.IGNORE_CASE),
                    Regex("""en\s+(.+?)\s+con\s+tu""", RegexOption.IGNORE_CASE),
                    "credito"
                ),
                // "Retiro $150,000 — debito"
                Triple(
                    Regex("""(?:[\$\$]|COP[\$\s]*)\s*([\d.,]+)""", RegexOption.IGNORE_CASE),
                    Regex("""Retiro|ATM""", RegexOption.IGNORE_CASE),
                    "debito"
                )
            ),
            "com.rappi.pay" to listOf(
                Triple(
                    Regex("""(?:[\$\$]|COP[\$\s]*)\s*([\d.,]+)""", RegexOption.IGNORE_CASE),
                    Regex("""en\s+(.+?)(?:\s+con|\s*$)""", RegexOption.IGNORE_CASE),
                    "credito"
                )
            ),
            "com.nequi.mobilebanking" to listOf(
                // "Transferencia de $50.000 a Juan"
                Triple(
                    Regex("""(?:[\$\$]|COP[\$\s]*)\s*([\d.,]+)""", RegexOption.IGNORE_CASE),
                    Regex("""a\s+(.+?)(?:\.|$)""", RegexOption.IGNORE_CASE),
                    "debito"
                )
            ),
            "co.com.davivienda.mobileapp" to listOf(
                Triple(
                    Regex("""(?:[\$\$]|COP[\$\s]*)\s*([\d.,]+)""", RegexOption.IGNORE_CASE),
                    Regex("""en\s+(.+?)(?:\s+con|\s*$)""", RegexOption.IGNORE_CASE),
                    "credito"
                )
            )
        )

        fun parseAmount(raw: String): Double? {
            val trimmed = raw.trim()
            // Si termina en decimales exactos (.XX o .X, por ejemplo 3,500.00)
            if (trimmed.matches(Regex("""^.*\.\d{1,2}$"""))) {
                val idx = trimmed.lastIndexOf('.')
                val intPart = trimmed.substring(0, idx).replace(".", "").replace(",", "")
                val decPart = trimmed.substring(idx + 1)
                return "$intPart.$decPart".toDoubleOrNull()
            }
            // Si termina en decimales con coma (,XX o ,X, por ejemplo 3.500,00)
            if (trimmed.matches(Regex("""^.*,\d{1,2}$"""))) {
                val idx = trimmed.lastIndexOf(',')
                val intPart = trimmed.substring(0, idx).replace(".", "").replace(",", "")
                val decPart = trimmed.substring(idx + 1)
                return "$intPart.$decPart".toDoubleOrNull()
            }
            // Si no tiene decimales al final (.XX o ,XX), entonces todo punto o coma es separador de miles
            val cleaned = trimmed.replace(".", "").replace(",", "")
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

    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
        Log.d(TAG, "NotificationListenerService conectado")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        instance = null
        Log.d(TAG, "NotificationListenerService desconectado")
    }

    fun fetchAndProcessActiveNotifications() {
        Log.d(TAG, "Fetching active notifications...")
        try {
            val activeNotifs = activeNotifications ?: return
            for (sbn in activeNotifs) {
                // Call the existing method to process it
                onNotificationPosted(sbn)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error fetching active notifications", e)
        }
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
        
        // 1. Intentar con los parsers específicos del paquete
        val parsers = PARSERS[pkg] ?: emptyList()
        var montoEncontrado: Double? = null
        var comercioEncontrado: String = ""
        var tipoEncontrado: String = "desconocido"

        for ((montoRegex, comercioRegex, tipo) in parsers) {
            val montoMatch = montoRegex.find(texto) ?: continue
            val montoRaw = montoMatch.groupValues.getOrNull(1) ?: continue
            val monto = parseAmount(montoRaw) ?: continue
            if (monto <= 0) continue

            montoEncontrado = monto
            val comercioMatch = comercioRegex.find(texto)
            comercioEncontrado = comercioMatch?.groupValues?.getOrNull(1)?.trim() ?: ""
            tipoEncontrado = tipo
            break
        }

        // 2. Fallback universal si no coincidió el montoRegex específico:
        // Buscar cualquier monto como COP3,500.00 o $150.000 o "Recibiste 13.000,00" en el texto
        if (montoEncontrado == null) {
            val universalMontoRegex = Regex("""(?:[\$\$]|COP[\$\s]*|(?:recibiste|llegó|transferencia|abono|consignación)[:\s]+(?:[\$\$]|COP[\$\s]*)?)\s*([\d.,]+)""", RegexOption.IGNORE_CASE)
            val montoMatch = universalMontoRegex.find(texto)
            if (montoMatch != null) {
                val montoRaw = montoMatch.groupValues.getOrNull(1) ?: ""
                val monto = parseAmount(montoRaw)
                if (monto != null && monto > 0) {
                    montoEncontrado = monto
                }
            }
        }

        if (montoEncontrado == null || montoEncontrado <= 0) {
            return null
        }

        // 3. Si el comercio no se extrajo por regex, deducirlo del título o texto
        if (comercioEncontrado.isBlank()) {
            // Intentar extraer remitente de ingreso ("dinero de JOSE ISMAEL...")
            val remitenteMatch = Regex("""(?:dinero|transferencia)\s+de\s+(.+?)(?:\s+con|\s*\.|$)""", RegexOption.IGNORE_CASE).find(texto)
            if (remitenteMatch != null) {
                comercioEncontrado = remitenteMatch.groupValues[1].trim()
            } else {
                // Para Google Pay u otras donde el título es "GOOGLE *Minecraft" o "Uber"
                val lim = titulo.replace(Regex("""^GOOGLE\s*\*?""", RegexOption.IGNORE_CASE), "").trim()
                if (lim.isNotEmpty() && !lim.equals("Google Pay", ignoreCase = true) && !lim.contains("Compra", ignoreCase = true) && !lim.contains("Notificación", ignoreCase = true) && !lim.contains("Recibiste", ignoreCase = true)) {
                    comercioEncontrado = lim
                } else {
                    // Si no, tomar las primeras palabras del título o cuerpo como referencia
                    comercioEncontrado = if (titulo.isNotBlank() && !titulo.contains("Recibiste", ignoreCase = true)) titulo else "Ingreso / Transferencia"
                }
            }
        }

        // 4. Detectar tipo según keywords en el texto (tanto español como inglés)
        val tipoFinal = when {
            texto.contains("recibiste", ignoreCase = true) ||
            texto.contains("llegó dinero", ignoreCase = true) ||
            texto.contains("llego dinero", ignoreCase = true) ||
            texto.contains("consignación", ignoreCase = true) ||
            texto.contains("consignacion", ignoreCase = true) ||
            texto.contains("transferencia recibida", ignoreCase = true) ||
            texto.contains("abono", ignoreCase = true) ||
            tipoEncontrado == "ingreso" -> "ingreso"
            texto.contains("avance", ignoreCase = true) -> "credito_avance"
            texto.contains("débito", ignoreCase = true) ||
            texto.contains("debito", ignoreCase = true) ||
            texto.contains("debit", ignoreCase = true) ||
            texto.contains("retiro", ignoreCase = true) -> "debito"
            texto.contains("crédito", ignoreCase = true) ||
            texto.contains("credito", ignoreCase = true) ||
            texto.contains("credit", ignoreCase = true) ||
            tipoEncontrado == "credito" -> "credito"
            else -> "desconocido"
        }

        return Triple(montoEncontrado, comercioEncontrado, tipoFinal)
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
