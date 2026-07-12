import '../database_service.dart';

class AnalyticsDao {
  static final AnalyticsDao instance = AnalyticsDao._();
  AnalyticsDao._();

  Future<Map<String, dynamic>> getAnalytics({double pctAbonoExtra = 0.0}) async {
    final tarjetasData = await DatabaseService.instance.query("SELECT SUM(cupo_total - cupo_disponible) as total FROM tarjetas_credito WHERE activa = 1");
    final deudaTarjetas = (tarjetasData.first['total'] as num?)?.toDouble() ?? 0.0;

    final cuentasCobrarData = await DatabaseService.instance.query("SELECT SUM(saldo_pendiente) as total FROM cuentas_cobrar WHERE estado IN ('AL_DIA', 'MORA')");
    final cuentasCobrar = (cuentasCobrarData.first['total'] as num?)?.toDouble() ?? 0.0;

    final now = DateTime.now();
    final mesActualStr = "${now.year}-${now.month.toString().padLeft(2, '0')}";
    
    // 1. Obtener ingresos del mes
    final ingresos = await DatabaseService.instance.query(
      "SELECT SUM(monto) as total FROM ingresos WHERE mes_referencia = ? OR es_fijo = 1",
      [mesActualStr]
    );
    final ingresosMes = (ingresos.first['total'] as num?)?.toDouble() ?? 0.0;

    // 2. Obtener gastos fijos del mes
    final gastos = await DatabaseService.instance.query(
      "SELECT SUM(monto) as total FROM gastos_fijos WHERE activo = 1 AND (es_fijo = 1 OR mes_referencia = ?)",
      [mesActualStr]
    );
    final totalGastosFijos = (gastos.first['total'] as num?)?.toDouble() ?? 0.0;

    // 3. Obtener cuota básica de tarjetas
    final cuotasBasicasQuery = await DatabaseService.instance.query(
      "SELECT SUM(c.valor_cuota) as total FROM cuotas_amortizacion c JOIN compras_tarjeta cp ON c.compra_id = cp.id WHERE c.numero_cuota = cp.cuota_actual AND c.estado = 'PENDIENTE'"
    );
    final cuotaBasicaTarjetas = (cuotasBasicasQuery.first['total'] as num?)?.toDouble() ?? 0.0;

    // 4. Calcular liquidez y abono extra
    final liquidez = (ingresosMes - totalGastosFijos - cuotaBasicaTarjetas) > 0 ? (ingresosMes - totalGastosFijos - cuotaBasicaTarjetas) : 0.0;
    final abonoExtra = liquidez * (pctAbonoExtra / 100);

    // 5. Agrupar capital programado por mes
    final pagosProgramados = await DatabaseService.instance.query(
      "SELECT strftime('%Y-%m', fecha_vencimiento) as mes, SUM(valor_capital) as total_capital FROM cuotas_amortizacion WHERE estado = 'PENDIENTE' GROUP BY mes ORDER BY mes ASC"
    );
    final Map<String, double> mapaPagos = {};
    for (var r in pagosProgramados) {
      if (r['mes'] != null) {
        mapaPagos[r['mes'].toString()] = (r['total_capital'] as num?)?.toDouble() ?? 0.0;
      }
    }

    final List<Map<String, dynamic>> proyeccion = [];
    double tempDeuda = deudaTarjetas;
    int mesLibre = 0;

    for (int i = 0; i < 60; i++) {
      final m = DateTime(now.year, now.month + i);
      final mesStr = "${m.year}-${m.month.toString().padLeft(2, '0')}";
      final label = "${m.month}/${m.year}";
      
      proyeccion.add({'label': label, 'deuda_restante': tempDeuda > 0 ? tempDeuda : 0});
      
      if (tempDeuda <= 0 && mesLibre == 0) {
        mesLibre = i;
      }
      
      final capitalProgramado = mapaPagos[mesStr] ?? 0.0;
      double decrementoFinal = capitalProgramado + abonoExtra;
      
      if (tempDeuda > 0 && decrementoFinal == 0) {
        bool hasFuture = false;
        for (var key in mapaPagos.keys) {
          if (key.compareTo(mesStr) > 0) {
            hasFuture = true; break;
          }
        }
        if (!hasFuture) {
          decrementoFinal = tempDeuda;
        }
      }
      
      tempDeuda -= decrementoFinal;
      
      if (tempDeuda <= 0 && proyeccion.length >= 6) {
        final m1 = DateTime(now.year, now.month + i + 1);
        proyeccion.add({'label': "${m1.month}/${m1.year}", 'deuda_restante': 0});
        break;
      }
    }

    return {
      'historical': [],
      'proyeccion': proyeccion,
      'deuda_tarjetas': deudaTarjetas,
      'cuentas_por_cobrar': cuentasCobrar
    };
  }
}
