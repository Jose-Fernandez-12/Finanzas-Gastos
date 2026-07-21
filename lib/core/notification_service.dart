import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'local_repository.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification click if needed
      },
    );
  }

  Future<bool> requestPermissions() async {
    // Request permission for Android
    final androidImplementation = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }

    // Request permission for iOS
    final iosImplementation = _localNotifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosImplementation != null) {
      await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    return true;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'pagos_alertas_channel_id',
      'Alertas de Pago',
      channelDescription: 'Canal para avisar sobre vencimientos de facturas y deudas',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(id, title, body, platformDetails);
  }

  /// Revisa la base de datos y programa o dispara notificaciones inmediatamente si hay vencimientos en 3 días o menos
  Future<void> checkAndNotifyUpcomingPayments() async {
    try {
      final repo = LocalRepository.instance;
      final dashboardData = await repo.getDashboard();
      if (dashboardData['ok'] != true) return;

      final data = dashboardData['data'] as Map<String, dynamic>;
      
      // 1. Próximas cuotas de tarjetas en los próximos 3 días
      final proximasCuotas = data['proximas_cuotas'] as List<dynamic>? ?? [];
      final now = DateTime.now();
      final limitDate = now.add(const Duration(days: 3));

      int notificationId = 100;

      for (var c in proximasCuotas) {
        final Map<String, dynamic> cuota = Map<String, dynamic>.from(c);
        final fechaVencStr = cuota['fecha_vencimiento']?.toString();
        if (fechaVencStr != null) {
          final fechaVenc = DateTime.tryParse(fechaVencStr);
          if (fechaVenc != null && fechaVenc.isAfter(now.subtract(const Duration(days: 1))) && fechaVenc.isBefore(limitDate)) {
            final diffDays = fechaVenc.difference(now).inDays + 1;
            final desc = cuota['compra_descripcion'] ?? 'Compra';
            final valor = cuota['valor_cuota'] ?? 0.0;
            final tarjeta = cuota['nombre_tarjeta'] ?? 'Tarjeta';
            
            await showNotification(
              id: notificationId++,
              title: 'Vencimiento de Tarjeta Cercano',
              body: 'La cuota de "$desc" ($tarjeta) por \$${valor.toStringAsFixed(0)} vence en $diffDays día(s) (el $fechaVencStr).',
            );
          }
        }
      }

      // 2. Gastos fijos activos del mes que no se han pagado en los próximos 3 días
      final gastosFijosRes = await repo.getGastosFijos();
      if (gastosFijosRes['ok'] == true) {
        final listGastos = gastosFijosRes['data'] as List<dynamic>? ?? [];
        for (var g in listGastos) {
          final Map<String, dynamic> gasto = Map<String, dynamic>.from(g);
          final diaPago = (gasto['dia_pago'] as num?)?.toInt() ?? 0;
          if (diaPago > 0 && diaPago <= 31) {
            // Determinar la fecha de vencimiento este mes
            final vencimientoGasto = DateTime(now.year, now.month, diaPago);
            final ultimoPagoStr = gasto['fecha_ultimo_pago']?.toString();
            
            bool pagadoEsteMes = false;
            if (ultimoPagoStr != null && ultimoPagoStr.isNotEmpty) {
              final ultimoPago = DateTime.tryParse(ultimoPagoStr);
              if (ultimoPago != null && ultimoPago.year == now.year && ultimoPago.month == now.month) {
                pagadoEsteMes = true;
              }
            }

            if (!pagadoEsteMes && vencimientoGasto.isAfter(now.subtract(const Duration(days: 1))) && vencimientoGasto.isBefore(limitDate)) {
              final diffDays = vencimientoGasto.difference(now).inDays + 1;
              final nombre = gasto['nombre'] ?? 'Gasto Fijo';
              final monto = gasto['monto'] ?? 0.0;
              await showNotification(
                id: notificationId++,
                title: 'Pago de Gasto Fijo Pendiente',
                body: 'El gasto "$nombre" de \$${monto.toStringAsFixed(0)} vence en $diffDays día(s).',
              );
            }
          }
        }
      }

      // 3. Cuentas por cobrar en mora o con vencimiento cercano
      final cuentasCobrarRes = await repo.getCuentasCobrar();
      if (cuentasCobrarRes['ok'] == true) {
        final listCuentas = cuentasCobrarRes['data'] as List<dynamic>? ?? [];
        for (var c in listCuentas) {
          final Map<String, dynamic> cuenta = Map<String, dynamic>.from(c);
          final fechaVencStr = cuenta['fecha_primer_vencimiento']?.toString();
          final saldo = (cuenta['saldo_pendiente'] as num?)?.toDouble() ?? 0.0;
          final deudor = cuenta['nombre_deudor'] ?? 'Persona';
          final estado = cuenta['estado']?.toString();

          if (saldo > 0) {
            if (estado == 'MORA') {
              await showNotification(
                id: notificationId++,
                title: 'Deuda Vencida (Mora)',
                body: '$deudor te debe \$${saldo.toStringAsFixed(0)} y está retrasado.',
              );
            } else if (fechaVencStr != null) {
              final fechaVenc = DateTime.tryParse(fechaVencStr);
              if (fechaVenc != null && fechaVenc.isAfter(now.subtract(const Duration(days: 1))) && fechaVenc.isBefore(limitDate)) {
                final diffDays = fechaVenc.difference(now).inDays + 1;
                await showNotification(
                  id: notificationId++,
                  title: 'Cobro Próximo a Vencer',
                  body: '$deudor debe pagarte \$${saldo.toStringAsFixed(0)} en $diffDays día(s).',
                );
              }
            }
          }
        }
      }
      // 4. Suscripciones activas con cobro proximo segun su recordatorio_dias
      final suscripcionesList = await repo.getSuscripciones();
      for (var s in suscripcionesList) {
        final diaCobro = (s['dia_cobro'] as num?)?.toInt() ?? 1;
        final recordatorioDias = (s['recordatorio_dias'] as num?)?.toInt() ?? 1;
        final nombre   = s['nombre'] ?? 'Suscripcion';
        final monto    = (s['monto'] as num?)?.toDouble() ?? 0.0;

        // Calcular la fecha de cobro este mes; si ya paso, usar el mes siguiente
        DateTime fechaCobro = DateTime(now.year, now.month, diaCobro.clamp(1, 28));
        if (fechaCobro.isBefore(DateTime(now.year, now.month, now.day))) {
          fechaCobro = DateTime(now.year, now.month + 1, diaCobro.clamp(1, 28));
        }

        final diasRestantes = fechaCobro.difference(DateTime(now.year, now.month, now.day)).inDays;

        if (diasRestantes <= recordatorioDias && diasRestantes >= 0) {
          final textoTiempo = diasRestantes == 0
              ? 'hoy'
              : diasRestantes == 1
                  ? 'manana'
                  : 'en $diasRestantes dias';

          await showNotification(
            id: notificationId++,
            title: 'Suscripcion por cobrar: $nombre',
            body: 'Se te cobrara \$${monto.toStringAsFixed(0)} $textoTiempo (dia $diaCobro).',
          );
        }
      }
      // 5. Metas de ahorro
      final ahorrosRes = await repo.getAhorros();
      if (ahorrosRes['ok'] == true) {
        final listAhorros = ahorrosRes['data'] as List<dynamic>? ?? [];
        for (var a in listAhorros) {
          final Map<String, dynamic> ahorro = Map<String, dynamic>.from(a);
          final meta = (ahorro['meta_monto'] as num?)?.toDouble() ?? 0.0;
          final actual = (ahorro['monto_actual'] as num?)?.toDouble() ?? 0.0;
          final cuota = (ahorro['cuota_monto'] as num?)?.toDouble() ?? 0.0;
          final nombre = ahorro['nombre'] ?? 'Meta de ahorro';
          
          if (meta > 0 && actual < meta && cuota > 0) {
            // Un recordatorio para que no olvide separar su cuota
            await showNotification(
              id: notificationId++,
              title: '¡No olvides tu meta: $nombre!',
              body: 'Recuerda separar tu cuota de \$${cuota.toStringAsFixed(0)} para seguir acercandote a tu meta.',
            );
          }
        }
      }

    } catch (_) {
      // Ignorar silenciosamente en produccion
    }
  }
}

