import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/formatters.dart';
import '../core/health_score_calculator.dart';
import '../providers/dashboard_provider.dart';
import '../providers/virtual_assistant_provider.dart';

class SimuladorFinancieroScreen extends ConsumerStatefulWidget {
  const SimuladorFinancieroScreen({super.key});

  @override
  ConsumerState<SimuladorFinancieroScreen> createState() => _SimuladorFinancieroScreenState();
}

class _SimuladorFinancieroScreenState extends ConsumerState<SimuladorFinancieroScreen> {
  double _montoCredito = 0;
  double _tasaInteres = 2.0; // % mensual
  int _plazoMeses = 12;
  bool _haSimulado = false;

  HealthScore? _scoreActual;
  HealthScore? _scoreSimulado;
  double _pctActual = 0;
  double _pctSimulado = 0;
  double _cuotaMensualSimulada = 0;

  @override
  Widget build(BuildContext context) {
    final dashAsync = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: const Text('Laboratorio Financiero'),
        backgroundColor: AppTheme.bgCard,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: dashAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (response) {
          final data = response['data'] as Map<String, dynamic>;
          return _buildBody(data);
        },
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> data) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Intro
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.science_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Simula antes de decidir',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ingresa los datos de un posible crédito o compra y mira cómo afectaría tus finanzas.',
                      style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // --- Monto ---
        _sectionLabel('MONTO DEL CRÉDITO / COMPRA'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              Text(
                formatCOP(_montoCredito),
                style: AppTheme.monoStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 12),
              Slider(
                value: _montoCredito,
                min: 0,
                max: 50000000,
                divisions: 500,
                activeColor: AppTheme.primary,
                label: formatCOP(_montoCredito),
                onChanged: (v) => setState(() {
                  _montoCredito = v;
                  _haSimulado = false;
                }),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('\$0', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                  Text('\$50M', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // --- Tasa y Plazo ---
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('TASA MENSUAL'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDecoration(),
                    child: Column(
                      children: [
                        Text(
                          '${_tasaInteres.toStringAsFixed(1)}%',
                          style: AppTheme.monoStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                        ),
                        Slider(
                          value: _tasaInteres,
                          min: 0,
                          max: 5,
                          divisions: 50,
                          activeColor: const Color(0xFFF59E0B),
                          onChanged: (v) => setState(() {
                            _tasaInteres = v;
                            _haSimulado = false;
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('PLAZO (MESES)'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDecoration(),
                    child: Column(
                      children: [
                        Text(
                          '$_plazoMeses',
                          style: AppTheme.monoStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                        ),
                        Slider(
                          value: _plazoMeses.toDouble(),
                          min: 1,
                          max: 60,
                          divisions: 59,
                          activeColor: const Color(0xFF10B981),
                          onChanged: (v) => setState(() {
                            _plazoMeses = v.round();
                            _haSimulado = false;
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // --- Botón simular ---
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _montoCredito > 0 ? () => _simular(ref) : null,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('SIMULAR IMPACTO', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 3,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // --- Resultados ---
        if (_haSimulado && _scoreActual != null && _scoreSimulado != null) ...[
          _sectionLabel('RESULTADO DE LA SIMULACIÓN'),
          const SizedBox(height: 12),
          _buildResultCard(),
          const SizedBox(height: 16),
          _buildComparisonRow('Health Score', _scoreActual!.score.toDouble(), _scoreSimulado!.score.toDouble(), suffix: '/100'),
          const SizedBox(height: 8),
          _buildComparisonRow('Endeudamiento', _pctActual, _pctSimulado, suffix: '%'),
          const SizedBox(height: 8),
          _buildComparisonRow('Cuota nueva', 0, _cuotaMensualSimulada, suffix: '', isCurrency: true),
          const SizedBox(height: 60),
        ],
      ],
    );
  }

  void _simular(WidgetRef ref) {
    final dashData = ref.read(dashboardProvider).value;
    if (dashData == null) return;

    final data = dashData['data'] as Map<String, dynamic>;
    final cap = data['capacidad_crediticia'] as Map<String, dynamic>;
    final ingresos = (cap['ingresos_mes'] as num).toDouble();
    final gastosFijos = (cap['total_gastos_fijos'] as num).toDouble();
    final cuotasTarj = (cap['cuotas_tarjetas_mes'] as num).toDouble();
    final pctEndeudamiento = (cap['porcentaje_endeudamiento'] as num).toDouble();

    final totales = data['totales'] as Map<String, dynamic>;
    final deudaTarjetas = (totales['deuda_tarjetas'] as num).toDouble();
    final totalAhorros = (totales['total_ahorros'] as num).toDouble();

    // Calcular cuota mensual del nuevo crédito (fórmula de amortización francesa)
    final tasaMensual = _tasaInteres / 100;
    double cuotaMensual;
    if (tasaMensual > 0) {
      cuotaMensual = _montoCredito * (tasaMensual * math.pow(1 + tasaMensual, _plazoMeses)) /
          (math.pow(1 + tasaMensual, _plazoMeses) - 1);
    } else {
      cuotaMensual = _montoCredito / _plazoMeses;
    }

    // Score actual
    _scoreActual = calculateHealthScore(data);
    _pctActual = pctEndeudamiento;

    // Datos simulados: sumar la nueva deuda y la nueva cuota
    final newCuotasTarj = cuotasTarj + cuotaMensual;
    final newDeudaTarjetas = deudaTarjetas + _montoCredito;
    final newLiquidez = ingresos - gastosFijos - newCuotasTarj;
    final newPctEndeudamiento = ingresos > 0 ? ((gastosFijos + newCuotasTarj) / ingresos * 100) : 0.0;

    final dataSimulado = {
      'capacidad_crediticia': {
        'ingresos_mes': ingresos,
        'total_gastos_fijos': gastosFijos,
        'cuotas_tarjetas_mes': newCuotasTarj,
        'liquidez_disponible': newLiquidez,
        'porcentaje_endeudamiento': newPctEndeudamiento,
        'nivel_riesgo': newPctEndeudamiento > 80 ? 'ALTO' : (newPctEndeudamiento > 50 ? 'MEDIO' : 'BAJO'),
      },
      'totales': {
        'deuda_tarjetas': newDeudaTarjetas,
        'cuentas_cobrar': (totales['cuentas_cobrar'] as num?)?.toDouble() ?? 0.0,
        'total_ahorros': totalAhorros,
      },
      'tarjetas': data['tarjetas'],
      'cuentas_en_mora': data['cuentas_en_mora'],
    };

    _scoreSimulado = calculateHealthScore(dataSimulado);
    _pctSimulado = newPctEndeudamiento;
    _cuotaMensualSimulada = cuotaMensual;

    setState(() => _haSimulado = true);

    // Rocky reacciona
    final diff = _scoreSimulado!.score - _scoreActual!.score;
    final assistant = ref.read(virtualAssistantProvider.notifier);
    if (diff <= -20) {
      assistant.showActionMessage(
        '¡Impacto severo! Tu puntaje caería ${diff.abs()} puntos. Tu cuota mensual sería ${formatCOP(cuotaMensual)}. Piénsalo bien.',
        AssistantAnimation.warningSevere,
      );
    } else if (diff <= -10) {
      assistant.showActionMessage(
        'Cuidado: perderías ${diff.abs()} puntos de salud financiera. La cuota de ${formatCOP(cuotaMensual)} afectaría tu liquidez.',
        AssistantAnimation.glowRed,
      );
    } else if (diff < 0) {
      assistant.showActionMessage(
        'Impacto moderado: -${diff.abs()} puntos. Parece viable pero tu margen se reduce. Cuota: ${formatCOP(cuotaMensual)}/mes.',
        AssistantAnimation.nod,
      );
    } else {
      assistant.showActionMessage(
        'Tus finanzas pueden con esto sin problemas. Cuota mensual: ${formatCOP(cuotaMensual)}.',
        AssistantAnimation.thumbsUp,
      );
    }
  }

  Widget _buildResultCard() {
    final diff = _scoreSimulado!.score - _scoreActual!.score;
    final isGood = diff >= 0;
    final color = isGood ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        children: [
          Icon(
            isGood ? Icons.check_circle_rounded : Icons.warning_rounded,
            color: color,
            size: 36,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isGood ? 'Viable' : 'Riesgoso',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tu Health Score ${isGood ? "se mantiene" : "caería"} de ${_scoreActual!.score} a ${_scoreSimulado!.score} puntos.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(String label, double actual, double simulado, {required String suffix, bool isCurrency = false}) {
    final diff = simulado - actual;
    final isNeg = diff < 0;
    final color = label == 'Endeudamiento'
        ? (isNeg ? const Color(0xFF10B981) : const Color(0xFFEF4444))
        : (isNeg ? const Color(0xFFEF4444) : const Color(0xFF10B981));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
          ),
          Expanded(
            child: Text(
              isCurrency ? formatCOP(actual) : '${actual.round()}$suffix',
              style: AppTheme.monoStyle(fontSize: 12, color: AppTheme.textPrimary),
              textAlign: TextAlign.center,
            ),
          ),
          const Icon(Icons.arrow_right_alt_rounded, size: 18, color: Color(0xFFD1D5DB)),
          Expanded(
            child: Text(
              isCurrency ? formatCOP(simulado) : '${simulado.round()}$suffix',
              style: AppTheme.monoStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Color(0xFF9CA3AF),
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: const Color(0xFFE5E7EB)),
  );
}
