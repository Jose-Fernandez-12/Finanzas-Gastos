import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/formatters.dart';
import '../providers/app_providers.dart';
import '../widgets/common_widgets.dart';
import 'tarjetas_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';


class DashboardScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  const DashboardScreen({super.key, this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().cargar();
    });
  }

  @override
  Widget build(BuildContext context) {
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
            onPressed: () => context.read<DashboardProvider>().cargar(),
          ),
        ],
      ),
      body: Consumer<DashboardProvider>(
        builder: (context, provider, _) {
          if (provider.loading) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          if (provider.error != null) {
            return _ErrorView(error: provider.error!, onRetry: provider.cargar);
          }
          return RefreshIndicator(
            color:    AppTheme.primary,
            onRefresh: provider.cargar,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // --- Capacidad Crediticia ---
                CapacidadCrediticiaCard(
                  pct:     provider.pctEndeudamiento,
                  nivel:   provider.nivelRiesgo,
                  liquidez: provider.liquidez,
                ),
                const SizedBox(height: 16),

                // --- Resumen de 4 cuadros principales ---
                GridView.count(
                  crossAxisCount:    2,
                  crossAxisSpacing:  12,
                  mainAxisSpacing:   12,
                  childAspectRatio:  MediaQuery.of(context).size.width < 400 ? 1.35 : 1.55,
                  shrinkWrap:        true,
                  physics:           const NeverScrollableScrollPhysics(),
                  children: [
                    SummaryCard(
                      label: 'Liquidez',
                      monto: provider.liquidez,
                      color: AppTheme.secondary,
                      icon:  Icons.account_balance_wallet_rounded,
                      onTap: null,
                    ),
                    SummaryCard(
                      label: 'Ingresos (Mes)',
                      monto: provider.ingresos,
                      color: AppTheme.colorIngresos,
                      icon:  Icons.trending_up_rounded,
                      onTap: () => widget.onNavigate?.call(1),
                    ),
                    SummaryCard(
                      label: 'Gastos Fijos',
                      monto: provider.gastosFijos,
                      color: AppTheme.colorGastos,
                      icon:  Icons.trending_down_rounded,
                      onTap: () => widget.onNavigate?.call(2),
                    ),
                    SummaryCard(
                      label: 'Cuotas TdC',
                      monto: provider.cuotasTarj,
                      color: AppTheme.colorDeudas,
                      icon:  Icons.credit_card_rounded,
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
                  total: provider.liquidez,
                  color: AppTheme.secondary,
                  icon: Icons.savings_outlined,
                ),
                const SizedBox(height: 10),
                _WideSummaryCard(
                  title: 'Cuentas por cobrar',
                  subtitle: 'Deudores activos',
                  total: provider.totalCuentasCobrar,
                  color: AppTheme.primary,
                  icon: Icons.people_rounded,
                  onTap: () => widget.onNavigate?.call(5),
                ),
                const SizedBox(height: 10),
                if (provider.totalAhorros > 0) ...[
                  _WideSummaryCard(
                    title: 'Total ahorros',
                    subtitle: 'Fondo de emergencia',
                    total: provider.totalAhorros,
                    color: AppTheme.colorAhorros,
                    icon: Icons.savings_rounded,
                    onTap: () => widget.onNavigate?.call(4),
                  ),
                  const SizedBox(height: 10),
                ],
                if (provider.totalDeudaTarjetas > 0) ...[
                  _WideSummaryCard(
                    title: 'Deuda activa en tarjetas',
                    subtitle: 'Saldo total adeudado',
                    total: provider.totalDeudaTarjetas,
                    color: AppTheme.colorDeudas,
                    icon: Icons.credit_card_rounded,
                  ),
                  const SizedBox(height: 24),
                ],

                // --- Proximas cuotas a vencer ---
                if (provider.proximasCuotas.isNotEmpty) ...[
                  const _SectionTitle(title: 'Próximas cuotas (45 días)'),
                  const SizedBox(height: 12),
                  ...provider.proximasCuotas.map((c) => _ProximaCuotaItem(cuota: c)),
                  const SizedBox(height: 24),
                ],

                // --- Ahorros ---
                if (provider.ahorros.isNotEmpty) ...[
                  const _SectionTitle(title: 'Metas de ahorro'),
                  const SizedBox(height: 12),
                  ...provider.ahorros.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ProgresoAhorroBar(bolsillo: a),
                  )),
                  const SizedBox(height: 24),
                ],

                // --- Cuentas en mora ---
                if (provider.cuentasMora.isNotEmpty) ...[
                  const _SectionTitle(title: 'Cuentas en mora', color: AppTheme.colorMora),
                  const SizedBox(height: 12),
                  ...provider.cuentasMora.map((c) => _MoraItem(cuenta: c)),
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

class _ProximaCuotaItem extends StatelessWidget {
  final Map<String, dynamic> cuota;
  const _ProximaCuotaItem({required this.cuota});

  @override
  Widget build(BuildContext context) {
    final color = getTarjetaColor(cuota);
    return InkWell(
      onTap: () {
        final tId = cuota['tarjeta_id'] as int?;
        if (tId != null) {
          final prov = context.read<DashboardProvider>();
          final tarjetaIndex = prov.tarjetas.indexWhere((t) => t['id'] == tId);
          if (tarjetaIndex != -1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TarjetaDetalleScreen(tarjeta: prov.tarjetas[tarjetaIndex]),
              ),
            ).then((_) => prov.cargar()); // Recargar al volver
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
