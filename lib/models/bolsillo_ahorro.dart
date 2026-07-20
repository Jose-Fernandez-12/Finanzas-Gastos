class BolsilloAhorro {
  final int id;
  final String nombre;
  final double metaMonto;
  final double montoActual;
  final String fechaCreacion;
  final String? fechaMeta;
  final String color;
  final String? notas;
  final int activo;

  // Nuevos campos para cuotas
  final double cuotaMonto;
  final String frecuenciaCuota;
  final int? mesesMeta;

  BolsilloAhorro({
    required this.id,
    required this.nombre,
    required this.metaMonto,
    required this.montoActual,
    required this.fechaCreacion,
    this.fechaMeta,
    required this.color,
    this.notas,
    required this.activo,
    this.cuotaMonto = 0.0,
    this.frecuenciaCuota = 'Mensual',
    this.mesesMeta,
  });

  factory BolsilloAhorro.fromMap(Map<String, dynamic> map) {
    return BolsilloAhorro(
      id: map['id'] as int,
      nombre: map['nombre'] ?? '',
      metaMonto: (map['meta_monto'] as num).toDouble(),
      montoActual: (map['monto_actual'] as num).toDouble(),
      fechaCreacion: map['fecha_creacion'] ?? '',
      fechaMeta: map['fecha_meta'],
      color: map['color'] ?? '#4CAF50',
      notas: map['notas'],
      activo: map['activo'] ?? 1,
      cuotaMonto: (map['cuota_monto'] ?? 0.0) is num ? (map['cuota_monto'] as num).toDouble() : double.tryParse(map['cuota_monto'].toString()) ?? 0.0,
      frecuenciaCuota: map['frecuencia_cuota'] ?? 'Mensual',
      mesesMeta: map['meses_meta'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'meta_monto': metaMonto,
      'monto_actual': montoActual,
      'fecha_creacion': fechaCreacion,
      'fecha_meta': fechaMeta,
      'color': color,
      'notas': notas,
      'activo': activo,
      'cuota_monto': cuotaMonto,
      'frecuencia_cuota': frecuenciaCuota,
      'meses_meta': mesesMeta,
    };
  }
}
