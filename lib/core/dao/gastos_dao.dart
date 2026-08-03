import 'package:intl/intl.dart';
import '../../models/gasto_fijo.dart';
import '../../models/categoria.dart';
import '../database_service.dart';

class GastosDao {
  static final GastosDao instance = GastosDao._();
  GastosDao._();

  Future<List<GastoFijo>> getGastosFijos({String? mes}) async {
    final queryMes = mes ?? DateFormat('yyyy-MM').format(DateTime.now());
    final rows = await DatabaseService.instance.query(
      '''
      SELECT g.*, c.nombre AS categoria_nombre, c.icono AS categoria_icono, c.color AS categoria_color
      FROM gastos_fijos g
      JOIN categorias_gasto c ON g.categoria_id = c.id
      WHERE g.activo = 1 AND (g.es_fijo = 1 OR g.mes_referencia = ?)
      ORDER BY
        CASE
          WHEN g.fecha_ultimo_pago IS NOT NULL AND strftime('%Y-%m', g.fecha_ultimo_pago) = strftime('%Y-%m', 'now') THEN 1
          ELSE 0
        END ASC,
        g.dia_pago ASC
      ''',
      [queryMes]
    );
    return rows.map((e) => GastoFijo.fromMap(e)).toList();
  }

  Future<void> createGastoFijo(GastoFijo gasto) async {
    final map = gasto.toMap();
    if (map['dia_pago'] == null || map['dia_pago'] < 1 || map['dia_pago'] > 31) {
      map['dia_pago'] = DateTime.now().day;
    }
    // Al registrar un gasto, se marca como pagado hoy (el usuario lo ingresa porque ya lo pagó)
    map['fecha_ultimo_pago'] = DateTime.now().toIso8601String().split('T')[0];
    await DatabaseService.instance.insert('gastos_fijos', map);
  }

  Future<void> updateGastoFijo(int id, GastoFijo gasto) async {
    final map = gasto.toMap();
    if (map['dia_pago'] == null || map['dia_pago'] < 1 || map['dia_pago'] > 31) {
      map['dia_pago'] = DateTime.now().day;
    }
    map['actualizado_en'] = DateTime.now().toIso8601String();
    await DatabaseService.instance.update('gastos_fijos', map, where: 'id = ?', whereArgs: [id]);
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

  Future<List<Categoria>> getCategoriasGasto() async {
    final rows = await DatabaseService.instance.query('SELECT * FROM categorias_gasto WHERE activa = 1');
    return rows.map((e) => Categoria.fromMap(e)).toList();
  }
}
