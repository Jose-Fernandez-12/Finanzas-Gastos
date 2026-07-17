import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme.dart';
import 'core/notification_listener_channel.dart';
import 'core/transaction_classifier.dart';
import 'screens/dashboard_screen.dart';
import 'screens/tarjetas/tarjetas_screen.dart';
import 'screens/ingresos_screen.dart';
import 'screens/gastos_screen.dart';
import 'screens/ahorros_screen.dart';
import 'screens/cuentas_cobrar_screen.dart';
import 'screens/notificaciones/gasto_detectado_dialog.dart';

import 'core/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);

  // Inicializar notificaciones locales (alertas de pago)
  final notifService = NotificationService.instance;
  await notifService.init();
  await notifService.requestPermissions();
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
  void initState() {
    super.initState();
    // Al abrir la app, verificar si hay transacciones detectadas pendientes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingTransactions();
      _listenForRealTimeTransactions();
    });
  }

  /// Verifica transacciones pendientes guardadas mientras la app estaba cerrada
  Future<void> _checkPendingTransactions() async {
    final pending = await NotificationListenerChannel.instance.getPendingTransactions();
    if (!mounted || pending.isEmpty) return;

    // Mostrar el dialog para la primera transaccion pendiente
    _showGastoDetectado(pending.first, 0);
  }

  /// Escucha transacciones en tiempo real mientras la app esta abierta
  void _listenForRealTimeTransactions() {
    NotificationListenerChannel.instance.transactionStream.listen((data) {
      if (mounted) _showGastoDetectado(data, -1);
    });
  }

  Future<void> _showGastoDetectado(Map<String, dynamic> rawData, int index) async {
    final classification = await TransactionClassifier.classify(rawData);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GastoDetectadoDialog(
        rawData: rawData,
        pendingIndex: index >= 0 ? index : 0,
        classification: classification,
        onDone: () {
          // Verificar si hay mas transacciones pendientes
          if (index >= 0) _checkPendingTransactions();
        },
      ),
    );
  }

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
