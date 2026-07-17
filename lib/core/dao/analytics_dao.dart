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
      "SELECT COALESCE(SUM(monto), 0) as total FROM gastos_fijos WHERE activo = 1 AND (es_fijo = 1 OR mes_referencia = ?) AND nombre NOT LIKE 'Cuota TC:%'",
      [mesActualStr]
    );
    final totalGastosFijos = (gastos.first['total'] as num?)?.toDouble() ?? 0.0;

    // 3. Obtener cuota básica de tarjetas (tanto pendientes como pagadas correspondientes a este mes)
    final cuotasBasicasQuery = await DatabaseService.instance.query(
      "SELECT COALESCE(SUM(valor_cuota), 0) as total FROM cuotas_amortizacion WHERE (strftime('%Y-%m', fecha_vencimiento) = ? OR strftime('%Y-%m', fecha_pago_real) = ?) AND estado IN ('PENDIENTE', 'PAGADA')",
      [mesActualStr, mesActualStr]
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

  Future<Map<String, dynamic>> getAdvancedAnalytics({String? mes, double abonoExtra = 200000.0}) async {
    final now = DateTime.now();
    final mesStr = mes ?? "${now.year}-${now.month.toString().padLeft(2, '0')}";

    // 1. Termómetro de "Plata Libre de Culpa"
    final ingRes = await DatabaseService.instance.query(
      "SELECT COALESCE(SUM(monto), 0) as total FROM ingresos WHERE mes_referencia = ? OR es_fijo = 1",
      [mesStr]
    );
    final double ingresos = (ingRes.first['total'] as num?)?.toDouble() ?? 0.0;

    final gfRes = await DatabaseService.instance.query(
      "SELECT COALESCE(SUM(monto), 0) as total FROM gastos_fijos WHERE activo = 1 AND (es_fijo = 1 OR mes_referencia = ?) AND nombre NOT LIKE 'Cuota TC:%'",
      [mesStr]
    );
    final double gastosFijos = (gfRes.first['total'] as num?)?.toDouble() ?? 0.0;

    final ctRes = await DatabaseService.instance.query(
      "SELECT COALESCE(SUM(valor_cuota), 0) as total FROM cuotas_amortizacion WHERE (strftime('%Y-%m', fecha_vencimiento) = ? OR strftime('%Y-%m', fecha_pago_real) = ?) AND estado IN ('PENDIENTE', 'PAGADA')",
      [mesStr, mesStr]
    );
    final double cuotasTarjetas = (ctRes.first['total'] as num?)?.toDouble() ?? 0.0;

    final morasRes = await DatabaseService.instance.query(
      "SELECT COALESCE(SUM(saldo_pendiente), 0) as total FROM cuentas_cobrar WHERE estado = 'MORA'"
    );
    final double cuentasEnMora = (morasRes.first['total'] as num?)?.toDouble() ?? 0.0;

    final double saldoComprometido = gastosFijos + cuotasTarjetas;
    final double disponibleReal = ingresos - saldoComprometido;
    
    final int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final int remainingDays = (daysInMonth - now.day + 1).clamp(1, daysInMonth);
    final double diarioSeguro = disponibleReal > 0 ? (disponibleReal / remainingDays) : 0.0;
    final double semanalSeguro = diarioSeguro * 7;

    String estadoTermometro = 'Sano';
    if (disponibleReal <= 0) {
      estadoTermometro = 'Déficit';
    } else if (disponibleReal < (ingresos * 0.15)) {
      estadoTermometro = 'Ajustado';
    }

    final termometro = {
      'ingresos': ingresos,
      'gastos_fijos': gastosFijos,
      'cuotas_tarjetas': cuotasTarjetas,
      'saldo_comprometido': saldoComprometido,
      'disponible_real': disponibleReal,
      'dias_restantes': remainingDays,
      'diario_seguro': diarioSeguro,
      'semanal_seguro': semanalSeguro,
      'cuentas_mora': cuentasEnMora,
      'estado': estadoTermometro,
    };

    // 2. Radar de Gastos Hormiga & Suscripciones menores a $45.000
    final hormigaGF = await DatabaseService.instance.query(
      "SELECT nombre as descripcion, monto as valor, 1 as recurrente FROM gastos_fijos WHERE activo = 1 AND monto <= 45000"
    );
    final hormigaTC = await DatabaseService.instance.query(
      "SELECT descripcion, monto_total as valor, 0 as recurrente FROM compras_tarjeta WHERE monto_total <= 45000 AND num_cuotas <= 1"
    );

    final Map<String, Map<String, dynamic>> hormigaAgrupada = {};
    double totalMensualHormiga = 0.0;
    
    for (var row in [...hormigaGF, ...hormigaTC]) {
      final desc = (row['descripcion'] as String? ?? 'Varios').trim();
      final val = (row['valor'] as num?)?.toDouble() ?? 0.0;
      final rec = (row['recurrente'] as int?) == 1;
      final key = desc.toLowerCase();

      final actual = hormigaAgrupada[key] ?? {
        'nombre': desc,
        'cantidad': 0,
        'total': 0.0,
        'recurrente': rec,
      };
      actual['cantidad'] = (actual['cantidad'] as int) + 1;
      actual['total'] = (actual['total'] as double) + val;
      hormigaAgrupada[key] = actual;

      totalMensualHormiga += rec ? val : (val / 3); // si es compra puntual asumimos promedio mensual en 3 meses
    }

    final listaHormiga = hormigaAgrupada.values.map((e) {
      final double tot = e['total'] as double;
      final bool rec = e['recurrente'] as bool;
      final double mesEq = rec ? tot : (tot / 3);
      return {
        'nombre': e['nombre'],
        'cantidad': e['cantidad'],
        'total': tot,
        'recurrente': rec,
        'anualizado': mesEq * 12,
      };
    }).toList();

    listaHormiga.sort((a, b) => (b['anualizado'] as double).compareTo(a['anualizado'] as double));
    final double totalAnualHormiga = listaHormiga.fold(0.0, (sum, item) => sum + (item['anualizado'] as double));

    final radarHormiga = {
      'lista': listaHormiga,
      'total_mensual': totalMensualHormiga,
      'total_anual': totalAnualHormiga,
    };

    // 3. Simulador Avalancha vs Bola de Nieve
    final deudasRes = await DatabaseService.instance.query(
      "SELECT c.id, c.descripcion, c.monto_total, c.saldo_capital, c.tasa_interes_mensual, c.cuota_actual, c.num_cuotas, t.banco, t.color FROM compras_tarjeta c JOIN tarjetas_credito t ON c.tarjeta_id = t.id WHERE c.saldo_capital > 0 AND c.cuota_actual <= c.num_cuotas"
    );

    final deudas = deudasRes.map((e) {
      final numC = e['num_cuotas'] as int? ?? 1;
      final actC = e['cuota_actual'] as int? ?? 1;
      final pend = (numC - actC + 1).clamp(1, 120);
      return {
        'id': e['id'],
        'nombre': e['descripcion'] ?? '',
        'banco': e['banco'] ?? '',
        'color': e['color'] ?? '#1976D2',
        'saldo_capital': (e['saldo_capital'] as num?)?.toDouble() ?? 0.0,
        'tasa_interes': (e['tasa_interes_mensual'] as num?)?.toDouble() ?? 0.0,
        'cuotas_pendientes': pend,
      };
    }).toList();

    Map<String, dynamic>? avalanchaOpcion;
    Map<String, dynamic>? bolaNieveOpcion;

    if (deudas.isNotEmpty) {
      // Avalancha: mayor tasa de interés primero
      final deudasAvalancha = List<Map<String, dynamic>>.from(deudas)..sort((a, b) => (b['tasa_interes'] as double).compareTo(a['tasa_interes'] as double));
      final topAvalancha = deudasAvalancha.first;
      final double tasaA = topAvalancha['tasa_interes'] as double;
      final int cuotasA = topAvalancha['cuotas_pendientes'] as int;
      final double ahorroInteres = (abonoExtra * (tasaA / 100)) * cuotasA;

      avalanchaOpcion = {
        'top_deuda': topAvalancha,
        'ahorro_estimado': ahorroInteres > 0 ? ahorroInteres : 0.0,
        'razon': 'Pagar primero la deuda con mayor tasa (${tasaA.toStringAsFixed(1)}%) ahorra el máximo interés posible al banco.'
      };

      // Bola de Nieve: menor saldo capital primero
      final deudasBola = List<Map<String, dynamic>>.from(deudas)..sort((a, b) => (a['saldo_capital'] as double).compareTo(b['saldo_capital'] as double));
      final topBola = deudasBola.first;
      final double saldoB = topBola['saldo_capital'] as double;
      final double cuotaAprox = saldoB / (topBola['cuotas_pendientes'] as int);
      final int mesesGanados = cuotaAprox > 0 ? (abonoExtra / cuotaAprox).round().clamp(1, 24) : 1;

      bolaNieveOpcion = {
        'top_deuda': topBola,
        'meses_ganados': mesesGanados,
        'razon': 'Pagar la deuda de menor saldo (${topBola['banco']} - \$${(saldoB / 1000).toStringAsFixed(0)}k) te libera una cuota mensual rápidamente y te da motivación psicológica.'
      };
    }

    final simulador = {
      'deudas': deudas,
      'avalancha': avalanchaOpcion,
      'bola_nieve': bolaNieveOpcion,
    };

    // 4. Calendario de Estrés de Efectivo
    final gfDias = await DatabaseService.instance.query("SELECT dia_pago, COALESCE(SUM(monto), 0) as total FROM gastos_fijos WHERE activo = 1 GROUP BY dia_pago");
    final Map<int, double> mapaDiasGasto = {};
    for (var r in gfDias) {
      final d = r['dia_pago'] as int? ?? 15;
      mapaDiasGasto[d] = (r['total'] as num?)?.toDouble() ?? 0.0;
    }

    // Identificar el bloque de días de mayor presión (p. ej. entre el día 10 y el 18)
    double maxPresion = 0.0;
    int diaInicioMax = 10;
    int diaFinMax = 18;

    for (int start = 1; start <= 25; start += 5) {
      double sumaBloque = 0.0;
      for (int d = start; d < start + 6; d++) {
        sumaBloque += mapaDiasGasto[d] ?? 0.0;
      }
      if (sumaBloque > maxPresion) {
        maxPresion = sumaBloque;
        diaInicioMax = start;
        diaFinMax = start + 5;
      }
    }

    final bool alertaEstres = maxPresion > (ingresos * 0.4);
    final estres = {
      'alerta': alertaEstres,
      'dia_inicio': diaInicioMax,
      'dia_fin': diaFinMax,
      'presion_monto': maxPresion,
      'mensaje': alertaEstres
          ? '⚠️ Alta concentración de pagos: Entre el día $diaInicioMax y $diaFinMax del mes se juntan \$${(maxPresion / 1000).toStringAsFixed(0)}k en vencimientos. Mantén reserva antes de esa fecha.'
          : '✅ Tu flujo de pagos en el mes está equilibrado sin cuellos de botella críticos.'
    };

    return {
      'termometro': termometro,
      'radar_hormiga': radarHormiga,
      'simulador': simulador,
      'estres': estres,
    };
  }
}
