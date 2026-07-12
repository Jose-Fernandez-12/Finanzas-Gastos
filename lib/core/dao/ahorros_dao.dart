import '../../models/bolsillo_ahorro.dart';
import '../database_service.dart';

class AhorrosDao {
  static final AhorrosDao instance = AhorrosDao._();
  AhorrosDao._();

  Future<List<BolsilloAhorro>> getAhorros() async {
    final rows = await DatabaseService.instance.query('SELECT * FROM bolsillos_ahorro WHERE activo = 1 ORDER BY id DESC');
    return rows.map((e) => BolsilloAhorro.fromMap(e)).toList();
  }

  Future<void> createAhorro(BolsilloAhorro ahorro) async {
    await DatabaseService.instance.insert('bolsillos_ahorro', ahorro.toMap());
  }

  Future<void> updateAhorro(int id, BolsilloAhorro ahorro) async {
    final map = ahorro.toMap();
    map['actualizado_en'] = DateTime.now().toIso8601String();
    await DatabaseService.instance.update('bolsillos_ahorro', map, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAhorro(int id) async {
    await DatabaseService.instance.update('bolsillos_ahorro', {'activo': 0}, where: 'id = ?', whereArgs: [id]);
  }
}
