import 'package:intl/intl.dart';
import 'database_service.dart';
import 'amortization_calculator.dart';

class LocalRepository {
  static LocalRepository? _instance;

  LocalRepository._();

  static LocalRepository get instance {
    _instance ??= LocalRepository._();
    return _instance!;
  }

  // ---- Dashboard ----
  Future<Map<String, dynamic>> getDashboard() async {
    final now = DateTime.now();
    final mesActual = "${now.year}-${now.month.toString().padLeft(2, '0')}";

    final ingresos = await DatabaseService.instance.query(
      "SELECT SUM(monto) as total FROM ingresos WHERE mes_referencia = ? OR es_fijo = 1",
      [mesActual]
    );
    final ingresosMes = (ingresos.first['total'] as num?)?.toDouble() ?? 0.0;

    final gastos = await DatabaseService.instance.query(
      "SELECT SUM(monto) as total FROM gastos_fijos WHERE activo = 1 AND (es_fijo = 1 OR mes_referencia = ?)",
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
        "SELECT SUM(c.valor_cuota) as total FROM cuotas_amortizacion c JOIN compras_tarjeta cp ON c.compra_id = cp.id WHERE c.tarjeta_id = ? AND c.numero_cuota = cp.cuota_actual AND c.estado = 'PENDIENTE'",
        [t['id']]
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

    return {
      'ok': true,
      'data': {
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
      }
    };
  }

  // ---- Analytics ----
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
      // El decremento de deuda es el capital que se paga en el mes + lo extra que se abone
      double decrementoFinal = capitalProgramado + abonoExtra;
      
      // Si la deuda se estancó (descuadre entre cupo y cuotas) y no hay más pagos a futuro, liquidamos.
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
      'ok': true,
      'data': {
        'historical': [],
        'proyeccion': proyeccion,
        'deuda_tarjetas': deudaTarjetas,
        'cuentas_por_cobrar': cuentasCobrar
      }
    };
  }

  // ---- Ingresos ----
  Future<Map<String, dynamic>> getIngresos({String? mes}) async {
    final queryMes = mes ?? DateFormat('yyyy-MM').format(DateTime.now());
    final rows = await DatabaseService.instance.query(
      '''
      SELECT i.*, c.nombre AS categoria_nombre, c.icono AS categoria_icono, c.color AS categoria_color
      FROM ingresos i
      JOIN categorias_ingreso c ON i.categoria_id = c.id
      WHERE i.mes_referencia = ? OR i.es_fijo = 1
      ORDER BY i.fecha DESC
      ''',
      [queryMes]
    );
    return {'ok': true, 'data': rows};
  }

  Future<void> createIngreso(Map<String, dynamic> data) async {
    await DatabaseService.instance.insert('ingresos', {
      'categoria_id': data['categoria_id'],
      'descripcion': data['descripcion'],
      'monto': data['monto'],
      'es_fijo': data['es_fijo'],
      'fecha': data['fecha'],
      'mes_referencia': data['mes_referencia'] ?? data['fecha']?.toString().substring(0, 7),
      'notas': data['notas']
    });
  }

  Future<void> updateIngreso(int id, Map<String, dynamic> data) async {
    await DatabaseService.instance.update('ingresos', {
      'categoria_id': data['categoria_id'],
      'descripcion': data['descripcion'],
      'monto': data['monto'],
      'es_fijo': data['es_fijo'],
      'fecha': data['fecha'],
      'mes_referencia': data['mes_referencia'] ?? data['fecha']?.toString().substring(0, 7),
      'notas': data['notas'],
      'actualizado_en': DateTime.now().toIso8601String()
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteIngreso(int id) async {
    await DatabaseService.instance.delete('ingresos', where: 'id = ?', whereArgs: [id]);
  }


  Future<Map<String, dynamic>> getCategoriasIngreso() async {
    final rows = await DatabaseService.instance.query('SELECT * FROM categorias_ingreso WHERE activa = 1');
    return {'ok': true, 'data': rows};
  }

  // ---- Gastos Fijos ----
  Future<Map<String, dynamic>> getGastosFijos({String? mes}) async {
    final queryMes = mes ?? DateFormat('yyyy-MM').format(DateTime.now());
    final rows = await DatabaseService.instance.query(
      '''
      SELECT g.*, c.nombre AS categoria_nombre, c.icono AS categoria_icono, c.color AS categoria_color
      FROM gastos_fijos g
      JOIN categorias_gasto c ON g.categoria_id = c.id
      WHERE g.activo = 1 AND (g.es_fijo = 1 OR g.mes_referencia = ?)
      ORDER BY g.dia_pago ASC
      ''',
      [queryMes]
    );
    return {'ok': true, 'data': rows};
  }

  Future<void> createGastoFijo(Map<String, dynamic> data) async {
    final now = DateTime.now();
    await DatabaseService.instance.insert('gastos_fijos', {
      'categoria_id': data['categoria_id'],
      'nombre': data['nombre'],
      'monto': data['monto'],
      'dia_pago': data['dia_pago'],
      'es_fijo': data['es_fijo'] ?? 1,
      'mes_referencia': data['mes_referencia'] ?? "${now.year}-${now.month.toString().padLeft(2, '0')}",
      'notas': data['notas']
    });
  }

  Future<void> updateGastoFijo(int id, Map<String, dynamic> data) async {
    final now = DateTime.now();
    await DatabaseService.instance.update('gastos_fijos', {
      'categoria_id': data['categoria_id'],
      'nombre': data['nombre'],
      'monto': data['monto'],
      'dia_pago': data['dia_pago'],
      'es_fijo': data['es_fijo'] ?? 1,
      'mes_referencia': data['mes_referencia'] ?? "${now.year}-${now.month.toString().padLeft(2, '0')}",
      'notas': data['notas'],
      'actualizado_en': DateTime.now().toIso8601String()
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteGastoFijo(int id) async {
    await DatabaseService.instance.update('gastos_fijos', {'activo': 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> pagarGastoFijo(int id) async {
    await DatabaseService.instance.update('gastos_fijos', {
      'fecha_ultimo_pago': DateTime.now().toIso8601String().split('T')[0],
      'actualizado_en': DateTime.now().toIso8601String()
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>> getCategoriasGasto() async {
    final rows = await DatabaseService.instance.query('SELECT * FROM categorias_gasto WHERE activa = 1');
    return {'ok': true, 'data': rows};
  }

  // ---- Tarjetas ----
  Future<Map<String, dynamic>> getTarjetas() async {
    final tarjetas = await DatabaseService.instance.query('SELECT * FROM tarjetas_credito WHERE activa = 1 ORDER BY banco');
    
    List<Map<String, dynamic>> result = [];
    for (var t in tarjetas) {
      final tId = t['id'];
      
      final deuda = await DatabaseService.instance.getOne(
        "SELECT COALESCE(SUM(saldo_capital), 0) AS total FROM compras_tarjeta WHERE tarjeta_id = ? AND cuota_actual <= num_cuotas",
        [tId]
      );
      final cuotaMes = await DatabaseService.instance.getOne(
        "SELECT COALESCE(SUM(valor_cuota), 0) AS total FROM cuotas_amortizacion WHERE tarjeta_id = ? AND estado = 'PENDIENTE' AND strftime('%Y-%m', fecha_vencimiento) = strftime('%Y-%m', 'now')",
        [tId]
      );
      final avances = await DatabaseService.instance.getOne(
        "SELECT COALESCE(SUM(saldo_capital), 0) AS total FROM compras_tarjeta WHERE tarjeta_id = ? AND cuota_actual <= num_cuotas AND es_avance = 1",
        [tId]
      );

      final cupoAvancesTotal = (t['cupo_avances_total'] as num?)?.toDouble() ?? 0;
      final avancesSuma = (avances?['total'] as num?)?.toDouble() ?? 0;
      final cupoAvancesDisponible = (cupoAvancesTotal - avancesSuma).clamp(0.0, double.infinity);

      Map<String, dynamic> tMap = Map.from(t);
      tMap['total_deuda_activa'] = deuda?['total'] ?? 0;
      tMap['cuota_mes_actual'] = cuotaMes?['total'] ?? 0;
      tMap['cupo_avances_disponible'] = cupoAvancesDisponible;
      result.add(tMap);
    }

    return {'ok': true, 'data': result};
  }

  Future<void> createTarjeta(Map<String, dynamic> data) async {
    await DatabaseService.instance.transaction((txn) async {
      await txn.insert('tarjetas_credito', {
        'banco': data['banco'],
        'nombre_tarjeta': data['nombre_tarjeta'],
        'cupo_total': data['cupo_total'],
        'cupo_disponible': data['cupo_total'],
        'fecha_corte': data['fecha_corte'],
        'fecha_pago': data['fecha_pago'],
        'tasa_interes_mensual': data['tasa_interes_mensual'] ?? 0,
        'cupo_avances_total': data['cupo_avances_total'] ?? 0,
        'cuota_manejo': data['cuota_manejo'] ?? 0,
        'color': data['color'] ?? '#1976D2',
        'notas': data['notas']
      });

      double cuotaManejo = (data['cuota_manejo'] as num?)?.toDouble() ?? 0;
      if (cuotaManejo > 0) {
        await txn.insert('gastos_fijos', {
          'categoria_id': 9, // Otros
          'nombre': 'Cuota Manejo ${data['nombre_tarjeta']}',
          'monto': cuotaManejo,
          'dia_pago': data['fecha_pago'],
          'notas': 'Generado automáticamente por la tarjeta ${data['banco']}'
        });
      }
    });
  }

  Future<void> updateTarjeta(int id, Map<String, dynamic> data) async {
    await DatabaseService.instance.transaction((txn) async {
      await txn.update('tarjetas_credito', {
        'banco': data['banco'],
        'nombre_tarjeta': data['nombre_tarjeta'],
        'cupo_total': data['cupo_total'],
        'fecha_corte': data['fecha_corte'],
        'fecha_pago': data['fecha_pago'],
        'tasa_interes_mensual': data['tasa_interes_mensual'],
        'cupo_avances_total': data['cupo_avances_total'],
        'cuota_manejo': data['cuota_manejo'],
        'color': data['color'],
        'notas': data['notas'],
        'actualizado_en': DateTime.now().toIso8601String()
      }, where: 'id = ?', whereArgs: [id]);

      double cuotaManejo = (data['cuota_manejo'] as num?)?.toDouble() ?? 0;
      if (cuotaManejo > 0) {
        String nombreGasto = 'Cuota Manejo ${data['nombre_tarjeta']}';
        final res = await txn.rawQuery("SELECT id FROM gastos_fijos WHERE nombre = ? OR nombre LIKE ?", [nombreGasto, "%${data['nombre_tarjeta']}%"]);
        if (res.isNotEmpty) {
          await txn.update('gastos_fijos', {
            'monto': cuotaManejo,
            'dia_pago': data['fecha_pago']
          }, where: 'id = ?', whereArgs: [res.first['id']]);
        } else {
          await txn.insert('gastos_fijos', {
            'categoria_id': 9,
            'nombre': nombreGasto,
            'monto': cuotaManejo,
            'dia_pago': data['fecha_pago'],
            'notas': 'Generado automáticamente por la tarjeta ${data['banco']}'
          });
        }
      }
    });
  }

  Future<Map<String, dynamic>> getComprasTarjeta(int tarjetaId) async {
    final compras = await DatabaseService.instance.query(
      "SELECT * FROM compras_tarjeta WHERE tarjeta_id = ? AND cuota_actual <= num_cuotas ORDER BY fecha_compra DESC",
      [tarjetaId]
    );
    List<Map<String, dynamic>> result = [];
    for (var c in compras) {
      final cuotas = await DatabaseService.instance.query(
        "SELECT * FROM cuotas_amortizacion WHERE compra_id = ? ORDER BY numero_cuota",
        [c['id']]
      );
      Map<String, dynamic> cMap = Map.from(c);
      cMap['cuotas'] = cuotas;
      result.add(cMap);
    }
    return {'ok': true, 'data': result};
  }

  Future<Map<String, dynamic>> createCompra(int tarjetaId, Map<String, dynamic> data) async {
    try {
      final tarjeta = await DatabaseService.instance.getOne('SELECT * FROM tarjetas_credito WHERE id = ?', [tarjetaId]);
      if (tarjeta == null) throw Exception("Tarjeta no encontrada");
      
      double montoTotal = double.parse(data['monto_total'].toString());
      if ((tarjeta['cupo_disponible'] as num).toDouble() < montoTotal) {
        throw Exception("Cupo insuficiente");
      }

      double tasaIngresada = double.parse(data['tasa_ingresada'].toString());
      String tipoTasa = data['tipo_tasa'] ?? 'MENSUAL';
      double tasaDecimal = tasaIngresada / 100;
      double tasaMensual = tipoTasa == 'EA' ? AmortizationCalculator.eaAMensual(tasaDecimal) : tasaDecimal;

      int numCuotas = int.parse(data['num_cuotas'].toString());

      final tabla = AmortizationCalculator.generarTablaAmortizacion(
        montoTotal, tasaMensual, numCuotas, data['fecha_compra'], 
        (tarjeta['fecha_corte'] as num).toInt(), (tarjeta['fecha_pago'] as num).toInt(), tarjeta['banco']
      );

      return await DatabaseService.instance.transaction((txn) async {
        int compraId = await txn.insert('compras_tarjeta', {
          'tarjeta_id': tarjetaId,
          'descripcion': data['descripcion'],
          'comercio': data['comercio'],
          'monto_total': montoTotal,
          'num_cuotas': numCuotas,
          'tasa_interes_mensual': tasaMensual,
          'tipo_tasa_ingresada': tipoTasa,
          'fecha_compra': data['fecha_compra'],
          'saldo_capital': montoTotal,
          'amortizacion_generada': 1,
          'categoria_id': data['categoria_id'],
          'notas': data['notas'],
          'es_avance': data['es_avance'] == true ? 1 : 0
        });

        for (var cuota in tabla) {
          await txn.insert('cuotas_amortizacion', {
            'compra_id': compraId,
            'tarjeta_id': tarjetaId,
            'numero_cuota': cuota['numero_cuota'],
            'fecha_vencimiento': cuota['fecha_vencimiento'],
            'saldo_inicial': cuota['saldo_inicial'],
            'valor_capital': cuota['valor_capital'],
            'valor_interes': cuota['valor_interes'],
            'valor_cuota': cuota['valor_cuota'],
            'saldo_final': cuota['saldo_final'],
            'estado': cuota['estado']
          });
        }

        await txn.rawUpdate(
          "UPDATE tarjetas_credito SET cupo_disponible = cupo_disponible - ?, actualizado_en = datetime('now') WHERE id = ?",
          [montoTotal, tarjetaId]
        );

        return {
          'ok': true, 
          'data': {
            'compra_id': compraId,
            'tasa_mensual_aplicada': tasaMensual * 100,
            'cuota_fija': tabla.isNotEmpty ? tabla[0]['valor_cuota'] : 0.0,
            'tabla_amortizacion': tabla
          }
        };
      });
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateCompra(int tarjetaId, int compraId, Map<String, dynamic> data) async {
    try {
      return await DatabaseService.instance.transaction((txn) async {
        final compraAnterior = (await txn.rawQuery('SELECT * FROM compras_tarjeta WHERE id = ?', [compraId])).firstOrNull;
        if (compraAnterior == null) throw Exception("Compra no encontrada");

        final tarjeta = (await txn.rawQuery('SELECT * FROM tarjetas_credito WHERE id = ?', [tarjetaId])).firstOrNull;
        if (tarjeta == null) throw Exception("Tarjeta no encontrada");

        double montoTotal = double.parse(data['monto_total'].toString());
        double saldoCapitalAnterior = (compraAnterior['saldo_capital'] as num).toDouble();
        double cupoDisponible = (tarjeta['cupo_disponible'] as num).toDouble();

        double nuevoCupoDisponible = cupoDisponible + saldoCapitalAnterior - montoTotal;
        if (nuevoCupoDisponible < 0) throw Exception("Cupo insuficiente para el nuevo monto");

        double tasaIngresada = double.parse(data['tasa_ingresada'].toString());
        String tipoTasa = data['tipo_tasa'] ?? 'MENSUAL';
        double tasaMensual = tipoTasa == 'EA' ? AmortizationCalculator.eaAMensual(tasaIngresada / 100) : tasaIngresada / 100;
        int numCuotas = int.parse(data['num_cuotas'].toString());

        final tabla = AmortizationCalculator.generarTablaAmortizacion(
          montoTotal, tasaMensual, numCuotas, data['fecha_compra'], 
          (tarjeta['fecha_corte'] as num).toInt(), (tarjeta['fecha_pago'] as num).toInt(), tarjeta['banco'].toString()
        );

        await txn.update('compras_tarjeta', {
          'descripcion': data['descripcion'],
          'comercio': data['comercio'],
          'monto_total': montoTotal,
          'num_cuotas': numCuotas,
          'tasa_interes_mensual': tasaMensual,
          'tipo_tasa_ingresada': tipoTasa,
          'fecha_compra': data['fecha_compra'],
          'saldo_capital': montoTotal,
          'cuota_actual': 1,
          'categoria_id': data['categoria_id'],
          'notas': data['notas'],
          'es_avance': data['es_avance'] == true ? 1 : 0,
          'actualizado_en': DateTime.now().toIso8601String()
        }, where: 'id = ?', whereArgs: [compraId]);

        await txn.delete('cuotas_amortizacion', where: 'compra_id = ?', whereArgs: [compraId]);

        for (var cuota in tabla) {
          await txn.insert('cuotas_amortizacion', {
            'compra_id': compraId,
            'tarjeta_id': tarjetaId,
            'numero_cuota': cuota['numero_cuota'],
            'fecha_vencimiento': cuota['fecha_vencimiento'],
            'saldo_inicial': cuota['saldo_inicial'],
            'valor_capital': cuota['valor_capital'],
            'valor_interes': cuota['valor_interes'],
            'valor_cuota': cuota['valor_cuota'],
            'saldo_final': cuota['saldo_final'],
            'estado': cuota['estado']
          });
        }

        await txn.update('tarjetas_credito', {
          'cupo_disponible': nuevoCupoDisponible,
          'actualizado_en': DateTime.now().toIso8601String()
        }, where: 'id = ?', whereArgs: [tarjetaId]);

        return {
          'ok': true, 
          'data': {
            'compra_id': compraId,
            'tasa_mensual_aplicada': tasaMensual * 100,
            'cuota_fija': tabla.isNotEmpty ? tabla[0]['valor_cuota'] : 0.0,
            'tabla_amortizacion': tabla
          }
        };
      });
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  Future<void> pagarCuota(int tarjetaId, int compraId, int cuotaId) async {
    await DatabaseService.instance.transaction((txn) async {
      await txn.rawUpdate(
        "UPDATE cuotas_amortizacion SET estado = 'PAGADA', fecha_pago_real = date('now') WHERE id = ? AND compra_id = ? AND estado = 'PENDIENTE'",
        [cuotaId, compraId]
      );
      final cuota = (await txn.rawQuery("SELECT * FROM cuotas_amortizacion WHERE id = ?", [cuotaId])).firstOrNull;
      if (cuota != null) {
        await txn.rawUpdate(
          "UPDATE compras_tarjeta SET saldo_capital = saldo_capital - ?, cuota_actual = cuota_actual + 1, actualizado_en = datetime('now') WHERE id = ?",
          [cuota['valor_capital'], compraId]
        );
        await txn.rawUpdate(
          "UPDATE tarjetas_credito SET cupo_disponible = cupo_disponible + ?, actualizado_en = datetime('now') WHERE id = ?",
          [cuota['valor_capital'], tarjetaId]
        );
      }
    });
  }

  // ---- Ahorros ----
  Future<Map<String, dynamic>> getAhorros() async {
    final bolsillos = await DatabaseService.instance.query('SELECT * FROM bolsillos_ahorro WHERE activo = 1');
    List<Map<String, dynamic>> result = [];
    for (var b in bolsillos) {
      final aportes = await DatabaseService.instance.query(
        "SELECT * FROM aportes_ahorro WHERE bolsillo_id = ? ORDER BY fecha DESC", [b['id']]
      );
      Map<String, dynamic> bMap = Map.from(b);
      bMap['historial'] = aportes;
      result.add(bMap);
    }
    return {'ok': true, 'data': result};
  }

  Future<void> createAhorro(Map<String, dynamic> data) async {
    await DatabaseService.instance.insert('bolsillos_ahorro', {
      'nombre': data['nombre'],
      'meta_monto': data['meta_monto'],
      'monto_actual': 0,
      'fecha_meta': data['fecha_meta'],
      'icono': data['icono'] ?? 'savings',
      'color': data['color'] ?? '#4CAF50',
      'notas': data['notas']
    });
  }

  Future<void> createAporte(int bolsilloId, Map<String, dynamic> data) async {
    await DatabaseService.instance.transaction((txn) async {
      await txn.insert('aportes_ahorro', {
        'bolsillo_id': bolsilloId,
        'monto': data['monto'],
        'descripcion': data['descripcion'],
        'fecha': data['fecha']
      });
      // The trigger 'trg_actualizar_monto_bolsillo' handles updating the balance
    });
  }

  // ---- Cuentas por Cobrar ----
  Future<Map<String, dynamic>> getCuentasCobrar() async {
    // La actualización de MORA la hacemos en la consulta local también
    await DatabaseService.instance.execute(
      "UPDATE cuentas_cobrar SET estado = 'MORA' WHERE estado = 'AL_DIA' AND saldo_pendiente > 0 AND date(fecha_primer_vencimiento) < date('now')"
    );
    final rows = await DatabaseService.instance.query(
      "SELECT * FROM cuentas_cobrar ORDER BY estado DESC, fecha_primer_vencimiento ASC"
    );
    return {'ok': true, 'data': rows};
  }

  Future<void> createCuentaCobrar(Map<String, dynamic> data) async {
    await DatabaseService.instance.insert('cuentas_cobrar', {
      'nombre_deudor': data['nombre_deudor'],
      'telefono': data['telefono'],
      'monto_total': data['monto_total'],
      'saldo_pendiente': data['monto_total'],
      'modalidad': data['modalidad'] ?? 'CUOTAS',
      'num_cuotas': data['num_cuotas'] ?? 1,
      'valor_cuota': data['valor_cuota'],
      'fecha_primer_vencimiento': data['fecha_primer_vencimiento'],
      'periodicidad': data['periodicidad'] ?? 'MENSUAL',
      'notas': data['notas']
    });
  }

  Future<void> updateCuentaCobrar(int id, Map<String, dynamic> data) async {
    await DatabaseService.instance.update('cuentas_cobrar', {
      'nombre_deudor': data['nombre_deudor'],
      'telefono': data['telefono'],
      'monto_total': data['monto_total'],
      'modalidad': data['modalidad'] ?? 'CUOTAS',
      'num_cuotas': data['num_cuotas'] ?? 1,
      'fecha_primer_vencimiento': data['fecha_primer_vencimiento'],
      'notas': data['notas']
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> registrarPago(int cuentaId, Map<String, dynamic> data) async {
    await DatabaseService.instance.transaction((txn) async {
      await txn.insert('pagos_cuenta_cobrar', {
        'cuenta_id': cuentaId,
        'monto_pagado': data['monto_pagado'],
        'fecha_pago': data['fecha_pago'],
        'notas': data['notas']
      });
      // The trigger 'trg_actualizar_saldo_cuenta' will update saldo_pendiente and estado
    });
  }

  // ---- Health check ----
  Future<bool> checkHealth() async {
    return true; // Always healthy if local
  }
}
