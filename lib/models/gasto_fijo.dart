class GastoFijo {
  final int id;
  final int categoriaId;
  final String nombre;
  final double monto;
  final int diaPago;
  final int esFijo;
  final String mesReferencia;
  final String? notas;
  final int activo;
  final String? fechaUltimoPago;

  // Datos adicionales (JOIN)
  final String? categoriaNombre;
  final String? categoriaIcono;
  final String? categoriaColor;

  GastoFijo({
    required this.id,
    required this.categoriaId,
    required this.nombre,
    required this.monto,
    required this.diaPago,
    required this.esFijo,
    required this.mesReferencia,
    this.notas,
    required this.activo,
    this.fechaUltimoPago,
    this.categoriaNombre,
    this.categoriaIcono,
    this.categoriaColor,
  });

  factory GastoFijo.fromMap(Map<String, dynamic> map) {
    return GastoFijo(
      id: map['id'] as int,
      categoriaId: map['categoria_id'] ?? 0,
      nombre: map['nombre'] ?? '',
      monto: (map['monto'] as num).toDouble(),
      diaPago: map['dia_pago'] ?? 0,
      esFijo: map['es_fijo'] ?? 1,
      mesReferencia: map['mes_referencia'] ?? '',
      notas: map['notas'],
      activo: map['activo'] ?? 1,
      fechaUltimoPago: map['fecha_ultimo_pago'],
      categoriaNombre: map['categoria_nombre'],
      categoriaIcono: map['categoria_icono'],
      categoriaColor: map['categoria_color'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoria_id': categoriaId,
      'nombre': nombre,
      'monto': monto,
      'dia_pago': diaPago,
      'es_fijo': esFijo,
      'mes_referencia': mesReferencia,
      'notas': notas,
      'activo': activo,
      'fecha_ultimo_pago': fechaUltimoPago,
    };
  }
}
