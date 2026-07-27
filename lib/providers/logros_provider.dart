import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database_service.dart';

/// Definición de todos los logros disponibles en la app.
class LogroDefinicion {
  final String clave;
  final String titulo;
  final String descripcion;
  final String icono;
  final String categoria;
  final double metaValor;

  /// Función que evalúa el progreso actual del logro.
  /// Recibe el mapa de datos del dashboard y retorna el progreso (0.0 - metaValor).
  final double Function(Map<String, dynamic> data) evaluador;

  const LogroDefinicion({
    required this.clave,
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.categoria,
    required this.metaValor,
    required this.evaluador,
  });
}

class LogroEstado {
  final int id;
  final String clave;
  final String titulo;
  final String descripcion;
  final String icono;
  final String categoria;
  final double metaValor;
  final double progreso;
  final bool completado;
  final String? fechaCompletado;

  double get porcentaje => metaValor > 0 ? (progreso / metaValor).clamp(0.0, 1.0) : 0.0;

  const LogroEstado({
    required this.id,
    required this.clave,
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.categoria,
    required this.metaValor,
    required this.progreso,
    required this.completado,
    this.fechaCompletado,
  });

  factory LogroEstado.fromMap(Map<String, dynamic> m) => LogroEstado(
    id: m['id'] as int,
    clave: m['clave'] as String,
    titulo: m['titulo'] as String,
    descripcion: m['descripcion'] as String,
    icono: m['icono'] as String? ?? 'emoji_events',
    categoria: m['categoria'] as String? ?? 'general',
    metaValor: (m['meta_valor'] as num?)?.toDouble() ?? 0.0,
    progreso: (m['progreso'] as num?)?.toDouble() ?? 0.0,
    completado: (m['completado'] as int?) == 1,
    fechaCompletado: m['fecha_completado'] as String?,
  );
}

/// Catálogo de logros. Cada uno define su propia lógica de evaluación.
final List<LogroDefinicion> catalogoLogros = [
  LogroDefinicion(
    clave: 'primer_ingreso',
    titulo: 'Primer Paso',
    descripcion: 'Registra tu primer ingreso en la app.',
    icono: 'flag',
    categoria: 'basico',
    metaValor: 1,
    evaluador: (_) => 1, // Si hay datos, ya registró algo
  ),
  LogroDefinicion(
    clave: 'health_score_70',
    titulo: 'Buen Estado',
    descripcion: 'Alcanza un Health Score de 70 o más.',
    icono: 'favorite',
    categoria: 'salud',
    metaValor: 70,
    evaluador: (data) {
      final hs = data['health_score'];
      if (hs == null) return 0;
      return (hs.score as int).toDouble();
    },
  ),
  LogroDefinicion(
    clave: 'health_score_85',
    titulo: 'Equilibrista',
    descripcion: 'Alcanza un Health Score de 85 o más.',
    icono: 'stars',
    categoria: 'salud',
    metaValor: 85,
    evaluador: (data) {
      final hs = data['health_score'];
      if (hs == null) return 0;
      return (hs.score as int).toDouble();
    },
  ),
  LogroDefinicion(
    clave: 'cero_mora',
    titulo: 'Cero Mora',
    descripcion: 'Mantén tu lista de mora vacía.',
    icono: 'verified',
    categoria: 'deuda',
    metaValor: 1,
    evaluador: (data) {
      final mora = data['cuentas_en_mora'] as List<dynamic>?;
      return (mora == null || mora.isEmpty) ? 1.0 : 0.0;
    },
  ),
  LogroDefinicion(
    clave: 'ahorro_100k',
    titulo: 'Primer Colchón',
    descripcion: 'Acumula más de \$100,000 en ahorros.',
    icono: 'savings',
    categoria: 'ahorro',
    metaValor: 100000,
    evaluador: (data) {
      final totales = data['totales'] as Map<String, dynamic>?;
      return (totales?['total_ahorros'] as num?)?.toDouble() ?? 0.0;
    },
  ),
  LogroDefinicion(
    clave: 'ahorro_500k',
    titulo: 'Ahorro Sólido',
    descripcion: 'Acumula más de \$500,000 en ahorros.',
    icono: 'account_balance',
    categoria: 'ahorro',
    metaValor: 500000,
    evaluador: (data) {
      final totales = data['totales'] as Map<String, dynamic>?;
      return (totales?['total_ahorros'] as num?)?.toDouble() ?? 0.0;
    },
  ),
  LogroDefinicion(
    clave: 'ahorro_1m',
    titulo: 'Maestro del Ahorro',
    descripcion: 'Acumula más de \$1,000,000 en ahorros.',
    icono: 'workspace_premium',
    categoria: 'ahorro',
    metaValor: 1000000,
    evaluador: (data) {
      final totales = data['totales'] as Map<String, dynamic>?;
      return (totales?['total_ahorros'] as num?)?.toDouble() ?? 0.0;
    },
  ),
  LogroDefinicion(
    clave: 'bajo_endeudamiento',
    titulo: 'Libre de Cadenas',
    descripcion: 'Mantén tu endeudamiento por debajo del 20%.',
    icono: 'lock_open',
    categoria: 'deuda',
    metaValor: 1,
    evaluador: (data) {
      final cap = data['capacidad_crediticia'] as Map<String, dynamic>?;
      final pct = (cap?['porcentaje_endeudamiento'] as num?)?.toDouble() ?? 100;
      return pct < 20 ? 1.0 : 0.0;
    },
  ),
  LogroDefinicion(
    clave: 'liquidez_positiva',
    titulo: 'Flujo Positivo',
    descripcion: 'Mantén una liquidez disponible positiva.',
    icono: 'water_drop',
    categoria: 'liquidez',
    metaValor: 1,
    evaluador: (data) {
      final cap = data['capacidad_crediticia'] as Map<String, dynamic>?;
      final liq = (cap?['liquidez_disponible'] as num?)?.toDouble() ?? 0;
      return liq > 0 ? 1.0 : 0.0;
    },
  ),
  LogroDefinicion(
    clave: 'sin_tarjetas_full',
    titulo: 'Sin Tope',
    descripcion: 'Mantén todas tus tarjetas por debajo del 50% de uso.',
    icono: 'credit_score',
    categoria: 'deuda',
    metaValor: 1,
    evaluador: (data) {
      final tarjetas = data['tarjetas'] as List<dynamic>?;
      if (tarjetas == null || tarjetas.isEmpty) return 0.0;
      for (final t in tarjetas) {
        final cupo = (t['cupo_total'] as num?)?.toDouble() ?? 1;
        final deuda = (t['deuda_actual'] as num?)?.toDouble() ?? 0;
        if (cupo > 0 && (deuda / cupo) >= 0.5) return 0.0;
      }
      return 1.0;
    },
  ),
];

