class TarjetaCredito {
  final int id;
  final String banco;
  final String nombreTarjeta;
  final double cupoTotal;
  final double cupoDisponible;
  final int fechaCorte;
  final int fechaPago;
  final double tasaInteresMensual;
  final double cupoAvancesTotal;
  final double cuotaManejo;
  final String color;
  final String? notas;
  final int activa;

  // Campos calculados / auxiliares (JOIN / SUM)
  final double totalDeudaActiva;
  final double cuotaMesActual;
  final double cupoAvancesDisponible;

  TarjetaCredito({
    required this.id,
    required this.banco,
    required this.nombreTarjeta,
    required this.cupoTotal,
    required this.cupoDisponible,
    required this.fechaCorte,
    required this.fechaPago,
    required this.tasaInteresMensual,
    required this.cupoAvancesTotal,
    required this.cuotaManejo,
    required this.color,
    this.notas,
    required this.activa,
    this.totalDeudaActiva = 0.0,
    this.cuotaMesActual = 0.0,
    this.cupoAvancesDisponible = 0.0,
  });

  factory TarjetaCredito.fromMap(Map<String, dynamic> map) {
    return TarjetaCredito(
      id: map['id'] as int,
      banco: map['banco'] ?? '',
      nombreTarjeta: map['nombre_tarjeta'] ?? '',
      cupoTotal: (map['cupo_total'] as num?)?.toDouble() ?? 0.0,
      cupoDisponible: (map['cupo_disponible'] as num?)?.toDouble() ?? 0.0,
      fechaCorte: map['fecha_corte'] as int? ?? 1,
      fechaPago: map['fecha_pago'] as int? ?? 1,
      tasaInteresMensual: (map['tasa_interes_mensual'] as num?)?.toDouble() ?? 0.0,
      cupoAvancesTotal: (map['cupo_avances_total'] as num?)?.toDouble() ?? 0.0,
      cuotaManejo: (map['cuota_manejo'] as num?)?.toDouble() ?? 0.0,
      color: map['color'] ?? '#1976D2',
      notas: map['notas'],
      activa: map['activa'] ?? 1,
      totalDeudaActiva: (map['total_deuda_activa'] as num?)?.toDouble() ?? 0.0,
      cuotaMesActual: (map['cuota_mes_actual'] as num?)?.toDouble() ?? 0.0,
      cupoAvancesDisponible: (map['cupo_avances_disponible'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'banco': banco,
      'nombre_tarjeta': nombreTarjeta,
      'cupo_total': cupoTotal,
      'cupo_disponible': cupoDisponible,
      'fecha_corte': fechaCorte,
      'fecha_pago': fechaPago,
      'tasa_interes_mensual': tasaInteresMensual,
      'cupo_avances_total': cupoAvancesTotal,
      'cuota_manejo': cuotaManejo,
      'color': color,
      'notas': notas,
      'activa': activa,
    };
  }
}
