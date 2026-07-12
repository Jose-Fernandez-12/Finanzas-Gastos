class CuotaAmortizacion {
  final int id;
  final int compraId;
  final int tarjetaId;
  final int numeroCuota;
  final String fechaVencimiento;
  final double valorCuota;
  final double valorCapital;
  final double valorInteres;
  final double saldoRestante;
  final String estado; // PENDIENTE o PAGADA

  CuotaAmortizacion({
    required this.id,
    required this.compraId,
    required this.tarjetaId,
    required this.numeroCuota,
    required this.fechaVencimiento,
    required this.valorCuota,
    required this.valorCapital,
    required this.valorInteres,
    required this.saldoRestante,
    required this.estado,
  });

  factory CuotaAmortizacion.fromMap(Map<String, dynamic> map) {
    return CuotaAmortizacion(
      id: map['id'] as int,
      compraId: map['compra_id'] as int,
      tarjetaId: map['tarjeta_id'] as int,
      numeroCuota: map['numero_cuota'] as int,
      fechaVencimiento: map['fecha_vencimiento'] ?? '',
      valorCuota: (map['valor_cuota'] as num?)?.toDouble() ?? 0.0,
      valorCapital: (map['valor_capital'] as num?)?.toDouble() ?? 0.0,
      valorInteres: (map['valor_interes'] as num?)?.toDouble() ?? 0.0,
      saldoRestante: (map['saldo_restante'] as num?)?.toDouble() ?? 0.0,
      estado: map['estado'] ?? 'PENDIENTE',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'compra_id': compraId,
      'tarjeta_id': tarjetaId,
      'numero_cuota': numeroCuota,
      'fecha_vencimiento': fechaVencimiento,
      'valor_cuota': valorCuota,
      'valor_capital': valorCapital,
      'valor_interes': valorInteres,
      'saldo_restante': saldoRestante,
      'estado': estado,
    };
  }
}
