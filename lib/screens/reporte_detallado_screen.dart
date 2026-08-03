import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/theme.dart';
import '../core/formatters.dart';
import '../providers/dashboard_provider.dart';
import '../core/pdf_report_generator.dart';

class ReporteDetalladoView extends ConsumerWidget {
  const ReporteDetalladoView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);

    return dashboardAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (response) {
          final data = response['data'] as Map<String, dynamic>;
          final cap = data['capacidad_crediticia'] as Map<String, dynamic>;
          
          final ingresos = (cap['ingresos_mes'] as num).toDouble();
          final gastosFijos = (cap['total_gastos_fijos'] as num).toDouble();
          final cuotasTarj = (cap['cuotas_tarjetas_mes'] as num).toDouble();
          final totalEgresos = gastosFijos + cuotasTarj;
          final liquidez = (cap['liquidez_disponible'] as num).toDouble();
          final pctEndeudamiento = (cap['porcentaje_endeudamiento'] as num).toDouble();

          final totales = data['totales'] as Map<String, dynamic>;
          final totalAhorros = (totales['total_ahorros'] as num).toDouble();
          final totalCuentasCobrar = (totales['cuentas_cobrar'] as num).toDouble();
          final deudaTarjetas = (totales['deuda_tarjetas'] as num).toDouble();

          final proximasCuotas = data['proximas_cuotas'] as List<dynamic>;
          final ahorros = data['ahorros'] as List<dynamic>;
          final cuentasMora = data['cuentas_en_mora'] as List<dynamic>;
          final tarjetasData = data['tarjetas'] as List<dynamic>;

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. Resumen Ejecutivo (Hero)
                  _buildResumenEjecutivo(ingresos, totalEgresos, liquidez, pctEndeudamiento),
                  const SizedBox(height: 24),

                  // 2. Gráfico Ingresos vs Egresos
                  if (ingresos > 0 || totalEgresos > 0)
                    _buildGraficoBalance(ingresos, totalEgresos),
                  const SizedBox(height: 24),

                  // 3. Desglose Detallado de Tarjetas de Crédito y Deuda
                  if (tarjetasData.isNotEmpty)
                    _buildDesgloseTarjetas(tarjetasData, deudaTarjetas),
                  const SizedBox(height: 24),

                  // 4. Próximas Cuotas Detalladas
                  if (proximasCuotas.isNotEmpty)
                    _buildDetalleCuotas(proximasCuotas),
                  const SizedBox(height: 24),

                  // 5. Ahorros
                  if (ahorros.isNotEmpty)
                    _buildDetalleAhorros(ahorros, totalAhorros),
                  const SizedBox(height: 24),

                  // 6. Cuentas por Cobrar
                  _buildCuentasCobrar(totalCuentasCobrar, cuentasMora),
                  
                  const SizedBox(height: 80),
                ],
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton.extended(
                  heroTag: 'pdfDownload',
                  onPressed: () => PdfReportGenerator.generateAndSaveReport(context, data),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Descargar PDF'),
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
    );
  }

  Widget _buildResumenEjecutivo(double ingresos, double egresos, double liquidez, double pctEndeudamiento) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withAlpha(80),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Liquidez a Fin de Mes', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Text(formatCOP(liquidez), style: AppTheme.monoStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MiniStat(label: 'Ingresos Totales', value: ingresos, color: Colors.greenAccent),
              _MiniStat(label: 'Egresos Totales', value: egresos, color: Colors.redAccent),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.analytics, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('Nivel de Endeudamiento: ${pctEndeudamiento.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraficoBalance(double ingresos, double egresos) {
    final double total = ingresos + egresos;
    if (total == 0) return const SizedBox();

    final pctIngreso = (ingresos / total) * 100;
    final pctEgreso = (egresos / total) * 100;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Proporción: Ingresos vs Egresos', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 50,
                sections: [
                  PieChartSectionData(
                    color: AppTheme.colorIngresos,
                    value: ingresos,
                    title: '${pctIngreso.toStringAsFixed(0)}%',
                    radius: 40,
                    titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  PieChartSectionData(
                    color: AppTheme.colorGastos,
                    value: egresos,
                    title: '${pctEgreso.toStringAsFixed(0)}%',
                    radius: 40,
                    titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Indicator(color: AppTheme.colorIngresos, text: 'Ingresos'),
              const SizedBox(width: 16),
              _Indicator(color: AppTheme.colorGastos, text: 'Egresos'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesgloseTarjetas(List<dynamic> tarjetas, double deudaTotal) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.credit_card, color: AppTheme.colorDeudas),
              const SizedBox(width: 8),
              const Text('Análisis de Tarjetas', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Deuda Total: ${formatCOP(deudaTotal)}', style: AppTheme.monoStyle(color: AppTheme.colorDeudas, fontSize: 16)),
          const Divider(height: 32),
          ...tarjetas.map((t) {
            final mapa = Map<String, dynamic>.from(t);
            final cupoTotal = (mapa['cupo_total'] as num).toDouble();
            final cupoDispo = (mapa['cupo_disponible'] as num).toDouble();
            final deuda = cupoTotal - cupoDispo;
            final pctUtilizado = cupoTotal > 0 ? (deuda / cupoTotal) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mapa['nombre_tarjeta'], style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Deuda: ${formatCOP(deuda)}', style: AppTheme.monoStyle(color: AppTheme.colorDeudas, fontSize: 12)),
                      Text('Disp: ${formatCOP(cupoDispo)}', style: AppTheme.monoStyle(color: AppTheme.colorIngresos, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: pctUtilizado,
                    backgroundColor: AppTheme.borderLight,
                    color: AppTheme.colorDeudas,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDetalleCuotas(List<dynamic> cuotas) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Próximas Cuotas Detalladas (45 Días)', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...cuotas.map((c) {
            final cuota = Map<String, dynamic>.from(c);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bgCardLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long, color: AppTheme.textSecondary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cuota['compra_descripcion'] ?? 'Cuota', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('${cuota['nombre_tarjeta']} - Cuota ${cuota['numero_cuota']}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        Text('Vence: ${formatFecha(cuota['fecha_vencimiento']?.toString())}', style: const TextStyle(fontSize: 12, color: AppTheme.colorGastos, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Text(formatCOP((cuota['valor_cuota'] as num).toDouble()), style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDetalleAhorros(List<dynamic> ahorros, double totalAhorros) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.savings, color: AppTheme.colorAhorros),
              const SizedBox(width: 8),
              const Text('Respaldo Financiero (Ahorros)', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Total: ${formatCOP(totalAhorros)}', style: AppTheme.monoStyle(color: AppTheme.colorAhorros, fontSize: 16)),
          const Divider(height: 32),
          ...ahorros.map((a) {
            final map = Map<String, dynamic>.from(a);
            final actual = (map['monto_actual'] as num).toDouble();
            final meta = (map['meta'] as num?)?.toDouble();
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.bgCardLight, borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(map['nombre_bolsillo'] ?? 'Ahorro', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatCOP(actual), style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                      if (meta != null && meta > 0)
                        Text('Meta: ${formatCOP(meta)}', style: AppTheme.monoStyle(color: AppTheme.textSecondary, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCuentasCobrar(double totalCuentas, List<dynamic> mora) {
    if (totalCuentas == 0 && mora.isEmpty) return const SizedBox();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Text('Cuentas por Cobrar', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Total Pendiente: ${formatCOP(totalCuentas)}', style: AppTheme.monoStyle(color: AppTheme.primary, fontSize: 16)),
          if (mora.isNotEmpty) ...[
            const Divider(height: 32),
            const Text('Atención: Deudores en Mora', style: TextStyle(color: AppTheme.colorMora, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...mora.map((m) {
              final map = Map<String, dynamic>.from(m);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('• ${map['nombre_deudor']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text(formatCOP((map['saldo_pendiente'] as num).toDouble()), style: AppTheme.monoStyle(color: AppTheme.colorMora, fontSize: 14)),
                ],
              );
            }),
          ]
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppTheme.bgCard,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.borderLight),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(5),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 2),
        Text(formatCOP(value), style: AppTheme.monoStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _Indicator extends StatelessWidget {
  final Color color;
  final String text;

  const _Indicator({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
      ],
    );
  }
}
