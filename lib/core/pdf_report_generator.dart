import 'dart:io';
import 'package:flutter/material.dart' as material;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'formatters.dart';

class PdfReportGenerator {
  // Colores corporativos basados en AppTheme
  static const primaryColor = PdfColor.fromInt(0xFF6C63FF);
  static const primaryDarkColor = PdfColor.fromInt(0xFF4F46E5);
  static const ingresosColor = PdfColor.fromInt(0xFF10B981);
  static const gastosColor = PdfColor.fromInt(0xFFEF4444);
  static const ahorrosColor = PdfColor.fromInt(0xFF3B82F6);
  static const deudaColor = PdfColor.fromInt(0xFFF59E0B);
  static const bgLight = PdfColor.fromInt(0xFFF3F4F6);

  static Future<void> generateAndSaveReport(material.BuildContext context, Map<String, dynamic> data) async {
    material.ScaffoldMessenger.of(context).showSnackBar(
      const material.SnackBar(content: material.Text('Generando reporte PDF con gráficas...')),
    );

    try {
      final pdf = pw.Document();

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

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (pw.Context ctx) {
            return pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('REPORTE FINANCIERO DETALLADO', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: primaryDarkColor)),
                        pw.SizedBox(height: 4),
                        pw.Text('Análisis del Estado de Finanzas', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Text(formatFecha(DateTime.now().toString()), style: pw.TextStyle(fontSize: 12, color: primaryColor, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Divider(color: primaryColor, thickness: 2),
                pw.SizedBox(height: 20),
              ],
            );
          },
          build: (pw.Context ctx) {
            return [
              // 1. Resumen Ejecutivo (Con Gráfico)
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: bgLight,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Columna de Datos
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Balance General del Mes', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryDarkColor)),
                          pw.SizedBox(height: 15),
                          _buildStat('Liquidez Libre a Fin de Mes', liquidez, PdfColors.black, size: 20),
                          pw.SizedBox(height: 15),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStat('Ingresos Totales', ingresos, ingresosColor),
                              _buildStat('Egresos Totales', totalEgresos, gastosColor),
                            ],
                          ),
                          pw.SizedBox(height: 15),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: pw.BoxDecoration(color: pctEndeudamiento > 60 ? gastosColor : (pctEndeudamiento > 40 ? deudaColor : ingresosColor), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
                            child: pw.Text('Nivel de Endeudamiento: ${pctEndeudamiento.toStringAsFixed(1)}%', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          ),
                        ],
                      ),
                    ),
                    // Gráfica de Torta
                    pw.SizedBox(width: 20),
                    if (ingresos > 0 || totalEgresos > 0)
                      pw.SizedBox(
                        height: 120,
                        width: 120,
                        child: pw.Chart(
                          grid: pw.PieGrid(),
                          datasets: [
                            pw.PieDataSet(
                              value: ingresos,
                              color: ingresosColor,
                              legend: 'Ingresos',
                            ),
                            pw.PieDataSet(
                              value: totalEgresos,
                              color: gastosColor,
                              legend: 'Egresos',
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // 2. Análisis de Patrimonio
              pw.Text('ANÁLISIS DE PATRIMONIO Y RESPALDO', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryDarkColor)),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildCardStat('Deuda en Tarjetas', deudaTarjetas, deudaColor),
                  _buildCardStat('Fondo de Ahorros', totalAhorros, ahorrosColor),
                  _buildCardStat('Cuentas por Cobrar', totalCuentasCobrar, ingresosColor),
                ],
              ),
              pw.SizedBox(height: 30),

              // 3. Próximas Cuotas Detalladas
              if (proximasCuotas.isNotEmpty) ...[
                pw.Text('PRÓXIMOS VENCIMIENTOS (45 DÍAS)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryDarkColor)),
                pw.Divider(color: PdfColors.grey400),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  context: ctx,
                  headerDecoration: const pw.BoxDecoration(color: primaryColor),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  cellAlignment: pw.Alignment.centerLeft,
                  rowDecoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  data: <List<String>>[
                    <String>['Concepto / Detalle', 'Tarjeta / Entidad', 'Vencimiento', 'Cuota', 'Valor (COP)'],
                    ...proximasCuotas.map((c) {
                      final map = Map<String, dynamic>.from(c);
                      return <String>[
                        map['compra_descripcion']?.toString() ?? 'Compra',
                        map['nombre_tarjeta']?.toString() ?? 'TC',
                        formatFecha(map['fecha_vencimiento']?.toString()),
                        map['numero_cuota']?.toString() ?? '1',
                        formatCOP((map['valor_cuota'] as num).toDouble()),
                      ];
                    })
                  ],
                ),
              ],
            ];
          },
          footer: (pw.Context ctx) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 10),
              child: pw.Text(
                'Generado por Antigravity Finanzas App • Página ${ctx.pageNumber} de ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/Reporte_Financiero_Detallado.pdf');
      await file.writeAsBytes(await pdf.save());

      // Abrir el diálogo nativo de "Guardar en archivos / Compartir"
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Reporte Financiero Detallado',
      );

    } catch (e) {
      if (context.mounted) {
        material.ScaffoldMessenger.of(context).showSnackBar(
          material.SnackBar(content: material.Text('Error al generar PDF: $e')),
        );
      }
    }
  }

  static pw.Widget _buildStat(String label, double value, PdfColor color, {double size = 16}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
        pw.SizedBox(height: 2),
        pw.Text(formatCOP(value), style: pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold, color: color)),
      ],
    );
  }

  static pw.Widget _buildCardStat(String label, double value, PdfColor color) {
    return pw.Container(
      width: 130,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 1.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800), textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 6),
          pw.Text(formatCOP(value), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color), textAlign: pw.TextAlign.center),
        ],
      ),
    );
  }
}
