import 'package:intl/intl.dart';
import '../../models/ingreso.dart';
import '../../models/categoria.dart';
import '../database_service.dart';

class IngresosDao {
  static final IngresosDao instance = IngresosDao._();
  IngresosDao._();

  Future<List<Ingreso>> getIngresos({String? mes}) async {
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
    return rows.map((e) => Ingreso.fromMap(e)).toList();
  }

  Future<void> createIngreso(Ingreso ingreso) async {
    await DatabaseService.instance.insert('ingresos', ingreso.toMap());
  }

  Future<void> updateIngreso(int id, Ingreso ingreso) async {
    final map = ingreso.toMap();
    map['actualizado_en'] = DateTime.now().toIso8601String();
    await DatabaseService.instance.update('ingresos', map, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteIngreso(int id) async {
    await DatabaseService.instance.delete('ingresos', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Categoria>> getCategoriasIngreso() async {
    final rows = await DatabaseService.instance.query('SELECT * FROM categorias_ingreso WHERE activa = 1');
    return rows.map((e) => Categoria.fromMap(e)).toList();
  }
}
