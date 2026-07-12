import 'cuota_amortizacion.dart';

class CompraTarjeta {
  final int id;
  final int tarjetaId;
  final String descripcion;
  final double montoTotal;
  final int numCuotas;
  final int cuotaActual;
  final double tasaInteresMensual;
  final double saldoCapital;
  final String fechaCompra;
  final int esAvance;
  final String? categoria;
  
  // Lista opcional de cuotas asociadas
  final List<CuotaAmortizacion>? cuotas;
  
  // Campos auxiliares para la UI
  final String? nombreTarjeta;
  final String? tarjetaColor;

  CompraTarjeta({
    required this.id,
    required this.tarjetaId,
    required this.descripcion,
    required this.montoTotal,
    required this.numCuotas,
    required this.cuotaActual,
    required this.tasaInteresMensual,
    required this.saldoCapital,
    required this.fechaCompra,
    required this.esAvance,
    this.categoria,
    this.cuotas,
    this.nombreTarjeta,
    this.tarjetaColor,
  });

  factory CompraTarjeta.fromMap(Map<String, dynamic> map) {
    List<CuotaAmortizacion>? parsedCuotas;
    if (map['cuotas'] != null && map['cuotas'] is List) {
      parsedCuotas = (map['cuotas'] as List)
          .map((c) => CuotaAmortizacion.fromMap(c as Map<String, dynamic>))
          .toList();
    }

    return CompraTarjeta(
      id: map['id'] as int,
      tarjetaId: map['tarjeta_id'] as int,
      descripcion: map['descripcion'] ?? '',
      montoTotal: (map['monto_total'] as num?)?.toDouble() ?? 0.0,
      numCuotas: map['num_cuotas'] as int? ?? 1,
      cuotaActual: map['cuota_actual'] as int? ?? 1,
      tasaInteresMensual: (map['tasa_interes_mensual'] as num?)?.toDouble() ?? 0.0,
      saldoCapital: (map['saldo_capital'] as num?)?.toDouble() ?? 0.0,
      fechaCompra: map['fecha_compra'] ?? '',
      esAvance: map['es_avance'] ?? 0,
      categoria: map['categoria'],
      cuotas: parsedCuotas,
      nombreTarjeta: map['nombre_tarjeta'],
      tarjetaColor: map['tarjeta_color'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tarjeta_id': tarjetaId,
      'descripcion': descripcion,
      'monto_total': montoTotal,
      'num_cuotas': numCuotas,
      'cuota_actual': cuotaActual,
      'tasa_interes_mensual': tasaInteresMensual,
      'saldo_capital': saldoCapital,
      'fecha_compra': fechaCompra,
      'es_avance': esAvance,
      'categoria': categoria,
    };
  }
}
