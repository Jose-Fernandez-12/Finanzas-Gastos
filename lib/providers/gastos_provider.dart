import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/dao/gastos_dao.dart';
import '../models/gasto_fijo.dart';

final gastosProvider = FutureProvider.family<List<GastoFijo>, String?>((ref, mes) async {
  return await GastosDao.instance.getGastosFijos(mes: mes);
});
