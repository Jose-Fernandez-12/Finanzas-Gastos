import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/formatters.dart';
import '../providers/dashboard_provider.dart';
import '../providers/virtual_assistant_provider.dart';
import '../widgets/common_widgets.dart';
import 'tarjetas/tarjeta_detalle_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';
import '../models/bolsillo_ahorro.dart';
import '../models/tarjeta_credito.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final Function(int)? onNavigate;
  const DashboardScreen({super.key, this.onNavigate});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(virtualAssistantProvider.notifier).setCurrentView('dashboard');
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mis Finanzas', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            Text(
              formatMes(mesActual()),
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.settings_rounded, color: AppTheme.textSecondary, size: 20),
            ),
            tooltip: 'Configuración',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.analytics_rounded, color: AppTheme.primary, size: 20),
            ),
            tooltip: 'Analíticas',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
            onPressed: () => ref.invalidate(dashboardProvider),
          ),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (err, stack) => _ErrorView(error: err.toString(), onRetry: () => ref.invalidate(dashboardProvider)),
        data: (response) {
          final data = response['data'] as Map<String, dynamic>;
          final cap = data['capacidad_crediticia'] as Map<String, dynamic>;
          final pctEndeudamiento = (cap['porcentaje_endeudamiento'] as num).toDouble();
          final nivelRiesgo = cap['nivel_riesgo'] as String;
          final liquidez = (cap['liquidez_disponible'] as num).toDouble();
          final ingresos = (cap['ingresos_mes'] as num).toDouble();
          final gastosFijos = (cap['total_gastos_fijos'] as num).toDouble();
          final cuotasTarj = (cap['cuotas_tarjetas_mes'] as num).toDouble();

          final totales = data['totales'] as Map<String, dynamic>;
          final totalCuentasCobrar = (totales['cuentas_cobrar'] as num).toDouble();
          final totalAhorros = (totales['total_ahorros'] as num).toDouble();
          final totalDeudaTarjetas = (totales['deuda_tarjetas'] as num).toDouble();

          final proximasCuotas = data['proximas_cuotas'] as List<dynamic>;
          final ahorros = data['ahorros'] as List<dynamic>;
          final cuentasMora = data['cuentas_en_mora'] as List<dynamic>;
          final tarjetasData = data['tarjetas'] as List<dynamic>;

          // Calcular alertas de pago para los próximos 3 días
          final now = DateTime.now();
          final limitDate = now.add(const Duration(days: 3));
          final List<Map<String, dynamic>> alertasVencimiento = [];

          // 1. Tarjetas
          for (var c in proximasCuotas) {
            final Map<String, dynamic> cuota = Map<String, dynamic>.from(c);
            final fechaVencStr = cuota['fecha_vencimiento']?.toString();
            if (fechaVencStr != null) {
              final fechaVenc = DateTime.tryParse(fechaVencStr);
              if (fechaVenc != null && fechaVenc.isAfter(now.subtract(const Duration(days: 1))) && fechaVenc.isBefore(limitDate)) {
                final diffDays = fechaVenc.difference(now).inDays + 1;
                alertasVencimiento.add({
                  'tipo': 'Tarjeta',
                  'descripcion': '${cuota['compra_descripcion'] ?? 'Cuota'} (${cuota['nombre_tarjeta'] ?? 'TC'})',
                  'monto': (cuota['valor_cuota'] as num?)?.toDouble() ?? 0.0,
                  'vence_en': '$diffDays día(s)',
                });
              }
            }
          }

          // 2. Cuentas en mora
          for (var c in cuentasMora) {
            alertasVencimiento.add({
              'tipo': 'Deudores en Mora',
              'descripcion': 'Cobro atrasado de ${c['nombre_deudor']}',
              'monto': (c['saldo_pendiente'] as num?)?.toDouble() ?? 0.0,
              'vence_en': 'VENCIDO',
            });
          }

          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async => ref.invalidate(dashboardProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // --- Banner de Alertas de Pago ---
                if (alertasVencimiento.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF1744).withAlpha(60),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.notification_important_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'ALERTAS DE PAGO PENDIENTES',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.8),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...alertasVencimiento.map((al) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${al['tipo']}: ${al['descripcion']}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${formatCOP(al['monto'] as double)} (${al['vence_en']})',
                                style: AppTheme.monoStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ],

                // --- Capacidad Crediticia ---
                CapacidadCrediticiaCard(
                  pct: pctEndeudamiento,
                  nivel: nivelRiesgo,
                  liquidez: liquidez,
                ),
                const SizedBox(height: 16),

                // --- Resumen de 4 cuadros principales ---
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: MediaQuery.of(context).size.width < 400 ? 1.35 : 1.55,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    SummaryCard(
                      label: 'Liquidez',
                      monto: liquidez,
                      color: AppTheme.secondary,
                      icon: Icons.account_balance_wallet_rounded,
                      onTap: null,
                    ),
                    SummaryCard(
                      label: 'Ingresos (Mes)',
                      monto: ingresos,
                      color: AppTheme.colorIngresos,
                      icon: Icons.trending_up_rounded,
                      onTap: () => widget.onNavigate?.call(1),
                    ),
                    SummaryCard(
                      label: 'Gastos Fijos',
                      monto: gastosFijos,
                      color: AppTheme.colorGastos,
                      icon: Icons.trending_down_rounded,
                      onTap: () => widget.onNavigate?.call(2),
                    ),
                    SummaryCard(
                      label: 'Cuotas TdC',
                      monto: cuotasTarj,
                      color: AppTheme.colorDeudas,
                      icon: Icons.credit_card_rounded,
                      onTap: () => widget.onNavigate?.call(3),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // --- Proyecciones y Deudas Totales ---
                const _SectionTitle(title: 'Proyecciones & Saldos'),
                const SizedBox(height: 12),
                _WideSummaryCard(
                  title: 'Libre a fin de mes',
                  subtitle: 'Proyección calculada',
                  total: liquidez,
                  color: AppTheme.secondary,
                  icon: Icons.savings_outlined,
                ),
                const SizedBox(height: 10),
                _WideSummaryCard(
                  title: 'Cuentas por cobrar',
                  subtitle: 'Deudores activos',
                  total: totalCuentasCobrar,
                  color: AppTheme.primary,
                  icon: Icons.people_rounded,
                  onTap: () => widget.onNavigate?.call(5),
                ),
                const SizedBox(height: 10),
                if (totalAhorros > 0) ...[
                  _WideSummaryCard(
                    title: 'Total ahorros',
                    subtitle: 'Fondo de emergencia',
                    total: totalAhorros,
                    color: AppTheme.colorAhorros,
                    icon: Icons.savings_rounded,
                    onTap: () => widget.onNavigate?.call(4),
                  ),
                  const SizedBox(height: 10),
                ],
                if (totalDeudaTarjetas > 0) ...[
                  _WideSummaryCard(
                    title: 'Deuda activa en tarjetas',
                    subtitle: 'Saldo total adeudado',
                    total: totalDeudaTarjetas,
                    color: AppTheme.colorDeudas,
                    icon: Icons.credit_card_rounded,
                  ),
                  const SizedBox(height: 24),
                ],

                // --- Proximas cuotas a vencer ---
                if (proximasCuotas.isNotEmpty) ...[
                  const _SectionTitle(title: 'Próximas cuotas (45 días)'),
                  const SizedBox(height: 12),
                  ...proximasCuotas.map((c) => _ProximaCuotaItem(cuota: Map<String, dynamic>.from(c), tarjetas: tarjetasData)),
                  const SizedBox(height: 24),
                ],

                // --- Ahorros ---
                if (ahorros.isNotEmpty) ...[
                  const _SectionTitle(title: 'Metas de ahorro'),
                  const SizedBox(height: 12),
                  ...ahorros.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ProgresoAhorroBar(bolsillo: BolsilloAhorro.fromMap(Map<String, dynamic>.from(a))),
                  )),
                  const SizedBox(height: 24),
                ],

                // --- Cuentas en mora ---
                if (cuentasMora.isNotEmpty) ...[
                  const _SectionTitle(title: 'Cuentas en mora', color: AppTheme.colorMora),
                  const SizedBox(height: 12),
                  ...cuentasMora.map((c) => _MoraItem(cuenta: Map<String, dynamic>.from(c))),
                ],
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color  color;
  const _SectionTitle({required this.title, this.color = AppTheme.textPrimary});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(width: 4, height: 18, decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16)),
    ],
  );
}

