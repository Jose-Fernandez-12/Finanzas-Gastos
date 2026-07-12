import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/dao/cuentas_cobrar_dao.dart';
import '../models/cuenta_cobrar.dart';

final cuentasCobrarProvider = FutureProvider<List<CuentaCobrar>>((ref) async {
  return await CuentasCobrarDao.instance.getCuentasCobrar();
});