/// Provider que evalúa y gestiona el estado de los logros.
final logrosProvider = FutureProvider<List<LogroEstado>>((ref) async {
  final db = DatabaseService.instance;

  // Asegurar que todos los logros del catálogo existen en la BD
  for (final def in catalogoLogros) {
    final existing = await db.getOne(
      'SELECT id FROM logros_misiones WHERE clave = ?', [def.clave],
    );
    if (existing == null) {
      await db.rawInsert('''
        INSERT INTO logros_misiones (clave, titulo, descripcion, icono, categoria, meta_valor, progreso, completado)
        VALUES (?, ?, ?, ?, ?, ?, 0, 0)
      ''', [def.clave, def.titulo, def.descripcion, def.icono, def.categoria, def.metaValor]);
    }
  }

  // Evaluar progreso con los datos actuales del dashboard
  final dashData = await ref.watch(dashboardDataForLogrosProvider.future);

  if (dashData != null) {
    for (final def in catalogoLogros) {
      final progreso = def.evaluador(dashData);
      final completado = progreso >= def.metaValor;

      if (completado) {
        await db.execute('''
          UPDATE logros_misiones SET progreso = ?, completado = 1, fecha_completado = datetime('now')
          WHERE clave = ? AND completado = 0
        ''', [progreso, def.clave]);
      } else {
        await db.execute('''
          UPDATE logros_misiones SET progreso = ? WHERE clave = ? AND completado = 0
        ''', [progreso, def.clave]);
      }
    }
  }

  // Retornar todos los logros actualizados
  final rows = await db.query('SELECT * FROM logros_misiones ORDER BY completado DESC, categoria, id');
  return rows.map((r) => LogroEstado.fromMap(r)).toList();
});

/// Provider auxiliar que obtiene los datos del dashboard para evaluar logros,
/// sin crear una dependencia circular.
final dashboardDataForLogrosProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final db = DatabaseService.instance;

  // Consulta simplificada para obtener los datos necesarios
  final now = DateTime.now();
  final mesActual = '${now.year}-${now.month.toString().padLeft(2, '0')}';

  final ingresosMes = (await db.getOne('''
    SELECT COALESCE(SUM(monto), 0) as total FROM ingresos
    WHERE substr(COALESCE(mes_referencia, fecha), 1, 7) = ?
  ''', [mesActual]))?['total'] ?? 0;

  if ((ingresosMes as num).toDouble() == 0) return null;

  final totalGastosFijos = (await db.getOne('''
    SELECT COALESCE(SUM(monto), 0) as total FROM gastos_fijos
    WHERE substr(COALESCE(mes_referencia, fecha), 1, 7) = ?
  ''', [mesActual]))?['total'] ?? 0;

  final deudaTarjetas = (await db.getOne(
    'SELECT COALESCE(SUM(deuda_actual), 0) as total FROM tarjetas_credito'
  ))?['total'] ?? 0;

  final totalAhorros = (await db.getOne(
    'SELECT COALESCE(SUM(saldo_actual), 0) as total FROM bolsillos_ahorro'
  ))?['total'] ?? 0;

  final cuentasEnMora = await db.query(
    "SELECT * FROM cuentas_cobrar WHERE estado = 'vencida'"
  );

  final tarjetas = await db.query('SELECT * FROM tarjetas_credito');

  final cuotasTarjetas = (await db.getOne('''
    SELECT COALESCE(SUM(ca.valor_cuota), 0) as total
    FROM cuotas_amortizacion ca
    JOIN compras_tarjeta ct ON ca.compra_id = ct.id
    WHERE ca.estado = 'pendiente'
    AND substr(ca.fecha_vencimiento, 1, 7) = ?
  ''', [mesActual]))?['total'] ?? 0;

  final ingD = (ingresosMes as num).toDouble();
  final gastD = (totalGastosFijos as num).toDouble();
  final cuotD = (cuotasTarjetas as num).toDouble();
  final liquidez = ingD - gastD - cuotD;
  final pctEndeudamiento = ingD > 0 ? ((gastD + cuotD) / ingD * 100) : 0.0;

  return {
    'capacidad_crediticia': {
      'ingresos_mes': ingD,
      'total_gastos_fijos': gastD,
      'cuotas_tarjetas_mes': cuotD,
      'liquidez_disponible': liquidez,
      'porcentaje_endeudamiento': pctEndeudamiento,
    },
    'totales': {
      'deuda_tarjetas': (deudaTarjetas as num).toDouble(),
      'total_ahorros': (totalAhorros as num).toDouble(),
    },
    'tarjetas': tarjetas,
    'cuentas_en_mora': cuentasEnMora,
  };
});
