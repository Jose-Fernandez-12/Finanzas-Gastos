import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/health_score_calculator.dart';
import '../core/theme.dart';

class HealthScoreCard extends StatefulWidget {
  final HealthScore healthScore;
  final void Function(String factor, int subScore)? onFactorTap;
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

class _HealthScoreCardState extends State<HealthScoreCard> with SingleTickerProviderStateMixin {
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D28D9).withAlpha(60),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Elemento decorativo de fondo (círculo esquina superior derecha)
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(15),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top section: Anillo de puntaje y Textos
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Anillo animado
                    AnimatedBuilder(
                      animation: _animation,
                      builder: (context, _) => SizedBox(
                        width: 75,
                        height: 75,
                        child: CustomPaint(
                          painter: _ScoreRingPainter(
                            progress: _animation.value * hs.score / 100,
                            color: Colors.white,
                            trackColor: Colors.white.withAlpha(40),
                          ),
                          child: Center(
                            child: Text(
                              '${(hs.score * _animation.value).round()}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'SALUD FINANCIERA',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                  color: Colors.white70,
                                ),
                              ),
                              if (widget.onLabTap != null) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: widget.onLabTap,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(30),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.science_rounded, size: 12, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text(
                                          'LAB',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hs.label,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _buildRecommendation(hs),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Separador
                Container(
                  height: 1,
                  color: Colors.white.withAlpha(30),
                ),
                const SizedBox(height: 16),
                // Bottom section: Grid de factores
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _buildGridItem('Equilibrio', hs.equilibrioScore, const Color(0xFF10B981), () => widget.onFactorTap?.call('Equilibrio', hs.equilibrioScore)),
                          const SizedBox(height: 12),
                          _buildGridItem('Liquidez', hs.liquidezScore, const Color(0xFF3B82F6), () => widget.onFactorTap?.call('Liquidez', hs.liquidezScore)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          _buildGridItem('Deuda', hs.deudaScore, const Color(0xFFFBBF24), () => widget.onFactorTap?.call('Deuda', hs.deudaScore)),
                          const SizedBox(height: 12),
                          _buildGridItem('Ahorro', hs.ahorroScore, const Color(0xFFF43F5E), () => widget.onFactorTap?.call('Ahorro', hs.ahorroScore)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(String label, int score, Color dotColor, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            '$score',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
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
        return 'Tus gastos fijos consumen una gran parte de tus ingresos.';
      case 'Deuda':
        return 'Tu nivel de deuda está jalando el score hacia abajo.';
      case 'Liquidez':
        return 'Tu margen de maniobra o liquidez es bajo.';
      case 'Ahorro':
        return 'Tu ahorro está jalando el score hacia abajo.';
      default:
        return 'Mantienes un excelente balance en tus finanzas.';
    }
  }
}

class _ScoreRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  const _ScoreRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 4;
    const strokeWidth = 6.0;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) =>
      old.progress != progress || old.color != color || old.trackColor != trackColor;
}
