import 'categoria.dart';

class Ingreso {
  final int id;
  final int categoriaId;
  final String? descripcion;
  final double monto;
  final int esFijo;
  final String fecha;
  final String mesReferencia;
  final String? notas;
  
  // Datos adicionales (JOIN)
  final String? categoriaNombre;
  final String? categoriaIcono;
  final String? categoriaColor;

  Ingreso({
    required this.id,
    required this.categoriaId,
    this.descripcion,
    required this.monto,
    required this.esFijo,
    required this.fecha,
    required this.mesReferencia,
    this.notas,
    this.categoriaNombre,
    this.categoriaIcono,
    this.categoriaColor,
  });

  factory Ingreso.fromMap(Map<String, dynamic> map) {
    return Ingreso(
      id: map['id'] as int,
      categoriaId: map['categoria_id'] as int,
      descripcion: map['descripcion'],
      monto: (map['monto'] as num).toDouble(),
      esFijo: map['es_fijo'] ?? 0,
      fecha: map['fecha'],
      mesReferencia: map['mes_referencia'] ?? '',
      notas: map['notas'],
      categoriaNombre: map['categoria_nombre'],
      categoriaIcono: map['categoria_icono'],
      categoriaColor: map['categoria_color'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoria_id': categoriaId,
      'descripcion': descripcion,
      'monto': monto,
      'es_fijo': esFijo,
      'fecha': fecha,
      'mes_referencia': mesReferencia,
      'notas': notas,
    };
  }
}
