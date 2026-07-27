import 'package:flutter/material.dart';

/// Modelo que representa el puntaje de salud financiera global
/// y los 4 sub-scores que lo componen.
class HealthScore {
  final int score;           // 0–100 global
  final int equilibrioScore; // Ingresos vs egresos
  final int deudaScore;      // Nivel de deuda
  final int liquidezScore;   // Liquidez disponible
  final int ahorroScore;     // Nivel de ahorro

  const HealthScore({
    required this.score,
    required this.equilibrioScore,
    required this.deudaScore,
    required this.liquidezScore,
    required this.ahorroScore,
  });

  /// Etiqueta descriptiva basada en el score global.
  String get label {
    if (score >= 80) return 'EXCELENTE';
    if (score >= 60) return 'BIEN';
    if (score >= 40) return 'CUIDADO';
    return 'ALERTA';
  }

  /// El factor con menor puntaje (el más débil).
  String get weakestFactor {
    final factors = {
      'Equilibrio': equilibrioScore,
      'Deuda': deudaScore,
      'Liquidez': liquidezScore,
      'Ahorro': ahorroScore,
    };
    return factors.entries.reduce((a, b) => a.value < b.value ? a : b).key;
  }

  /// Color según rango del score.
  static Color scoreColor(int score) {
    if (score >= 80) return const Color(0xFF10B981); // Verde
    if (score >= 60) return const Color(0xFFF59E0B); // Ámbar
    if (score >= 40) return const Color(0xFFEF4444); // Rojo
    return const Color(0xFFDC2626);                  // Rojo crítico
  }

  /// Color del sub-score individual.
  static Color subScoreColor(int score) => scoreColor(score);
}

/// Calcula el [HealthScore] a partir del mapa retornado por [dashboardProvider].
HealthScore calculateHealthScore(Map<String, dynamic> data) {
  final cap = data['capacidad_crediticia'] as Map<String, dynamic>;
  final totales = data['totales'] as Map<String, dynamic>;

  final double ingresos    = (cap['ingresos_mes'] as num?)?.toDouble() ?? 0.0;
  final double gastosFijos = (cap['total_gastos_fijos'] as num?)?.toDouble() ?? 0.0;
  final double cuotasTarj  = (cap['cuotas_tarjetas_mes'] as num?)?.toDouble() ?? 0.0;
  final double liquidez    = (cap['liquidez_disponible'] as num?)?.toDouble() ?? 0.0;
  final double pctDeuda    = (cap['porcentaje_endeudamiento'] as num?)?.toDouble() ?? 0.0;
  final double totalAhorros = (totales['total_ahorros'] as num?)?.toDouble() ?? 0.0;
  final double deudaTarjetas = (totales['deuda_tarjetas'] as num?)?.toDouble() ?? 0.0;

  if (ingresos <= 0) {
    return const HealthScore(
      score: 0,
      equilibrioScore: 0,
      deudaScore: 0,
      liquidezScore: 0,
      ahorroScore: 0,
    );
  }

  final double totalEgresos = gastosFijos + cuotasTarj;

  // Sub-scores (0–100)
  final int equilibrioScore = (((ingresos - totalEgresos) / ingresos) * 100)
      .clamp(0.0, 100.0)
      .round();

  final int deudaScore = (100.0 - pctDeuda)
      .clamp(0.0, 100.0)
      .round();

  final int liquidezScore = ((liquidez / ingresos) * 100)
      .clamp(0.0, 100.0)
      .round();

  final double ahorroBase = totalAhorros + deudaTarjetas + 1;
  final int ahorroScore = ((totalAhorros / ahorroBase) * 100)
      .clamp(0.0, 100.0)
      .round();

  // Score global ponderado: deuda(35%) + equilibrio(30%) + liquidez(20%) + ahorro(15%)
  final int globalScore = (
    deudaScore      * 0.35 +
    equilibrioScore * 0.30 +
    liquidezScore   * 0.20 +
    ahorroScore     * 0.15
  ).round();

  return HealthScore(
    score: globalScore,
    equilibrioScore: equilibrioScore,
    deudaScore: deudaScore,
    liquidezScore: liquidezScore,
    ahorroScore: ahorroScore,
  );
}
