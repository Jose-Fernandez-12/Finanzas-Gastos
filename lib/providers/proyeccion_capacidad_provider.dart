import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database_service.dart';

final proyeccionCapacidadProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, mesProyeccion) async {
  // mesProyeccion debe venir en formato "YYYY-MM"

  // 1. Ingresos proyectados (asumimos que los fijos se mantienen)
  // Nota: si el mes futuro no tiene ingresos variables registrados, solo tomará los fijos.
  final ingresos = await DatabaseService.instance.query(
    "SELECT SUM(monto) as total FROM ingresos WHERE mes_referencia = ? OR es_fijo = 1",
    [mesProyeccion]
  );
  final ingresosMes = (ingresos.first['total'] as num?)?.toDouble() ?? 0.0;

  // 2. Gastos fijos proyectados
  final gastos = await DatabaseService.instance.query(
    "SELECT COALESCE(SUM(monto), 0) as total FROM gastos_fijos WHERE activo = 1 AND (es_fijo = 1 OR mes_referencia = ?) AND nombre NOT LIKE 'Cuota TC:%'",
    [mesProyeccion]
  );
  final totalGastosFijos = (gastos.first['total'] as num?)?.toDouble() ?? 0.0;

  // 3. Cuotas de tarjetas proyectadas para ese mes futuro
  // Solo consideramos cuotas PENDIENTES o PAGADAS (por si alguien ya adelantó el pago de un mes futuro)
  final tarjetasData = await DatabaseService.instance.query("SELECT id FROM tarjetas_credito WHERE activa = 1");
  double cuotasTarjetasMes = 0.0;
  for (var t in tarjetasData) {
    final cuotas = await DatabaseService.instance.query(
      "SELECT COALESCE(SUM(valor_cuota), 0) as total FROM cuotas_amortizacion WHERE tarjeta_id = ? AND (strftime('%Y-%m', fecha_vencimiento) = ? OR strftime('%Y-%m', fecha_pago_real) = ?) AND estado IN ('PENDIENTE', 'PAGADA')",
      [t['id'], mesProyeccion, mesProyeccion]
    );
    cuotasTarjetasMes += (cuotas.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // 4. Cálculos finales
  final totalEgresos = totalGastosFijos + cuotasTarjetasMes;
  final liquidezDisponible = ingresosMes - totalEgresos;
  final porcentajeEndeudamiento = ingresosMes > 0 ? (totalEgresos / ingresosMes) * 100 : 0.0;
  
  String nivelRiesgo = 'BAJO';
  if (porcentajeEndeudamiento > 60) nivelRiesgo = 'ALTO';
  else if (porcentajeEndeudamiento > 40) nivelRiesgo = 'MEDIO';

  return {
    'ingresos_mes': ingresosMes,
    'total_gastos_fijos': totalGastosFijos,
    'cuotas_tarjetas_mes': cuotasTarjetasMes,
    'liquidez_disponible': liquidezDisponible,
    'porcentaje_endeudamiento': porcentajeEndeudamiento,
    'nivel_riesgo': nivelRiesgo
  };
});
