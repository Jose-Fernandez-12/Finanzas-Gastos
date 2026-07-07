import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme.dart';
import 'providers/app_providers.dart';
import 'screens/dashboard_screen.dart';
import 'screens/tarjetas_screen.dart';
import 'screens/ingresos_screen.dart';
import 'screens/gastos_screen.dart';
import 'screens/ahorros_screen.dart';
import 'screens/cuentas_cobrar_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);

  runApp(
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
}

class FinanzasApp extends StatelessWidget {
  const FinanzasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:         'Mis Finanzas',
      theme:         AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home:          const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    DashboardScreen(
      onNavigate: (i) {
        setState(() => _currentIndex = i);
        switch (i) {
          case 0: context.read<DashboardProvider>().cargar();
          case 1: context.read<IngresosProvider>().cargar();
          case 2: context.read<GastosProvider>().cargar();
          case 3: context.read<TarjetasProvider>().cargar();
          case 4: context.read<AhorrosProvider>().cargar();
          case 5: context.read<CuentasCobrarProvider>().cargar();
        }
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
        index:    _currentIndex,
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
          selectedIndex:    _currentIndex,
          backgroundColor:  AppTheme.bgCard,
          indicatorColor:   AppTheme.primary.withAlpha(25),
          labelBehavior:    NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) {
            setState(() => _currentIndex = i);
            // Recargar datos al cambiar de pantalla
            switch (i) {
              case 0: context.read<DashboardProvider>().cargar();
              case 1: context.read<IngresosProvider>().cargar();
              case 2: context.read<GastosProvider>().cargar();
              case 3: context.read<TarjetasProvider>().cargar();
              case 4: context.read<AhorrosProvider>().cargar();
              case 5: context.read<CuentasCobrarProvider>().cargar();
            }
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
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              mini:      true,
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              tooltip:   'Configuracion del servidor',
              child:     const Icon(Icons.settings_rounded),
            )
          : null,
    );
  }
}
