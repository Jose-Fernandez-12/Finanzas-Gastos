import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/dao/analytics_dao.dart';

// Definimos un Provider parametrizado para la analítica (acepta el abono extra)
final analyticsProvider = FutureProvider.family<Map<String, dynamic>, double>((ref, abonoExtra) async {
  return await AnalyticsDao.instance.getAnalytics(pctAbonoExtra: abonoExtra);
});

final advancedAnalyticsProvider = FutureProvider.family<Map<String, dynamic>, Map<String, dynamic>>((ref, params) async {
  final mes = params['mes'] as String?;
  final abonoExtra = (params['abonoExtra'] as num?)?.toDouble() ?? 200000.0;
  return await AnalyticsDao.instance.getAdvancedAnalytics(mes: mes, abonoExtra: abonoExtra);
});
