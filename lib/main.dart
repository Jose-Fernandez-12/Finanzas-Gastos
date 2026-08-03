import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme.dart';
import 'core/notification_listener_channel.dart';
import 'core/transaction_classifier.dart';
import 'screens/dashboard_screen.dart';
import 'screens/movimientos_screen.dart';
import 'screens/finanzas_screen.dart';
import 'screens/mas_screen.dart';
import 'screens/ingresos_screen.dart';
import 'screens/gastos_screen.dart';
import 'screens/tarjetas/tarjetas_screen.dart';
import 'screens/tarjetas/forms.dart';
import 'screens/ahorros_screen.dart';
import 'screens/suscripciones_screen.dart';
import 'screens/cuentas_cobrar_screen.dart';
import 'screens/notificaciones/gasto_detectado_dialog.dart';
import 'widgets/virtual_assistant_widget.dart';
import 'widgets/custom_bottom_nav.dart';
import 'widgets/quick_add_sheet.dart';
import 'providers/virtual_assistant_provider.dart';

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
      // Rutas para el QuickAddSheet
      routes: {
        '/ingresos/nuevo':         (_) => const IngresosScreen(),
        '/gastos/nuevo':           (_) => const GastosScreen(),
        '/tarjetas/nueva-compra':  (_) => const TarjetasScreen(),
        '/suscripciones/nueva':    (_) => const SuscripcionesScreen(),
        '/ahorros/nueva':          (_) => const AhorrosScreen(),
        '/cuentas-cobrar/nuevo':   (_) => const CuentasCobrarScreen(),
      },
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            // Rocky — global, aparece en todas las pantallas
            const GlobalVirtualAssistant(),
          ],
        );
      },
    );
  }
}

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});
  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  /// Indices mapeados a pantallas reales (FAB en pos. 2 no tiene pantalla)
  /// 0=Inicio, 1=Movimientos, 2=Finanzas, 3=Mas
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    DashboardScreen(
      onNavigate: (i) => setState(() => _currentIndex = i),
    ),
    const MovimientosScreen(),
    const FinanzasScreen(),
    const MasScreen(),
  ];

  static const _viewNames = ['inicio', 'movimientos', 'finanzas', 'mas'];

  // ── Mapeo index de pantalla → contexto del FAB ─────────────
  static const _fabContexts = [
    QuickAddContext.inicio,
    QuickAddContext.movimientos,
    QuickAddContext.finanzas,
    QuickAddContext.mas,
  ];

  // ── Transacciones detectadas ─────────────────────────────────
  bool _isShowingDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationListenerChannel.instance.fetchActiveNotifications();
      _checkPendingTransactions();
      _listenForRealTimeTransactions();
    });
  }

  Future<void> _checkPendingTransactions() async {
    if (_isShowingDialog) return;
    final pending = await NotificationListenerChannel.instance.getPendingTransactions();
    if (!mounted || pending.isEmpty) return;
    _isShowingDialog = true;
    _showGastoDetectado(pending.first, 0);
  }

  void _listenForRealTimeTransactions() {
    NotificationListenerChannel.instance.transactionStream.listen((data) {
      if (mounted) _checkPendingTransactions();
    });
  }

  Future<void> _showGastoDetectado(Map<String, dynamic> rawData, int index) async {
    final classification = await TransactionClassifier.classify(rawData);
    if (!mounted) {
      _isShowingDialog = false;
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GastoDetectadoDialog(
        rawData: rawData,
        pendingIndex: index >= 0 ? index : 0,
        classification: classification,
        onDone: () {
          _isShowingDialog = false;
          _checkPendingTransactions();
        },
      ),
    ).then((_) {
      if (_isShowingDialog) {
        _isShowingDialog = false;
        _checkPendingTransactions();
      }
    });
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTabSelected: (i) {
          setState(() => _currentIndex = i);
          if (i < _viewNames.length) {
            ref.read(virtualAssistantProvider.notifier).setCurrentView(_viewNames[i]);
          }
        },
        onFabTap: () => showQuickAddSheet(context, _fabContexts[_currentIndex]),
      ),
    );
  }
}
