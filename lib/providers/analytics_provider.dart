import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/dao/analytics_dao.dart';

// Definimos un Provider parametrizado para la analítica (acepta el abono extra)
final analyticsProvider = FutureProvider.family<Map<String, dynamic>, double>((ref, abonoExtra) async {
  return await AnalyticsDao.instance.getAnalytics(pctAbonoExtra: abonoExtra);
});

typedef AdvancedAnalyticsParams = ({String? mes, double abonoExtra});

final advancedAnalyticsProvider = FutureProvider.family<Map<String, dynamic>, AdvancedAnalyticsParams>((ref, params) async {
  return await AnalyticsDao.instance.getAdvancedAnalytics(mes: params.mes, abonoExtra: params.abonoExtra);
});
