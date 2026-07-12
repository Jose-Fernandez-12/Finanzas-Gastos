import '../../models/tarjeta_credito.dart';
import '../../models/compra_tarjeta.dart';
import '../../models/cuota_amortizacion.dart';
import '../database_service.dart';

class TarjetasDao {
  static final TarjetasDao instance = TarjetasDao._();
  TarjetasDao._();

  Future<List<TarjetaCredito>> getTarjetas() async {
    final tarjetas = await DatabaseService.instance.query('SELECT * FROM tarjetas_credito WHERE activa = 1 ORDER BY banco');
    
    List<TarjetaCredito> result = [];
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
      
      result.add(TarjetaCredito.fromMap(tMap));
    }
    return result;
  }

  Future<void> createTarjeta(TarjetaCredito tarjeta) async {
    final data = tarjeta.toMap();
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

  Future<void> updateTarjeta(int id, TarjetaCredito tarjeta) async {
    final data = tarjeta.toMap();
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

  Future<void> deleteTarjeta(int id) async {
    await DatabaseService.instance.update('tarjetas_credito', {'activa': 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<CompraTarjeta>> getComprasTarjeta(int tarjetaId) async {
    final compras = await DatabaseService.instance.query(
      "SELECT * FROM compras_tarjeta WHERE tarjeta_id = ? ORDER BY id DESC",
      [tarjetaId]
    );

    List<CompraTarjeta> result = [];
    for (var c in compras) {
      final cuotas = await DatabaseService.instance.query(
        "SELECT * FROM cuotas_amortizacion WHERE compra_id = ? ORDER BY numero_cuota ASC",
        [c['id']]
      );
      Map<String, dynamic> cMap = Map.from(c);
      cMap['cuotas'] = cuotas;
      result.add(CompraTarjeta.fromMap(cMap));
    }
    return result;
  }
}
