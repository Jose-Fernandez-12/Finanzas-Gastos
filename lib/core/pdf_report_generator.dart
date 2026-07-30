import 'dart:io';
import 'package:flutter/material.dart' as material;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'formatters.dart';

class PdfReportGenerator {
  static Future<void> generateAndSaveReport(material.BuildContext context, Map<String, dynamic> data) async {
    material.ScaffoldMessenger.of(context).showSnackBar(
      const material.SnackBar(content: material.Text('Generando documento PDF...')),
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
          build: (pw.Context ctx) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Reporte Financiero Detallado', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.Text(formatFecha(DateTime.now().toString()), style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Resumen Ejecutivo
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Resumen Ejecutivo', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStat('Liquidez Neta', liquidez, PdfColors.black),
                        _buildStat('Ingresos Mes', ingresos, PdfColors.green700),
                        _buildStat('Egresos Mes', totalEgresos, PdfColors.red700),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text('Nivel de Endeudamiento: ${pctEndeudamiento.toStringAsFixed(1)}%', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Análisis de Deuda y Respaldo
              pw.Text('Análisis de Patrimonio', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildStat('Deuda en Tarjetas', deudaTarjetas, PdfColors.red700),
                  _buildStat('Fondo de Ahorros', totalAhorros, PdfColors.blue700),
                  _buildStat('Cuentas por Cobrar', totalCuentasCobrar, PdfColors.green700),
                ],
              ),
              pw.SizedBox(height: 30),

              // Próximas Cuotas
              if (proximasCuotas.isNotEmpty) ...[
                pw.Text('Próximos Vencimientos (45 Días)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Table.fromTextArray(
                  context: ctx,
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerLeft,
                  data: <List<String>>[
                    <String>['Concepto', 'Tarjeta', 'Vencimiento', 'Cuota', 'Valor'],
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

  static pw.Widget _buildStat(String label, double value, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
        pw.SizedBox(height: 2),
        pw.Text(formatCOP(value), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
      ],
    );
  }
}
