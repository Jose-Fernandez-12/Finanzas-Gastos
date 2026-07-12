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
    };
  }
}