class _WideSummaryCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double total;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  const _WideSummaryCard({
    required this.title,
    this.subtitle,
    required this.total,
    required this.color,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                formatCOP(total),
                style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ProximaCuotaItem extends ConsumerWidget {
  final Map<String, dynamic> cuota;
  final List<dynamic> tarjetas;
  const _ProximaCuotaItem({required this.cuota, required this.tarjetas});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = getTarjetaColor(cuota);
    return InkWell(
      onTap: () {
        final tId = cuota['tarjeta_id'] as int?;
        if (tId != null) {
          final tarjetaIndex = tarjetas.indexWhere((t) => (t as Map<String, dynamic>)['id'] == tId);
          if (tarjetaIndex != -1) {
            final tarjetaObj = TarjetaCredito.fromMap(Map<String, dynamic>.from(tarjetas[tarjetaIndex] as Map));
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TarjetaDetalleScreen(tarjeta: tarjetaObj),
              ),
            ).then((_) => ref.invalidate(dashboardProvider)); // Recargar al volver
          }
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.credit_card_rounded, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cuota['nombre_tarjeta']?.toString() ?? cuota['banco']?.toString() ?? '',
                      style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(cuota['compra_descripcion']?.toString() ?? '',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.event_rounded, size: 12, color: AppTheme.colorAlDia),
                      const SizedBox(width: 4),
                      Text('Vence: ${formatFecha(cuota['fecha_vencimiento']?.toString())}',
                          style: const TextStyle(color: AppTheme.colorAlDia, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatCOP((cuota['valor_cuota'] as num).toDouble()),
                    style: AppTheme.monoStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
                Text('Cuota ${cuota['numero_cuota']}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MoraItem extends StatelessWidget {
  final Map<String, dynamic> cuenta;
  const _MoraItem({required this.cuenta});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color:        AppTheme.bgCard,
      borderRadius: BorderRadius.circular(14),
      border:       Border.all(color: AppTheme.colorMora.withAlpha(80)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.colorMora.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.warning_rounded, color: AppTheme.colorMora, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(cuenta['nombre_deudor']?.toString() ?? '',
              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        Text(formatCOP((cuenta['saldo_pendiente'] as num).toDouble()),
            style: AppTheme.monoStyle(color: AppTheme.colorMora, fontWeight: FontWeight.w700, fontSize: 14)),
      ],
    ),
  );
}

class _ErrorView extends StatelessWidget {
  final String       error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.colorGastos.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded, color: AppTheme.colorGastos, size: 48),
          ),
          const SizedBox(height: 16),
          const Text('No se pudo conectar al servidor',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(error, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon:  const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );
}
