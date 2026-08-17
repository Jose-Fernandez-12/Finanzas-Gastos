import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/logros_provider.dart';


class TrofeosScreen extends ConsumerWidget {
  const TrofeosScreen({super.key});

  static const Map<String, IconData> _iconMap = {
    'flag': Icons.flag_rounded,
    'favorite': Icons.favorite_rounded,
    'stars': Icons.stars_rounded,
    'verified': Icons.verified_rounded,
    'savings': Icons.savings_rounded,
    'account_balance': Icons.account_balance_rounded,
    'workspace_premium': Icons.workspace_premium_rounded,
    'lock_open': Icons.lock_open_rounded,
    'water_drop': Icons.water_drop_rounded,
    'credit_score': Icons.credit_score_rounded,
    'emoji_events': Icons.emoji_events_rounded,
    'verified_user': Icons.verified_user_rounded,
    'folder_special': Icons.folder_special_rounded,
    'military_tech': Icons.military_tech_rounded,
    'credit_card': Icons.credit_card_rounded,
  };

  static const Map<String, Color> _categoryColors = {
    'basico': AppTheme.primary,
    'salud': AppTheme.success,
    'deuda': AppTheme.danger,
    'ahorro': AppTheme.warn,
    'liquidez': AppTheme.colorAhorros,
    'general': AppTheme.primaryDark,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logrosAsync = ref.watch(logrosProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: const Text('Trofeos y Misiones'),
        backgroundColor: AppTheme.bgCard,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: logrosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (logros) {
          final completados = logros.where((l) => l.completado).toList();
          final pendientes = logros.where((l) => !l.completado).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header con resumen
              _buildHeader(completados.length, logros.length),
              const SizedBox(height: 24),

              // Completados
              if (completados.isNotEmpty) ...[
                _sectionTitle('COMPLETADOS', completados.length),
                const SizedBox(height: 12),
                ...completados.map((l) => _LogroCard(
                  logro: l,
                  iconMap: _iconMap,
                  categoryColors: _categoryColors,
                  onTap: () => _onLogroTap(ref, l),
                )),
                const SizedBox(height: 24),
              ],

              // Pendientes
              if (pendientes.isNotEmpty) ...[
                _sectionTitle('EN PROGRESO', pendientes.length),
                const SizedBox(height: 12),
                ...pendientes.map((l) => _LogroCard(
                  logro: l,
                  iconMap: _iconMap,
                  categoryColors: _categoryColors,
                  onTap: () => _onLogroTap(ref, l),
                )),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(int completados, int total) {
    final pct = total > 0 ? completados / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withAlpha(60),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: CustomPaint(
              painter: _TrophyRingPainter(progress: pct),
              child: Center(
                child: Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white.withAlpha(230),
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$completados de $total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  completados == total
                      ? '¡Has completado todas las misiones!'
                      : 'Sigue avanzando para desbloquear más logros',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.bgCardWarm,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary),
          ),
        ),
      ],
    );
  }

  void _onLogroTap(WidgetRef ref, LogroEstado logro) {
    // Rocky desactivado
  }
}

// ---------------------------------------------------------------------------
// Card individual de logro
// ---------------------------------------------------------------------------
class _LogroCard extends StatelessWidget {
  final LogroEstado logro;
  final Map<String, IconData> iconMap;
  final Map<String, Color> categoryColors;
  final VoidCallback onTap;

  const _LogroCard({
    required this.logro,
    required this.iconMap,
    required this.categoryColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = categoryColors[logro.categoria] ?? AppTheme.primary;
    final icon = iconMap[logro.icono] ?? Icons.emoji_events_rounded;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: logro.completado ? color.withAlpha(80) : AppTheme.borderSoft,
          ),
          boxShadow: [
            if (logro.completado)
              BoxShadow(
                color: color.withAlpha(15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            // Medallón
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: logro.completado ? color.withAlpha(25) : const Color(0xFFF3F4F6),
                border: Border.all(
                  color: logro.completado ? color : const Color(0xFFE5E7EB),
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                color: logro.completado ? color : const Color(0xFFD1D5DB),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    logro.titulo,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: logro.completado ? AppTheme.textPrimary : const Color(0xFF9CA3AF),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    logro.descripcion,
                    style: TextStyle(
                      fontSize: 11,
                      color: logro.completado ? const Color(0xFF6B7280) : const Color(0xFFD1D5DB),
                    ),
                  ),
                  if (!logro.completado) ...[
                    const SizedBox(height: 8),
                    // Barra de progreso
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: logro.porcentaje,
                        backgroundColor: const Color(0xFFF3F4F6),
                        valueColor: AlwaysStoppedAnimation(color.withAlpha(150)),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Check o porcentaje
            if (logro.completado)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
              )
            else
              Text(
                '${(logro.porcentaje * 100).round()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color.withAlpha(160),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painter del anillo del header
// ---------------------------------------------------------------------------
class _TrophyRingPainter extends CustomPainter {
  final double progress;
  const _TrophyRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 5;

    final bgPaint = Paint()
      ..color = Colors.white.withAlpha(40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_TrophyRingPainter old) => old.progress != progress;
}
