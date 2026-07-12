import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/dao/tarjetas_dao.dart';
import '../models/tarjeta_credito.dart';
import '../models/compra_tarjeta.dart';
import '../models/cuota_amortizacion.dart';

final tarjetasProvider = FutureProvider<List<TarjetaCredito>>((ref) async {
  return await TarjetasDao.instance.getTarjetas();
});

final comprasTarjetaProvider = FutureProvider.family<List<CompraTarjeta>, int>((ref, tarjetaId) async {
  return await TarjetasDao.instance.getComprasTarjeta(tarjetaId);
});

final comprasActivasProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final tarjetas = await ref.watch(tarjetasProvider.future);
  List<Map<String, dynamic>> activas = [];
  
  for (var t in tarjetas) {
    final compras = await TarjetasDao.instance.getComprasTarjeta(t.id);
    for (var c in compras) {
      final cuotas = c.cuotas ?? [];
      final todasPagadas = cuotas.isNotEmpty && cuotas.every((cuota) => cuota.estado == 'PAGADA');
      if (!todasPagadas && c.saldoCapital > 1) {
        CuotaAmortizacion? cuotaActualOb;
        try {
          cuotaActualOb = cuotas.firstWhere((q) => q.numeroCuota == c.cuotaActual);
        } catch (_) {
          if (cuotas.isNotEmpty) cuotaActualOb = cuotas.last;
        }
        final valorCuota = cuotaActualOb?.valorCuota ?? 0.0;
        activas.add({
          'id': c.id,
          'descripcion': c.descripcion,
          'monto_total': c.montoTotal,
          'valor_cuota': valorCuota,
          'cuota_actual': c.cuotaActual,
          'num_cuotas': c.numCuotas,
          'saldo_capital': c.saldoCapital,
          'nombre_tarjeta': t.nombreTarjeta.isNotEmpty ? t.nombreTarjeta : t.banco,
          'tarjeta_color': t.color,
          'tarjeta_id': t.id,
        });
      }
    }
  }
  return activas;
});
