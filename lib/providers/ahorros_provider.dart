import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/dao/ahorros_dao.dart';
import '../models/bolsillo_ahorro.dart';

final ahorrosProvider = FutureProvider<List<BolsilloAhorro>>((ref) async {
  return await AhorrosDao.instance.getAhorros();
});
