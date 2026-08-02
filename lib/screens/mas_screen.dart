import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../core/theme.dart';
import '../core/formatters.dart';
import '../providers/suscripciones_provider.dart';
import '../providers/logros_provider.dart';
import '../providers/analytics_provider.dart';
import '../models/suscripcion.dart';
import 'analytics_screen.dart';

import 'trofeos_screen.dart';
import 'suscripciones_screen.dart';
import 'simulador_financiero_screen.dart';
import 'reporte_detallado_screen.dart' show ReporteDetalladoView;
import 'settings_screen.dart';

/// Pantalla "Mas": Analitica (preview) + Suscripciones + Logros + Herramientas
class MasScreen extends ConsumerWidget {
  const MasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suscripcionesAsync = ref.watch(suscripcionesProvider);
    final logrosAsync        = ref.watch(logrosProvider);
    final analyticsAsync     = ref.watch(analyticsProvider(0.0));

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      body: CustomScrollView(
        slivers: [
          // ── Header ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: _MasHeader(),
          ),

          // ── Preview Analitica ───────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: analyticsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (analytics) => _AnalyticaPreview(
                  analytics: analytics,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                  ),
                ),
              ),
            ),
          ),

          // ── Suscripciones ───────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Suscripciones',
              actionLabel: 'Ver todas',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SuscripcionesScreen()),
              ).then((_) => ref.invalidate(suscripcionesProvider)),
            ),
          ),
          SliverToBoxAdapter(
            child: suscripcionesAsync.when(
              loading: () => const SizedBox(
                height: 60,
                child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (subs) {
                final activas = subs.where((s) => s.activa == 1).toList();
                return _SuscripcionesSection(suscripciones: activas);
              },
            ),
          ),

          // ── Logros ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Logros',
              actionLabel: 'Ver todos',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TrofeosScreen()),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: logrosAsync.when(
              loading: () => const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (logros) {
                final completados = logros.where((l) => l.completado).length;
                final total = logros.length;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _TrofeoHeroCard(
                    completados: completados,
                    total: total,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TrofeosScreen()),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Herramientas ────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: 'Herramientas',
              actionLabel: null,
              onAction: null,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _MenuList(
                items: [
                  _MenuItem(
                    icon: Icons.psychology_rounded,
                    iconBg: const Color(0xFFEDE9FE),
                    iconColor: AppTheme.primary,
                    title: 'Simulador de Pagos',
                    desc: 'Avalancha o Bola de Nieve',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SimuladorFinancieroScreen()),
                    ),
                  ),
                  _MenuItem(
                    icon: Icons.picture_as_pdf_rounded,
                    iconBg: const Color(0xFFD1FAE5),
                    iconColor: AppTheme.success,
                    title: 'Reporte Detallado',
                    desc: 'Descargar PDF completo',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReporteDetalladoView()),
                    ),
                  ),
                  _MenuItem(
                    icon: Icons.settings_rounded,
                    iconBg: const Color(0xFFFEF3C7),
                    iconColor: AppTheme.warn,
                    title: 'Configuración',
                    desc: 'Perfil, datos, preferencias',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────

class _MasHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      child: const Text(
        'Más',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}

// ── Analitica Preview ─────────────────────────────────────────────────────

class _AnalyticaPreview extends StatelessWidget {
  final Map<String, dynamic> analytics;
  final VoidCallback onTap;
  const _AnalyticaPreview({required this.analytics, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final termometro = analytics['termometro'] as Map<String, dynamic>? ?? {};
    final eficiencia = analytics['eficiencia_ahorro'] as Map<String, dynamic>? ?? {};
    final esclavitud = analytics['esclavitud_financiera'] as Map<String, dynamic>? ?? {};

    final liquidez = (termometro['plata_libre'] as num?)?.toDouble() ?? 0.0;
    final endeudamiento = (esclavitud['tasa_esclavitud'] as num?)?.toDouble() ?? 0.0;
    final tasaAhorro = (eficiencia['tasa_ahorro'] as num?)?.toDouble() ?? 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.borderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Resumen Analítica',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Liquidez',
                    value: formatCOP(liquidez),
                    color: AppTheme.success,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStat(
                    label: 'Endeudamiento',
                    value: '${endeudamiento.toStringAsFixed(1)}%',
                    color: endeudamiento > 40 ? AppTheme.danger : AppTheme.warn,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStat(
                    label: 'Ahorro',
                    value: '${tasaAhorro.toStringAsFixed(1)}%',
                    color: tasaAhorro > 20 ? AppTheme.success : AppTheme.danger,
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

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.bgCardWarm,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              value,
              style: AppTheme.monoStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Suscripciones ─────────────────────────────────────────────────────────

class _SuscripcionesSection extends StatelessWidget {
  final List<Suscripcion> suscripciones;
  const _SuscripcionesSection({required this.suscripciones});

  @override
  Widget build(BuildContext context) {
    if (suscripciones.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgCardWarm,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderSoft),
          ),
          child: const Text(
            'Sin suscripciones activas. Añade una desde "+"',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
        ),
      );
    }

    final totalMensual = suscripciones.fold<double>(0, (s, sub) => s + sub.monto);
    final preview = suscripciones.take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Resumen total
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderSoft),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.success.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.subscriptions_rounded, color: AppTheme.success, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Gasto mensual', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    Text(
                      formatCOP(totalMensual),
                      style: AppTheme.monoStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Lista preview
          ...preview.map((s) => _SubItem(sub: s)),
        ],
      ),
    );
  }
}

class _SubItem extends StatelessWidget {
  final Suscripcion sub;
  const _SubItem({required this.sub});

  Color _parseColor() {
    try {
      final hex = sub.color.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor();
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
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
            child: Center(
              child: Text(
                sub.inicial,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub.nombre,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${sub.frecuencia} · Día ${sub.diaCobro}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          Text(
            formatCOP(sub.monto),
            style: AppTheme.monoStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Trofeo Hero Card ─────────────────────────────────────────────────────

class _TrofeoHeroCard extends StatelessWidget {
  final int completados;
  final int total;
  final VoidCallback onTap;

  const _TrofeoHeroCard({
    required this.completados,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? completados / total : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppTheme.heroGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          children: [
            // Ring SVG simulado con CustomPaint
            SizedBox(
              width: 60,
              height: 60,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(60, 60),
                    painter: _RingPainter(pct: pct),
                  ),
                  Text(
                    '$completados',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
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
                  Text(
                    '$completados de $total logros',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sigue avanzando para desbloquear más',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double pct;
  const _RingPainter({required this.pct});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 4;
    final track = Paint()
      ..color = Colors.white.withAlpha(50)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(cx, cy), r, track);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi / 2,
      2 * math.pi * pct,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.pct != pct;
}

// ── Menu ──────────────────────────────────────────────────────────────────

class _MenuList extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSoft),
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          return Column(
            children: [
              _MenuRow(item: items[i]),
              if (i < items.length - 1)
                const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          );
        }),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final _MenuItem item;
  const _MenuRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.iconBg,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(item.icon, color: item.iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    item.desc,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

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

// ── Data classes ──────────────────────────────────────────────────────────

class _MenuItem {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String desc;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.desc,
    required this.onTap,
  });
}
