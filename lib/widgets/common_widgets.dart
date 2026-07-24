import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/formatters.dart';
import '../models/bolsillo_ahorro.dart';

/// Tarjeta resumen reutilizable para el dashboard (estilo Finanzas Light Impeccable)
class SummaryCard extends StatelessWidget {
  final String  label;
  final double  monto;
  final Color   color;
  final IconData icon;
  final String? subtitulo;
  final VoidCallback? onTap;

  const SummaryCard({
    super.key,
    required this.label,
    required this.monto,
    required this.color,
    required this.icon,
    this.subtitulo,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderLight, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (subtitulo != null) ...[
                  const SizedBox(width: 4),
                  Text(subtitulo!, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatCOP(monto),
                style: AppTheme.monoStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Indicador de capacidad crediticia estilo Finanzas Light Impeccable (con arco semicircular)
class CapacidadCrediticiaCard extends StatelessWidget {
  final double pct;
  final String nivel;
  final double liquidez;

  const CapacidadCrediticiaCard({
    super.key,
    required this.pct,
    required this.nivel,
    required this.liquidez,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.colorPorRiesgo(nivel);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CAPACIDAD CREDITICIA',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              Icon(Icons.info_outline_rounded, color: AppTheme.textMuted, size: 18),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 220,
            height: 110,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                CustomPaint(
                  size: const Size(220, 110),
                  painter: _ArchProgressPainter(
                    progress: (pct / 100).clamp(0.0, 1.0),
                    color: color,
                    bgColor: AppTheme.borderLight,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${pct.round()}%',
                      style: AppTheme.monoStyle(fontSize: 34, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    _RiesgoBadge(nivel: nivel, color: color),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Endeudado: ${pct.toStringAsFixed(1)}%',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              Text(
                'Liquidez: ${formatCOP(liquidez)}',
                style: AppTheme.monoStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArchProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;

  _ArchProgressPainter({required this.progress, required this.color, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 14.0;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height - 10),
      radius: (size.width - strokeWidth) / 2,
    );

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi, math.pi, false, bgPaint);

    final progPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi, math.pi * progress.clamp(0.0, 1.0), false, progPaint);
  }

  @override
  bool shouldRepaint(covariant _ArchProgressPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.bgColor != bgColor;
}

class _RiesgoBadge extends StatelessWidget {
  final String nivel;
  final Color  color;
  const _RiesgoBadge({required this.nivel, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 6),
          Text('Riesgo $nivel', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Fila de cuota en tabla de amortización (Estilo claro)
class CuotaRow extends StatelessWidget {
  final Map<String, dynamic> cuota;
  final bool                 esPagada;
  final VoidCallback?        onPagar;
  final VoidCallback?        onTapCuota;

  const CuotaRow({super.key, required this.cuota, this.esPagada = false, this.onPagar, this.onTapCuota});

  @override
  Widget build(BuildContext context) {
    final estado = cuota['estado'] as String? ?? 'PENDIENTE';
    final color  = estado == 'PAGADA'   ? AppTheme.colorAlDia
                 : estado == 'MORA'     ? AppTheme.colorMora
                 : AppTheme.textPrimary;

    return GestureDetector(
      onTap: onTapCuota,
      child: Container(
        margin:  const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:        AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(
            color: estado == 'MORA' ? AppTheme.colorMora.withAlpha(80) : AppTheme.borderLight,
          ),
        ),
        child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color:        color.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${cuota['numero_cuota']}',
                style: AppTheme.monoStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatFecha(cuota['fecha_vencimiento'].toString()), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text('Cap: ${formatCOP((cuota['valor_capital'] as num).toDouble())}',
                        style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 8),
                    Text('Int: ${formatCOP((cuota['valor_interes'] as num).toDouble())}',
                        style: AppTheme.monoStyle(color: AppTheme.colorDeudas, fontSize: 11, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatCOP((cuota['valor_cuota'] as num).toDouble()),
                  style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
              if (estado == 'PENDIENTE' && onPagar != null)
                GestureDetector(
                  onTap: onPagar,
                  child: Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Pagar', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
              if (estado == 'PAGADA')
                const Icon(Icons.check_circle_rounded, color: AppTheme.colorAlDia, size: 18),
            ],
          ),
        ],
      ),
    ));
  }
}

/// Barra de progreso de ahorro (Estilo claro vibrante)
class ProgresoAhorroBar extends StatelessWidget {
  final BolsilloAhorro bolsillo;

  const ProgresoAhorroBar({super.key, required this.bolsillo});

  @override
  Widget build(BuildContext context) {
    final actual = bolsillo.montoActual;
    final meta   = bolsillo.metaMonto;
    final pct    = meta > 0 ? (actual / meta) * 100 : 0.0;
    final color  = hexToColor(bolsillo.color);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.savings_rounded, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(bolsillo.nombre, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14))),
              Text('${pct.toStringAsFixed(0)}%', style: AppTheme.monoStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:           (pct / 100).clamp(0.0, 1.0),
              minHeight:       8,
              backgroundColor: AppTheme.borderLight,
              valueColor:      AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatCOP(actual), style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
              Text('Meta: ${formatCOP(meta)}', style: AppTheme.monoStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}
