import '../../models/cuenta_cobrar.dart';
import '../database_service.dart';

class CuentasCobrarDao {
  static final CuentasCobrarDao instance = CuentasCobrarDao._();
  CuentasCobrarDao._();

  Future<List<CuentaCobrar>> getCuentasCobrar() async {
    // Marcar en mora las que vencieron
    await DatabaseService.instance.execute(
      "UPDATE cuentas_cobrar SET estado = 'MORA' WHERE estado = 'AL_DIA' AND saldo_pendiente > 0 AND date(fecha_primer_vencimiento) < date('now')"
    );
    final rows = await DatabaseService.instance.query(
      'SELECT * FROM cuentas_cobrar WHERE estado != \'CANCELADO\' ORDER BY saldo_pendiente DESC'
    );
    return rows.map((e) => CuentaCobrar.fromMap(e)).toList();
  }

  Future<void> createCuentaCobrar(CuentaCobrar cuenta) async {
    await DatabaseService.instance.insert('cuentas_cobrar', cuenta.toMap());
  }

  Future<void> updateCuentaCobrar(int id, CuentaCobrar cuenta) async {
    final map = cuenta.toMap();
    map['actualizado_en'] = DateTime.now().toIso8601String();
    await DatabaseService.instance.update('cuentas_cobrar', map, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteCuentaCobrar(int id) async {
    await DatabaseService.instance.delete('cuentas_cobrar', where: 'id = ?', whereArgs: [id]);
  }
}
