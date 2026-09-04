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
          cuotaActualOb = cuotas.firstWhere((q) => q.numeroCuota == c.cuotaActual && q.estado == 'PENDIENTE');
        } catch (_) {
          try {
            cuotaActualOb = cuotas.firstWhere((q) => q.estado == 'PENDIENTE');
          } catch (_) {
            if (cuotas.isNotEmpty) cuotaActualOb = cuotas.last;
          }
        }
        
        if (cuotaActualOb != null && cuotaActualOb.fechaVencimiento.isNotEmpty) {
          try {
            final fPago = DateTime.parse("${cuotaActualOb.fechaVencimiento}T00:00:00");
            DateTime fCorte = DateTime(fPago.year, fPago.month, t.fechaCorte);
            if (fCorte.isAfter(fPago) || fCorte.isAtSameMomentAs(fPago)) {
              fCorte = DateTime(fCorte.year, fCorte.month - 1, fCorte.day);
            }
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            
            // Si hoy es antes de la fecha de corte, no la mostramos como "activa" para pagar
            if (today.isBefore(fCorte)) {
              continue;
            }
          } catch (_) {}
        }

        final valorCuota = cuotaActualOb?.valorCuota ?? 0.0;
        activas.add({
          'id': c.id,
          'descripcion': c.descripcion,
          'monto_total': c.montoTotal,
          'valor_cuota': valorCuota,
          'cuota_actual': cuotaActualOb?.numeroCuota ?? c.cuotaActual,
          'num_cuotas': c.numCuotas,
          'saldo_capital': c.saldoCapital,
          'nombre_tarjeta': t.nombreTarjeta.isNotEmpty ? t.nombreTarjeta : t.banco,
          'tarjeta_color': t.color,
          'tarjeta_id': t.id,
          'cuota_id': cuotaActualOb?.id,
          'fecha_vencimiento': cuotaActualOb?.fechaVencimiento,
          'tarjeta_obj': t,
        });
      }
    }
  }
  return activas;
});

final todasLasComprasProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final tarjetas = await ref.watch(tarjetasProvider.future);
  List<Map<String, dynamic>> todas = [];
  
  for (var t in tarjetas) {
    final compras = await TarjetasDao.instance.getComprasTarjeta(t.id);
    for (var c in compras) {
      final cuotas = c.cuotas ?? [];
      final todasPagadas = cuotas.isNotEmpty && cuotas.every((cuota) => cuota.estado == 'PAGADA');
      
      CuotaAmortizacion? cuotaActualOb;
      try {
        cuotaActualOb = cuotas.firstWhere((q) => q.numeroCuota == c.cuotaActual && q.estado == 'PENDIENTE');
      } catch (_) {
        try {
          cuotaActualOb = cuotas.firstWhere((q) => q.estado == 'PENDIENTE');
        } catch (_) {
          if (cuotas.isNotEmpty) cuotaActualOb = cuotas.last;
        }
      }
      final valorCuota = cuotaActualOb?.valorCuota ?? 0.0;
      
      todas.add({
        'id': c.id,
        'descripcion': c.descripcion,
        'monto_total': c.montoTotal,
        'valor_cuota': valorCuota,
        'cuota_actual': cuotaActualOb?.numeroCuota ?? c.cuotaActual,
        'num_cuotas': c.numCuotas,
        'saldo_capital': c.saldoCapital,
        'nombre_tarjeta': t.nombreTarjeta.isNotEmpty ? t.nombreTarjeta : t.banco,
        'tarjeta_color': t.color,
        'tarjeta_id': t.id,
        'cuota_id': cuotaActualOb?.id,
        'fecha_vencimiento': cuotaActualOb?.fechaVencimiento,
        'tasa_interes_mensual': c.tasaInteresMensual,
        'pagada': todasPagadas || c.saldoCapital <= 1,
        'tarjeta_obj': t,
      });
    }
  }
  return todas;
});
