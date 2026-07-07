// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:gastos_e_ingresos/main.dart';
import 'package:gastos_e_ingresos/providers/app_providers.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DashboardProvider()),
          ChangeNotifierProvider(create: (_) => TarjetasProvider()),
          ChangeNotifierProvider(create: (_) => IngresosProvider()),
          ChangeNotifierProvider(create: (_) => GastosProvider()),
          ChangeNotifierProvider(create: (_) => AhorrosProvider()),
          ChangeNotifierProvider(create: (_) => CuentasCobrarProvider()),
          ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
        ],
        child: const FinanzasApp(),
      ),
    );
  });
}
