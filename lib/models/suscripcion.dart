class Suscripcion {
  final int id;
  final String nombre;
  final double monto;
  final int diaCobro;
  final String frecuencia; // 'Mensual', 'Anual', 'Semanal'
  final int recordatorioDias; // 1, 3, 7
  final String color;
  final String? notas;
  final int activa;
  final String? fechaUltimoCobro;

  Suscripcion({
    required this.id,
    required this.nombre,
    required this.monto,
    required this.diaCobro,
    this.frecuencia = 'Mensual',
    this.recordatorioDias = 1,
    required this.color,
    this.notas,
    this.activa = 1,
    this.fechaUltimoCobro,
  });

  factory Suscripcion.fromMap(Map<String, dynamic> map) {
    return Suscripcion(
      id: map['id'] as int,
      nombre: map['nombre'] ?? '',
      monto: (map['monto'] as num).toDouble(),
      diaCobro: map['dia_cobro'] ?? 1,
      frecuencia: map['frecuencia'] ?? 'Mensual',
      recordatorioDias: map['recordatorio_dias'] ?? 1,
      color: map['color'] ?? '#4F46E5',
      notas: map['notas'],
      activa: map['activa'] ?? 1,
      fechaUltimoCobro: map['fecha_ultimo_cobro'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'monto': monto,
      'dia_cobro': diaCobro,
      'frecuencia': frecuencia,
      'recordatorio_dias': recordatorioDias,
      'color': color,
      'notas': notas,
      'activa': activa,
      'fecha_ultimo_cobro': fechaUltimoCobro,
    };
  }

  /// Indica si ya se pago en el periodo actual (mes, semana, anio)
  bool get pagadoEnPeriodoActual {
    if (fechaUltimoCobro == null || fechaUltimoCobro!.isEmpty) return false;
    final now = DateTime.now();
    final ultimoCobro = DateTime.tryParse(fechaUltimoCobro!);
    if (ultimoCobro == null) return false;

    switch (frecuencia) {
      case 'Semanal':
        // Mismo numero de semana ISO
        final nowWeekStart = now.subtract(Duration(days: now.weekday - 1));
        final cobroWeekStart = ultimoCobro.subtract(Duration(days: ultimoCobro.weekday - 1));
        return nowWeekStart.year == cobroWeekStart.year &&
               nowWeekStart.month == cobroWeekStart.month &&
               nowWeekStart.day == cobroWeekStart.day;
      case 'Anual':
        return ultimoCobro.year == now.year;
      default: // Mensual
        return ultimoCobro.year == now.year && ultimoCobro.month == now.month;
    }
  }

  /// Dias que faltan para el proximo cobro (en el mes actual o siguiente)
  int get diasParaProximoCobro {
    final now = DateTime.now();
    DateTime fechaCobro = DateTime(now.year, now.month, diaCobro);

    // Si ya se pago en este periodo, apuntar al siguiente
    if (pagadoEnPeriodoActual) {
      switch (frecuencia) {
        case 'Semanal':
          fechaCobro = now.add(const Duration(days: 7));
          return fechaCobro.difference(DateTime(now.year, now.month, now.day)).inDays;
        case 'Anual':
          fechaCobro = DateTime(now.year + 1, now.month, diaCobro);
          return fechaCobro.difference(DateTime(now.year, now.month, now.day)).inDays;
        default: // Mensual
          fechaCobro = DateTime(now.year, now.month + 1, diaCobro);
          return fechaCobro.difference(DateTime(now.year, now.month, now.day)).inDays;
      }
    }

    if (fechaCobro.isBefore(now) || fechaCobro.day == now.day) {
      fechaCobro = DateTime(now.year, now.month + 1, diaCobro);
    }
    return fechaCobro.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  /// True si vence dentro del periodo de recordatorio
  bool get vencePronto => !pagadoEnPeriodoActual && diasParaProximoCobro <= recordatorioDias;


  /// Costo anual proyectado segun la frecuencia
  double get costoAnual {
    switch (frecuencia) {
      case 'Anual':   return monto;
      case 'Semanal': return monto * 52;
      default:        return monto * 12; // Mensual
    }
  }

  /// Devuelve el color de marca de servicios conocidos
  static String colorParaServicio(String nombre) {
    final n = nombre.toLowerCase();
    if (n.contains('netflix'))      return '#E50914';
    if (n.contains('spotify'))      return '#1DB954';
    if (n.contains('amazon'))       return '#FF9900';
    if (n.contains('disney'))       return '#113CCF';
    if (n.contains('hbo') || n.contains('max')) return '#7B00FF';
    if (n.contains('apple'))        return '#555555';
    if (n.contains('youtube'))      return '#FF0000';
    if (n.contains('crunchyroll'))  return '#F47521';
    if (n.contains('paramount'))    return '#0064FF';
    if (n.contains('deezer'))       return '#FF0092';
    return '#4F46E5'; // Indigo por defecto
  }

  /// Inicial(es) para el avatar cuando no hay logo reconocido
  String get inicial => nombre.isNotEmpty ? nombre[0].toUpperCase() : 'S';
}
