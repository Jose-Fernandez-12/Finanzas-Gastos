import '../../models/suscripcion.dart';
import '../database_service.dart';

class SuscripcionesDao {
  static final SuscripcionesDao instance = SuscripcionesDao._();
  SuscripcionesDao._();

  Future<List<Suscripcion>> getSuscripciones({bool soloActivas = true}) async {
    final where = soloActivas ? 'WHERE activa = 1' : '';
    final rows = await DatabaseService.instance.query(
      'SELECT * FROM suscripciones $where ORDER BY dia_cobro ASC',
    );
    return rows.map((e) => Suscripcion.fromMap(e)).toList();
  }

  Future<void> createSuscripcion(Suscripcion s) async {
    final map = s.toMap()..remove('id');
    await DatabaseService.instance.insert('suscripciones', map);
  }

  Future<void> updateSuscripcion(int id, Suscripcion s) async {
    final map = s.toMap()
      ..remove('id')
      ..['actualizado_en'] = DateTime.now().toIso8601String();
    await DatabaseService.instance.update('suscripciones', map, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSuscripcion(int id) async {
    await DatabaseService.instance.update(
      'suscripciones', {'activa': 0}, where: 'id = ?', whereArgs: [id],
    );
  }

  Future<void> registrarCobro(int id) async {
    await DatabaseService.instance.update('suscripciones', {
      'fecha_ultimo_cobro': DateTime.now().toIso8601String().split('T')[0],
      'actualizado_en': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
  }
}
