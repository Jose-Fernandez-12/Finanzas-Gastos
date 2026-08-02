import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/formatters.dart';
import '../core/health_score_calculator.dart';
import '../providers/dashboard_provider.dart';
import '../providers/virtual_assistant_provider.dart';
import '../widgets/health_score_card.dart';
import 'tarjetas/tarjeta_detalle_screen.dart';
import 'simulador_financiero_screen.dart';
import '../models/tarjeta_credito.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final Function(int)? onNavigate;
  const DashboardScreen({super.key, this.onNavigate});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final DateTime _startupTime = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      body: dashboardAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (err, _) => _ErrorView(
          error: err.toString(),
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
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

          final proximasCuotas = data['proximas_cuotas'] as List<dynamic>;
          final cuentasMora = data['cuentas_en_mora'] as List<dynamic>;
          final tarjetasData = data['tarjetas'] as List<dynamic>;
          final ahorros = data['ahorros'] as List<dynamic>;

          final HealthScore healthScore = data['health_score'] as HealthScore;

          // Anunciar health score a Rocky en startup
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final assistant = ref.read(virtualAssistantProvider.notifier);
            if (!ref.read(virtualAssistantProvider).isAction &&
                DateTime.now().difference(_startupTime).inSeconds >= 12) {
              assistant.announceHealthScore(healthScore.score, healthScore.weakestFactor);
            }
          });

          // Gastos del mes = gastos fijos + cuotas
          final gastosDelMes = gastosFijos + cuotasTarj;
          // Porcentaje de gasto libre restante
          final pctGastado = ingresos > 0 ? ((gastosDelMes / ingresos)).clamp(0.0, 1.0) : 0.0;

          // Plata libre de culpa diaria
          final ahora = DateTime.now();
          final diasRestantes = DateUtils.getDaysInMonth(ahora.year, ahora.month) - ahora.day + 1;
          final plataDiaria = diasRestantes > 0 ? liquidez / diasRestantes : 0.0;

          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async => ref.invalidate(dashboardProvider),
            child: CustomScrollView(
              slivers: [
                // ── Header ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _Header(
                    onRefresh: () => ref.invalidate(dashboardProvider),
                  ),
                ),

                // ── Health Score Hero ───────────────────────────────
                if (ingresos > 0)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: HealthScoreCard(
                        healthScore: healthScore,
                        onFactorTap: (factor, subScore) {
                          ref.read(virtualAssistantProvider.notifier)
                              .analyzeHealthFactor(factor, subScore);
                        },
                        onLabTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SimuladorFinancieroScreen(),
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Stats rapidos ───────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Ingresos',
                            value: formatCOP(ingresos),
                            color: AppTheme.success,
                            icon: Icons.trending_up_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Gastos',
                            value: formatCOP(gastosDelMes),
                            color: AppTheme.danger,
                            icon: Icons.trending_down_rounded,
                            isNegative: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Plata libre de culpa ────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _PlataLibreCard(
                      plataDiaria: plataDiaria,
                      gastado: gastosDelMes,
                      libre: liquidez,
                      pctGastado: pctGastado,
                    ),
                  ),
                ),

                // ── Capacidad crediticia mini ───────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _CreditMiniCard(
                      pct: pctEndeudamiento,
                      nivel: nivelRiesgo,
                      liquidez: liquidez,
                      cuentasCobrar: totalCuentasCobrar,
                      ahorros: totalAhorros,
                    ),
                  ),
                ),

                // ── Alertas de mora ─────────────────────────────────
                if (cuentasMora.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _MoraAlertBanner(cuentas: cuentasMora),
                    ),
                  ),

                // ── Proximos pagos ──────────────────────────────────
                if (proximasCuotas.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      title: 'Próximos pagos',
                      actionLabel: 'Ver finanzas',
                      onAction: () => widget.onNavigate?.call(2),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _ProximaCuotaItem(
                          cuota: Map<String, dynamic>.from(proximasCuotas[i]),
                          tarjetas: tarjetasData,
                        ),
                      ),
                      childCount: proximasCuotas.length,
                    ),
                  ),
                ],

                // ── Metas de ahorro (preview) ───────────────────────
                if (ahorros.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      title: 'Metas de ahorro',
                      actionLabel: 'Ver todas',
                      onAction: () => widget.onNavigate?.call(2),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final a = Map<String, dynamic>.from(ahorros[i]);
                        final meta = (a['monto_meta'] as num?)?.toDouble() ?? 1.0;
                        final actual = (a['monto_actual'] as num?)?.toDouble() ?? 0.0;
                        final pct = (actual / meta).clamp(0.0, 1.0);
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: _MetaAhorroRow(
                            nombre: a['nombre']?.toString() ?? '',
                            actual: actual,
                            meta: meta,
                            pct: pct,
                          ),
                        );
                      },
                      childCount: ahorros.length,
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onRefresh;
  const _Header({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hora = now.hour;
    String saludo;
    if (hora < 12) saludo = 'Buenos días';
    else if (hora < 18) saludo = 'Buenas tardes';
    else saludo = 'Buenas noches';

    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              gradient: AppTheme.heroGradient,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'MF',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Saludo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  saludo,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Text(
                  'Mis Finanzas',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          // Refresh
          _IconBtn(
            icon: Icons.refresh_rounded,
            onTap: onRefresh,
          ),
        ],
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool isNegative;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.isNegative = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              isNegative ? '-$value' : value,
              style: AppTheme.monoStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Plata libre de culpa ───────────────────────────────────────────────────

class _PlataLibreCard extends StatelessWidget {
  final double plataDiaria;
  final double gastado;
  final double libre;
  final double pctGastado;

  const _PlataLibreCard({
    required this.plataDiaria,
    required this.gastado,
    required this.libre,
    required this.pctGastado,
  });

  @override
  Widget build(BuildContext context) {
    final isHealthy = pctGastado < 0.7;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 16, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              const Text(
                'Plata libre de culpa',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isHealthy
                      ? AppTheme.success.withAlpha(25)
                      : AppTheme.warn.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Text(
                  isHealthy ? 'SANO' : 'AJUSTADO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isHealthy ? AppTheme.success : AppTheme.warn,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatCOP(plataDiaria),
            style: AppTheme.monoStyle(
              color: AppTheme.primary,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'presupuesto diario seguro hasta fin de mes',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 14),
          // Barra de progreso
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pctGastado,
              minHeight: 6,
              backgroundColor: AppTheme.borderSoft,
              valueColor: AlwaysStoppedAnimation<Color>(
                isHealthy ? AppTheme.primary : AppTheme.warn,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Gastado ${formatCOP(gastado)}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              Text(
                'Libre ${formatCOP(libre)}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Capacidad crediticia mini ─────────────────────────────────────────────

class _CreditMiniCard extends StatelessWidget {
  final double pct;
  final String nivel;
  final double liquidez;
  final double cuentasCobrar;
  final double ahorros;

  const _CreditMiniCard({
    required this.pct,
    required this.nivel,
    required this.liquidez,
    required this.cuentasCobrar,
    required this.ahorros,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.colorPorRiesgo(nivel);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSoft),
      ),
      child: Row(
        children: [
          // Gauge semicircular
          SizedBox(
            width: 64,
            height: 36,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                CustomPaint(
                  size: const Size(64, 36),
                  painter: _GaugePainter(pct: pct / 100, color: color),
                ),
                Text(
                  '${pct.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Capacidad Crediticia',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Riesgo $nivel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Liquidez
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Liquidez', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              FittedBox(
                child: Text(
                  formatCOP(liquidez),
                  style: AppTheme.monoStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double pct;
  final Color color;
  const _GaugePainter({required this.pct, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height;
    final r = size.width / 2 - 3;
    final trackPaint = Paint()
      ..color = AppTheme.borderSoft
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = color
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -3.14159,
      3.14159,
      false,
      trackPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -3.14159,
      3.14159 * pct,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.pct != pct;
}

// ── Mora Alert ───────────────────────────────────────────────────────────

class _MoraAlertBanner extends StatelessWidget {
  final List<dynamic> cuentas;
  const _MoraAlertBanner({required this.cuentas});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.danger.withAlpha(12),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.danger.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 18),
              SizedBox(width: 8),
              Text(
                'CUENTAS EN MORA',
                style: TextStyle(
                  color: AppTheme.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...cuentas.map((c) {
            final cuenta = Map<String, dynamic>.from(c);
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      cuenta['nombre_deudor']?.toString() ?? '',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    formatCOP((cuenta['saldo_pendiente'] as num).toDouble()),
                    style: AppTheme.monoStyle(
                      color: AppTheme.danger,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Section Header ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Proxima Cuota Item ───────────────────────────────────────────────────

class _ProximaCuotaItem extends ConsumerWidget {
  final Map<String, dynamic> cuota;
  final List<dynamic> tarjetas;
  const _ProximaCuotaItem({required this.cuota, required this.tarjetas});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = getTarjetaColor(cuota);
    final fechaStr = cuota['fecha_vencimiento']?.toString() ?? '';
    final esHoy = fechaStr.startsWith(
      DateTime.now().toIso8601String().substring(0, 10),
    );

    return GestureDetector(
      onTap: () {
        final tId = cuota['tarjeta_id'] as int?;
        if (tId != null) {
          final idx = tarjetas.indexWhere(
            (t) => (t as Map<String, dynamic>)['id'] == tId,
          );
          if (idx != -1) {
            final tarjetaObj = TarjetaCredito.fromMap(
              Map<String, dynamic>.from(tarjetas[idx] as Map),
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TarjetaDetalleScreen(tarjeta: tarjetaObj),
              ),
            ).then((_) => ref.invalidate(dashboardProvider));
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderSoft),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.credit_card_rounded, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cuota['nombre_tarjeta']?.toString() ?? cuota['banco']?.toString() ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    cuota['compra_descripcion']?.toString() ?? '',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatCOP((cuota['valor_cuota'] as num).toDouble()),
                  style: AppTheme.monoStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  esHoy ? 'Hoy' : formatFecha(fechaStr),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: esHoy ? AppTheme.danger : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Meta Ahorro Row ───────────────────────────────────────────────────────

class _MetaAhorroRow extends StatelessWidget {
  final String nombre;
  final double actual;
  final double meta;
  final double pct;

  const _MetaAhorroRow({
    required this.nombre,
    required this.actual,
    required this.meta,
    required this.pct,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                nombre,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: AppTheme.borderSoft,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${formatCOP(actual)} / ${formatCOP(meta)}',
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Icon Button ───────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Icon(icon, size: 18, color: AppTheme.textSecondary),
      ),
    );
  }
}

// ── Error View ────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.danger.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, color: AppTheme.danger, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'No se pudo conectar al servidor',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
