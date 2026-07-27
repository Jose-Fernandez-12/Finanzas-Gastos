import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database_service.dart';
import '../core/health_score_calculator.dart';

final dashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  // Aquí podemos seguir usando la lógica de Dashboard original o adaptarla al DAO.
  // Por simplicidad en la transición, traemos la lógica central del dashboard.
  
  final now = DateTime.now();
  final mesActual = "${now.year}-${now.month.toString().padLeft(2, '0')}";

  final ingresos = await DatabaseService.instance.query(
    "SELECT SUM(monto) as total FROM ingresos WHERE mes_referencia = ? OR es_fijo = 1",
    [mesActual]
  );
  final ingresosMes = (ingresos.first['total'] as num?)?.toDouble() ?? 0.0;

  final gastos = await DatabaseService.instance.query(
    "SELECT COALESCE(SUM(monto), 0) as total FROM gastos_fijos WHERE activo = 1 AND (es_fijo = 1 OR mes_referencia = ?) AND nombre NOT LIKE 'Cuota TC:%'",
    [mesActual]
  );
  final totalGastosFijos = (gastos.first['total'] as num?)?.toDouble() ?? 0.0;

  final tarjetasData = await DatabaseService.instance.query("SELECT * FROM tarjetas_credito WHERE activa = 1");
  double deudaTarjetas = 0.0;
  double cuotasTarjetasMes = 0.0;
  for (var t in tarjetasData) {
    final cupoTotal = (t['cupo_total'] as num?)?.toDouble() ?? 0.0;
    final cupoDispo = (t['cupo_disponible'] as num?)?.toDouble() ?? 0.0;
    deudaTarjetas += (cupoTotal - cupoDispo);
    final cuotas = await DatabaseService.instance.query(
      "SELECT COALESCE(SUM(valor_cuota), 0) as total FROM cuotas_amortizacion WHERE tarjeta_id = ? AND (strftime('%Y-%m', fecha_vencimiento) = ? OR strftime('%Y-%m', fecha_pago_real) = ?) AND estado IN ('PENDIENTE', 'PAGADA')",
      [t['id'], mesActual, mesActual]
    );
    cuotasTarjetasMes += (cuotas.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  final cuentasCobrarData = await DatabaseService.instance.query("SELECT SUM(saldo_pendiente) as total FROM cuentas_cobrar WHERE estado IN ('AL_DIA', 'MORA')");
  final cuentasCobrar = (cuentasCobrarData.first['total'] as num?)?.toDouble() ?? 0.0;

  final cuentasEnMora = await DatabaseService.instance.query("SELECT * FROM cuentas_cobrar WHERE estado = 'MORA'");

  final ahorrosData = await DatabaseService.instance.query("SELECT * FROM bolsillos_ahorro WHERE activo = 1");
  double totalAhorros = 0.0;
  for (var a in ahorrosData) {
    totalAhorros += (a['monto_actual'] as num?)?.toDouble() ?? 0.0;
  }

  final totalEgresos = totalGastosFijos + cuotasTarjetasMes;
  final liquidezDisponible = ingresosMes - totalEgresos;
  final porcentajeEndeudamiento = ingresosMes > 0 ? (totalEgresos / ingresosMes) * 100 : 0.0;
  
  String nivelRiesgo = 'BAJO';
  if (porcentajeEndeudamiento > 60) nivelRiesgo = 'ALTO';
  else if (porcentajeEndeudamiento > 40) nivelRiesgo = 'MEDIO';

  final proximasCuotasQuery = await DatabaseService.instance.query('''
    SELECT 
      c.id as cuota_id, c.numero_cuota, c.fecha_vencimiento, c.valor_cuota, c.estado,
      comp.id as compra_id, comp.descripcion as compra_descripcion,
      t.id as tarjeta_id, t.nombre_tarjeta, t.banco, t.color
    FROM cuotas_amortizacion c
    JOIN compras_tarjeta comp ON c.compra_id = comp.id
    JOIN tarjetas_credito t ON c.tarjeta_id = t.id
    WHERE c.estado = 'PENDIENTE' 
      AND date(c.fecha_vencimiento) BETWEEN date('now') AND date('now', '+45 days')
    ORDER BY date(c.fecha_vencimiento) ASC
    LIMIT 10
  ''');

  final Map<String, dynamic> innerData = {
    'capacidad_crediticia': {
      'ingresos_mes': ingresosMes,
      'total_gastos_fijos': totalGastosFijos,
      'cuotas_tarjetas_mes': cuotasTarjetasMes,
      'liquidez_disponible': liquidezDisponible,
      'porcentaje_endeudamiento': porcentajeEndeudamiento,
      'nivel_riesgo': nivelRiesgo
    },
    'totales': {
      'deuda_tarjetas': deudaTarjetas,
      'cuentas_cobrar': cuentasCobrar,
      'total_ahorros': totalAhorros
    },
    'tarjetas': tarjetasData,
    'proximas_cuotas': proximasCuotasQuery,
    'cuentas_en_mora': cuentasEnMora,
    'ahorros': ahorrosData
  };

  final healthScore = calculateHealthScore(innerData);

  return {
    'ok': true,
    'data': {
      ...innerData,
      'health_score': healthScore,
    }
  };
});

