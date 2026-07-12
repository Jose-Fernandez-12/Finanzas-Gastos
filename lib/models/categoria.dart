class Categoria {
  final int id;
  final String nombre;
  final String icono;
  final String color;
  final int activa;

  Categoria({
    required this.id,
    required this.nombre,
    required this.icono,
    required this.color,
    required this.activa,
  });

  factory Categoria.fromMap(Map<String, dynamic> map) {
    return Categoria(
      id: map['id'] as int,
      nombre: map['nombre'] ?? '',
      icono: map['icono'] ?? '',
      color: map['color'] ?? '#000000',
      activa: map['activa'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'icono': icono,
      'color': color,
      'activa': activa,
    };
  }
}
