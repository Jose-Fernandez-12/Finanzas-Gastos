import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/tarjetas/tarjetas_screen.dart';
import 'screens/ingresos_screen.dart';
import 'screens/gastos_screen.dart';
import 'screens/ahorros_screen.dart';
import 'screens/cuentas_cobrar_screen.dart';

import 'core/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);

  // Inicializar notificaciones
  final notifService = NotificationService.instance;
  await notifService.init();
  await notifService.requestPermissions();
  
  // Analizar y notificar deudas/pagos próximos
  await notifService.checkAndNotifyUpcomingPayments();

  runApp(
    const ProviderScope(
      child: FinanzasApp(),
    ),
  );
}

class FinanzasApp extends StatelessWidget {
  const FinanzasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mis Finanzas',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});
  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    DashboardScreen(
      onNavigate: (i) {
        setState(() => _currentIndex = i);
      },
    ),
    const IngresosScreen(),
    const GastosScreen(),
    const TarjetasScreen(),
    const AhorrosScreen(),
    const CuentasCobrarScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          border: const Border(top: BorderSide(color: AppTheme.borderLight)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          backgroundColor: AppTheme.bgCard,
          indicatorColor: AppTheme.primary.withAlpha(25),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) {
            setState(() => _currentIndex = i);
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_rounded),       label: 'Inicio'),
            NavigationDestination(icon: Icon(Icons.trending_up_rounded),     label: 'Ingresos'),
            NavigationDestination(icon: Icon(Icons.receipt_long_rounded),    label: 'Gastos'),
            NavigationDestination(icon: Icon(Icons.credit_card_rounded),     label: 'Tarjetas'),
            NavigationDestination(icon: Icon(Icons.savings_rounded),         label: 'Ahorros'),
            NavigationDestination(icon: Icon(Icons.people_rounded),          label: 'Cobrar'),
          ],
        ),
      ),
    );
  }
}
