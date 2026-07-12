import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/dao/ingresos_dao.dart';
import '../models/ingreso.dart';

final ingresosProvider = FutureProvider.family<List<Ingreso>, String?>((ref, mes) async {
  return await IngresosDao.instance.getIngresos(mes: mes);
});
