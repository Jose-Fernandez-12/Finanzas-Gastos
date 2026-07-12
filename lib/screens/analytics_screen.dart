import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/analytics_provider.dart';
import '../core/theme.dart';
import '../core/formatters.dart';
import '../core/local_repository.dart';
import 'dart:math' as math;

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _selectedMonth = mesActual();
  List<dynamic> _gastosDelMes = [];
  double _mesIngresos = 0.0;
  double _mesEgresos = 0.0;
  bool _loadingGastos = false;
  double _pctAbonoExtra = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ref.invalidate(analyticsProvider(_pctAbonoExtra));
      _fetchGastosDelMes();
    });
  }

  Future<void> _fetchGastosDelMes() async {
    setState(() => _loadingGastos = true);
    try {
      final rGastos = await LocalRepository.instance.getGastosFijos(mes: _selectedMonth);
      final List<dynamic> gastos = rGastos['data'] ?? [];
      double totalGastos = 0.0;
      for (var g in gastos) { totalGastos += (g['monto'] as num?)?.toDouble() ?? 0.0; }

      final rIngresos = await LocalRepository.instance.getIngresos(mes: _selectedMonth);
      final List<dynamic> ingresos = rIngresos['data'] ?? [];
      double totalIngresos = 0.0;
      for (var i in ingresos) { totalIngresos += (i['monto'] as num?)?.toDouble() ?? 0.0; }

      setState(() {
        _gastosDelMes = gastos;
        _mesIngresos = totalIngresos;
        _mesEgresos = totalGastos;
      });
    } catch (e) {
      debugPrint("Error loading data for analytics month $_selectedMonth: $e");
    } finally {
      setState(() => _loadingGastos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final analyticsAsync = ref.watch(analyticsProvider(_pctAbonoExtra));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analíticas', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, color: AppTheme.textPrimary)),
        backgroundColor: AppTheme.bgCanvas,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      backgroundColor: AppTheme.bgCanvas,
      body: _loadingGastos
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : analyticsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
              error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: AppTheme.colorGastos))),
              data: (provider) => _buildContent(provider),
            ),
    );
  }

  Widget _buildContent(Map<String, dynamic> provider) {
    // Construir historical dinámico con el mes seleccionado para que la gráfica no quede vacía
    final historical = [
      {'label': _selectedMonth, 'ingresos': _mesIngresos, 'egresos': _mesEgresos}
    ];
    final proyeccion = provider['proyeccion'] as List<dynamic>? ?? [];

    // Calcular datos de endeudamiento
    final double deudaTarjetas = (provider['deuda_tarjetas'] as num?)?.toDouble() ?? 0.0;
    final double cuentasPorCobrar = (provider['cuentas_por_cobrar'] as num?)?.toDouble() ?? 0.0;
    final double endeudamientoPct = (deudaTarjetas + cuentasPorCobrar) > 0
        ? (deudaTarjetas / (deudaTarjetas + cuentasPorCobrar) * 100)
        : 0.0;
    final String nivelRiesgo = endeudamientoPct > 60
        ? 'Alto'
        : endeudamientoPct > 35
            ? 'Medio'
            : 'Bajo';

    // Usar los ingresos y egresos cargados dinámicamente
    final double mesIngresos = _mesIngresos;
    final double mesEgresos = _mesEgresos;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selector de Mes flotante
          _buildMonthSelector(),
          const SizedBox(height: 20),

          // 1. Estado de Endeudamiento
          const _SectionTitle(title: 'Estado de Endeudamiento'),
          const SizedBox(height: 10),
          _buildEndeudamientoCard(endeudamientoPct, nivelRiesgo, provider),
          const SizedBox(height: 24),

          // 2. Tarjetas de Resumen Lado a Lado
          _buildResumenCards(mesIngresos, mesEgresos),
          const SizedBox(height: 24),

          // 3. Flujo de Caja
          const _SectionTitle(title: 'Flujo de Caja'),
          const SizedBox(height: 10),
          _buildBarChart(historical),
          const SizedBox(height: 24),

          // 4. Camino a Cero Deuda
          if (proyeccion.isNotEmpty) ...[
            const _SectionTitle(title: 'Camino a Cero Deuda'),
            const SizedBox(height: 10),
            _buildAbonoExtraSlider(),
            const SizedBox(height: 16),
            _buildLineChart(proyeccion, provider['mesLibreDeDeuda']?.toString() ?? ''),
            const SizedBox(height: 24),
          ],

          // 5. Gastos por Categoría
          const _SectionTitle(title: 'Gastos por Categoría'),
          const SizedBox(height: 10),
          _buildCategoriasCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showMonthPicker() {
    final now = DateTime.now();
    final List<String> monthsList = [];
    for (int i = 0; i < 12; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      final year = d.year;
      final month = d.month.toString().padLeft(2, '0');
      monthsList.add('$year-$month');
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Selecciona un Mes',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: monthsList.length,
                  itemBuilder: (context, idx) {
                    final mStr = monthsList[idx];
                    final isSelected = mStr == _selectedMonth;
                    return ListTile(
                      title: Text(
                        formatMes(mStr),
                        style: TextStyle(
                          color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected ? const Icon(Icons.check_rounded, color: AppTheme.primary) : null,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _selectedMonth = mStr;
                        });
                        _fetchGastosDelMes();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthSelector() {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: _showMonthPicker,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_rounded, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(
                formatMes(_selectedMonth),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEndeudamientoCard(double pct, String nivel, Map<String, dynamic> provider) {
    final color = AppTheme.colorPorRiesgo(nivel);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Deuda vs Activos', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  nivel == 'Bajo' ? 'Saludable' : 'Riesgo $nivel',
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${pct.toStringAsFixed(1)}%',
            style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          // Barra de progreso horizontal
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppTheme.borderLight,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('0%', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              Text('Riesgo ( >60% )', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ],
          ),
          const Divider(height: 28, color: AppTheme.borderLight),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.secondary)),
                        const SizedBox(width: 6),
                        const Text('A Favor', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(formatCOP((provider['cuentas_por_cobrar'] as num?)?.toDouble() ?? 0.0), style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.colorGastos)),
                        const SizedBox(width: 6),
                        const Text('Cuentas x Pagar', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(formatCOP((provider['deuda_tarjetas'] as num?)?.toDouble() ?? 0.0), style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumenCards(double ingresos, double egresos) {
    return Row(
      children: [
        // Tarjeta Ingresos
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderLight),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(4), blurRadius: 4, offset: const Offset(0, 1)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: AppTheme.colorIngresos.withAlpha(20), shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_upward_rounded, color: AppTheme.colorIngresos, size: 18),
                ),
                const SizedBox(height: 12),
                const Text('Ingresos', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(formatCOP(ingresos), style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: const [
                    Icon(Icons.trending_up_rounded, color: AppTheme.colorIngresos, size: 12),
                    SizedBox(width: 2),
                    Text('+12.5%', style: TextStyle(color: AppTheme.colorIngresos, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Tarjeta Gastos
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderLight),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(4), blurRadius: 4, offset: const Offset(0, 1)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: AppTheme.colorGastos.withAlpha(20), shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_downward_rounded, color: AppTheme.colorGastos, size: 18),
                ),
                const SizedBox(height: 12),
                const Text('Gastos', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(formatCOP(egresos), style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: const [
                    Icon(Icons.trending_down_rounded, color: AppTheme.colorGastos, size: 12),
                    SizedBox(width: 2),
                    Text('-2.4%', style: TextStyle(color: AppTheme.colorGastos, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart(List<dynamic> data) {
    double maxY = 0;
    for (var d in data) {
      maxY = math.max(maxY, (d['ingresos'] as num).toDouble());
      maxY = math.max(maxY, (d['egresos'] as num).toDouble());
    }
    if (maxY == 0) maxY = 10000;

    return Container(
      height: 230,
      padding: const EdgeInsets.all(16).copyWith(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY * 1.2,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value != value.toInt() || value.toInt() < 0 || value.toInt() >= data.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(data[value.toInt()]['label'], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (val, meta) {
                  if (val == 0) return const SizedBox.shrink();
                  return Text('\$${(val / 1000).toStringAsFixed(0)}k', style: const TextStyle(color: AppTheme.textMuted, fontSize: 9));
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.borderLight, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(data.length, (i) {
            final double ingresos = (data[i]['ingresos'] as num).toDouble();
            final double egresos = (data[i]['egresos'] as num).toDouble();

            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(toY: ingresos, color: AppTheme.colorIngresos, width: 8, borderRadius: BorderRadius.circular(4)),
                BarChartRodData(toY: egresos, color: AppTheme.colorGastos, width: 8, borderRadius: BorderRadius.circular(4)),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLineChart(List<dynamic> data, String mesLibre) {
    double maxY = 0;
    for (var d in data) {
      double deuda = (d['deuda_restante'] as num).toDouble();
      maxY = math.max(maxY, deuda);
    }
    if (maxY == 0) maxY = 10000;

    List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), (data[i]['deuda_restante'] as num).toDouble()));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Proyección estimada', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              Text('Libre de deuda: $mesLibre', style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY * 1.1,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          formatCOP(spot.y),
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: math.max(1.0, (data.length / 6).floorToDouble()),
                      getTitlesWidget: (value, meta) {
                        if (value != value.toInt() || value.toInt() < 0 || value.toInt() >= data.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(data[value.toInt()]['label'], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (val, meta) {
                        return Text('\$${(val / 1000).toStringAsFixed(1)}k', style: const TextStyle(color: AppTheme.textMuted, fontSize: 9));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.borderLight, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.colorDeudas,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.colorDeudas.withAlpha(20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbonoExtraSlider() {
    return StatefulBuilder(
      builder: (context, setStateSlider) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Abono Extra (% de Liquidez)', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('${_pctAbonoExtra.toInt()}%', style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.bold)),
                ],
              ),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppTheme.secondary,
                  inactiveTrackColor: AppTheme.secondary.withAlpha(40),
                  thumbColor: AppTheme.secondary,
                  overlayColor: AppTheme.secondary.withAlpha(20),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: _pctAbonoExtra,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  onChanged: (val) {
                    setStateSlider(() => _pctAbonoExtra = val);
                  },
                  onChangeEnd: (val) {
                    // Update global state
                    setState(() {
                      _pctAbonoExtra = val;
                    });
                  },
                ),
              ),
              const Text('Destina un porcentaje de tu dinero libre al pago acelerado de tus deudas para calcular cuándo terminarías de pagar.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ),
        );
      }
    );
  }

  Widget _buildCategoriasCard() {
    if (_gastosDelMes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: const Center(
          child: Text('Sin gastos registrados para analizar este mes.', style: TextStyle(color: AppTheme.textSecondary)),
        ),
      );
    }

    // Agrupar gastos por categoría
    final Map<String, double> categorySums = {};
    final Map<String, String> categoryColors = {};
    double totalExpenses = 0.0;

    for (var item in _gastosDelMes) {
      final catName = item['categoria_nombre']?.toString() ?? 'Otros';
      final amount = (item['monto'] as num?)?.toDouble() ?? 0.0;
      final colorHex = item['categoria_color']?.toString() ?? '#9CA3AF';

      categorySums[catName] = (categorySums[catName] ?? 0.0) + amount;
      categoryColors[catName] = colorHex;
      totalExpenses += amount;
    }

    // Convertir a lista ordenada para renderizar
    final sortedCategories = categorySums.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Generar las rebanadas del gráfico de dona
    final List<PieChartSectionData> sections = [];
    for (int i = 0; i < sortedCategories.length; i++) {
      final entry = sortedCategories[i];
      final color = hexToColor(categoryColors[entry.key]!);

      sections.add(
        PieChartSectionData(
          color: color,
          value: entry.value,
          radius: 18,
          showTitle: false,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Doughnut Chart
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 64,
                    sectionsSpace: 2,
                    startDegreeOffset: -90,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Total', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(
                      formatCOP(totalExpenses),
                      style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Legend List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedCategories.length,
            separatorBuilder: (_, __) => const Divider(height: 18, color: AppTheme.borderLight),
            itemBuilder: (context, index) {
              final entry = sortedCategories[index];
              final color = hexToColor(categoryColors[entry.key]!);
              final pct = totalExpenses > 0 ? (entry.value / totalExpenses * 100) : 0.0;

              return Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    formatCOP(entry.value),
                    style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${pct.toStringAsFixed(0)}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.2),
    );
  }
}
