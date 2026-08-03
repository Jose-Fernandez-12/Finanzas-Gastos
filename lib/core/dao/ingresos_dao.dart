import 'package:intl/intl.dart';
import '../../models/ingreso.dart';
import '../../models/categoria.dart';
import '../database_service.dart';

class IngresosDao {
  static final IngresosDao instance = IngresosDao._();
  IngresosDao._();

  Future<List<Ingreso>> getIngresos({String? mes}) async {
    String whereClause = 'i.mes_referencia = ? OR i.es_fijo = 1';
    List<dynamic> args;

    if (mes == 'all') {
      whereClause = '1 = 1';
      args = [];
    } else if (mes != null && mes.startsWith('year:')) {
      final year = mes.split(':')[1];
      whereClause = 'i.mes_referencia LIKE ? OR i.es_fijo = 1';
      args = ['$year-%'];
    } else if (mes != null && mes.startsWith('week:')) {
      final dateStr = mes.split(':')[1];
      final date = DateTime.parse(dateStr);
      final monday = date.subtract(Duration(days: date.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      final mondayStr = '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
      final sundayStr = '${sunday.year}-${sunday.month.toString().padLeft(2, '0')}-${sunday.day.toString().padLeft(2, '0')}';
      whereClause = '(i.fecha >= ? AND i.fecha <= ?) OR i.es_fijo = 1';
      args = [mondayStr, sundayStr];
    } else {
      final queryMes = mes ?? DateFormat('yyyy-MM').format(DateTime.now());
      args = [queryMes];
    }

    final rows = await DatabaseService.instance.query(
      '''
      SELECT i.*, c.nombre AS categoria_nombre, c.icono AS categoria_icono, c.color AS categoria_color
      FROM ingresos i
      JOIN categorias_ingreso c ON i.categoria_id = c.id
      WHERE $whereClause
      ORDER BY i.fecha DESC
      ''',
      args
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
