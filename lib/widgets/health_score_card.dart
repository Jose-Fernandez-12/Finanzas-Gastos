import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/health_score_calculator.dart';

/// Tarjeta principal que muestra el índice de salud financiera de Rocky.
/// Incluye un anillo animado, 4 sub-pills interactivos y una recomendación.
class HealthScoreCard extends StatefulWidget {
  final HealthScore healthScore;

  /// Callback disparado al tocar una sub-pill.
  /// Recibe el nombre del factor y su sub-score.
  final void Function(String factor, int subScore)? onFactorTap;

  /// Callback para abrir el laboratorio financiero.
  final VoidCallback? onLabTap;

  const HealthScoreCard({
    super.key,
    required this.healthScore,
    this.onFactorTap,
    this.onLabTap,
  });

  @override
  State<HealthScoreCard> createState() => _HealthScoreCardState();
}

class _HealthScoreCardState extends State<HealthScoreCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(HealthScoreCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.healthScore.score != widget.healthScore.score) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hs = widget.healthScore;
    final color = HealthScore.scoreColor(hs.score);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(20),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SALUD FINANCIERA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppTheme.textMuted,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.onLabTap != null)
                    GestureDetector(
                      onTap: widget.onLabTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.science_rounded, size: 13, color: AppTheme.primary),
                            SizedBox(width: 4),
                            Text(
                              'LAB',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primary, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      hs.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Anillo + sub-pills en fila
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Anillo animado
              AnimatedBuilder(
                animation: _animation,
                builder: (context, _) => SizedBox(
                  width: 110,
                  height: 110,
                  child: CustomPaint(
                    painter: _ScoreRingPainter(
                      progress: _animation.value * hs.score / 100,
                      color: color,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(hs.score * _animation.value).round()}',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: color,
                              height: 1,
                            ),
                          ),
                          const Text(
                            '/100',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // 4 sub-pills en columna (2 filas de 2)
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SubScorePill(
                            label: 'Equilibrio',
                            score: hs.equilibrioScore,
                            icon: Icons.balance_rounded,
                            onTap: () => widget.onFactorTap?.call('Equilibrio', hs.equilibrioScore),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SubScorePill(
                            label: 'Deuda',
                            score: hs.deudaScore,
                            icon: Icons.credit_card_rounded,
                            onTap: () => widget.onFactorTap?.call('Deuda', hs.deudaScore),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _SubScorePill(
                            label: 'Liquidez',
                            score: hs.liquidezScore,
                            icon: Icons.account_balance_wallet_rounded,
                            onTap: () => widget.onFactorTap?.call('Liquidez', hs.liquidezScore),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SubScorePill(
                            label: 'Ahorro',
                            score: hs.ahorroScore,
                            icon: Icons.savings_rounded,
                            onTap: () => widget.onFactorTap?.call('Ahorro', hs.ahorroScore),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Recomendación
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded,
                    color: color, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _buildRecommendation(hs),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4B5563),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildRecommendation(HealthScore hs) {
    final factor = hs.weakestFactor;
    switch (factor) {
      case 'Equilibrio':
        return 'Tus gastos fijos consumen una parte alta de tus ingresos. Toca "Equilibrio" para más detalles.';
      case 'Deuda':
        return 'Tu nivel de deuda está afectando tu puntaje. Toca "Deuda" para ver qué recomienda Rocky.';
      case 'Liquidez':
        return 'Tu margen de maniobra es bajo. Toca "Liquidez" para entender el impacto.';
      case 'Ahorro':
        return 'Mejorar tu ahorro subiría el puntaje. Toca "Ahorro" para que Rocky te explique cómo.';
      default:
        return 'Todo se ve bien. Toca cualquier factor para que Rocky lo analice en detalle.';
    }
  }
}

// ---------------------------------------------------------------------------
// Painter del anillo de progreso
// ---------------------------------------------------------------------------
class _ScoreRingPainter extends CustomPainter {
  final double progress; // 0.0 – 1.0
  final Color color;

  const _ScoreRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;
    const strokeWidth = 10.0;

    // Track (fondo)
    final trackPaint = Paint()
      ..color = const Color(0xFFF3F4F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Arco de progreso
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,                // Inicia arriba
      2 * math.pi * progress,      // Ángulo según progreso
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) =>
      old.progress != progress || old.color != color;
}

// ---------------------------------------------------------------------------
// Sub-pill individual (tappable)
// ---------------------------------------------------------------------------
class _SubScorePill extends StatelessWidget {
  final String label;
  final int score;
  final IconData icon;
  final VoidCallback? onTap;

  const _SubScorePill({
    required this.label,
    required this.score,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = HealthScore.subScoreColor(score);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 11, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            // 5 puntitos de progreso
            Row(
              children: List.generate(5, (i) {
                final filled = i < (score / 20).round();
                return Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? color : color.withAlpha(40),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 2),
            Text(
              '$score',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
