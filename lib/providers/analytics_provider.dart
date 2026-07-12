import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/dao/analytics_dao.dart';

// Definimos un Provider parametrizado para la analítica (acepta el abono extra)
final analyticsProvider = FutureProvider.family<Map<String, dynamic>, double>((ref, abonoExtra) async {
  return await AnalyticsDao.instance.getAnalytics(pctAbonoExtra: abonoExtra);
});
