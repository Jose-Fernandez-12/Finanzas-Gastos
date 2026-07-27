import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database_service.dart';

class Sobre {
  final int? id;
  final String nombre;
  final double montoAsignado;
  final double gastado;
  final String color;
  final String icono;
  final String mesReferencia;

  double get disponible => montoAsignado - gastado;
  double get porcentajeUsado => montoAsignado > 0 ? (gastado / montoAsignado).clamp(0.0, 1.0) : 0.0;

  const Sobre({
    this.id,
    required this.nombre,
    this.montoAsignado = 0,
    this.gastado = 0,
    this.color = '#4F46E5',
    this.icono = 'account_balance_wallet',
    required this.mesReferencia,
  });

  factory Sobre.fromMap(Map<String, dynamic> m) => Sobre(
    id: m['id'] as int?,
    nombre: m['nombre_sobre'] as String,
    montoAsignado: (m['monto_asignado'] as num?)?.toDouble() ?? 0,
    gastado: (m['gastado'] as num?)?.toDouble() ?? 0,
    color: m['color'] as String? ?? '#4F46E5',
    icono: m['icono'] as String? ?? 'account_balance_wallet',
    mesReferencia: m['mes_referencia'] as String,
  );

  Map<String, dynamic> toMap() => {
    'nombre_sobre': nombre,
    'monto_asignado': montoAsignado,
    'gastado': gastado,
    'color': color,
    'icono': icono,
    'mes_referencia': mesReferencia,
    'actualizado_en': DateTime.now().toIso8601String(),
  };
}

class PresupuestoState {
  final double ingresosMes;
  final double totalAsignado;
  final List<Sobre> sobres;

  double get sinAsignar => ingresosMes - totalAsignado;
  bool get cuadrado => sinAsignar.abs() < 1; // Margen de $1 por redondeo

  const PresupuestoState({
    required this.ingresosMes,
    required this.totalAsignado,
    required this.sobres,
  });
}

final presupuestoProvider = FutureProvider.family<PresupuestoState, String>((ref, mes) async {
  final db = DatabaseService.instance;

  // Obtener ingresos del mes
  final ingresoRow = await db.getOne('''
    SELECT COALESCE(SUM(monto), 0) as total FROM ingresos
    WHERE substr(COALESCE(mes_referencia, fecha), 1, 7) = ?
  ''', [mes]);
  final ingresosMes = (ingresoRow?['total'] as num?)?.toDouble() ?? 0;

  // Obtener sobres del mes
  final rows = await db.query(
    'SELECT * FROM presupuesto_sobres WHERE mes_referencia = ? ORDER BY id',
    [mes],
  );
  final sobres = rows.map((r) => Sobre.fromMap(r)).toList();
  final totalAsignado = sobres.fold<double>(0, (sum, s) => sum + s.montoAsignado);

  return PresupuestoState(
    ingresosMes: ingresosMes,
    totalAsignado: totalAsignado,
    sobres: sobres,
  );
});

/// Helper functions para CRUD de sobres
class SobresRepository {
  static final _db = DatabaseService.instance;

  static Future<int> crear(Sobre sobre) async {
    return await _db.insert('presupuesto_sobres', sobre.toMap());
  }

  static Future<void> actualizar(int id, {double? montoAsignado, double? gastado, String? nombre, String? color}) async {
    final updates = <String, dynamic>{
      'actualizado_en': DateTime.now().toIso8601String(),
    };
    if (montoAsignado != null) updates['monto_asignado'] = montoAsignado;
    if (gastado != null) updates['gastado'] = gastado;
    if (nombre != null) updates['nombre_sobre'] = nombre;
    if (color != null) updates['color'] = color;

    await _db.update('presupuesto_sobres', updates, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> eliminar(int id) async {
    await _db.delete('presupuesto_sobres', where: 'id = ?', whereArgs: [id]);
  }
}
