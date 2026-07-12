class CuentaCobrar {
  final int id;
  final String nombreDeudor;
  final String? telefono;
  final double montoTotal;
  final double saldoPendiente;
  final String? modalidad;
  final int numCuotas;
  final double? valorCuota;
  final String? fechaPrimerVencimiento;
  final String? periodicidad;
  final String estado;
  final String? notas;

  CuentaCobrar({
    required this.id,
    required this.nombreDeudor,
    this.telefono,
    required this.montoTotal,
    required this.saldoPendiente,
    this.modalidad,
    required this.numCuotas,
    this.valorCuota,
    this.fechaPrimerVencimiento,
    this.periodicidad,
    required this.estado,
    this.notas,
  });

  factory CuentaCobrar.fromMap(Map<String, dynamic> map) {
    return CuentaCobrar(
      id: map['id'] as int,
      nombreDeudor: map['nombre_deudor'] ?? '',
      telefono: map['telefono'],
      montoTotal: (map['monto_total'] as num?)?.toDouble() ?? 0.0,
      saldoPendiente: (map['saldo_pendiente'] as num?)?.toDouble() ?? 0.0,
      modalidad: map['modalidad'],
      numCuotas: (map['num_cuotas'] as num?)?.toInt() ?? 1,
      valorCuota: (map['valor_cuota'] as num?)?.toDouble(),
      fechaPrimerVencimiento: map['fecha_primer_vencimiento'],
      periodicidad: map['periodicidad'],
      estado: map['estado'] ?? 'AL_DIA',
      notas: map['notas'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre_deudor': nombreDeudor,
      'telefono': telefono,
      'monto_total': montoTotal,
      'saldo_pendiente': saldoPendiente,
      'modalidad': modalidad,
      'num_cuotas': numCuotas,
      'valor_cuota': valorCuota,
      'fecha_primer_vencimiento': fechaPrimerVencimiento,
      'periodicidad': periodicidad,
      'estado': estado,
      'notas': notas,
    };
  }
}
