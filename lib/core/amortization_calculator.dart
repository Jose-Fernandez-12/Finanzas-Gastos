import 'dart:math';

class AmortizationCalculator {
  static double eaAMensual(double ea) {
    return pow(1 + ea, 1 / 12).toDouble() - 1;
  }

  static double calcularCuotaFija(double capital, double tasaMensual, int numCuotas) {
    if (tasaMensual == 0) return capital / numCuotas;
    final factor = pow(1 + tasaMensual, numCuotas);
    return capital * (tasaMensual * factor) / (factor - 1);
  }

  static DateTime calcularPrimerPago(String fechaCompraStr, int diaCorte, int diaPago) {
    final fCompra = DateTime.parse("${fechaCompraStr}T00:00:00");
    
    DateTime fCorte = DateTime(fCompra.year, fCompra.month, diaCorte);
    if (fCompra.isAfter(fCorte) || fCompra.isAtSameMomentAs(fCorte)) {
      fCorte = DateTime(fCorte.year, fCorte.month + 1, fCorte.day);
    }
    
    DateTime fPago = DateTime(fCorte.year, fCorte.month, diaPago);
    if (fPago.isBefore(fCorte) || fPago.isAtSameMomentAs(fCorte)) {
      fPago = DateTime(fPago.year, fPago.month + 1, fPago.day);
    }
    return fPago;
  }

  static List<Map<String, dynamic>> generarTablaAmortizacion(
    double capital, double tasaMensual, int numCuotas, 
    String fechaCompra, int diaCorte, int diaPago, [String banco = '']
  ) {
    if (numCuotas == 1) tasaMensual = 0; // Sin interes a 1 cuota
    
    final esRappi = banco.toLowerCase().contains('rappi');
    final cuotaFija = esRappi ? 0.0 : calcularCuotaFija(capital, tasaMensual, numCuotas);
    final abonoCapitalRappi = esRappi ? double.parse((capital / numCuotas).toStringAsFixed(2)) : 0.0;
    
    final tabla = <Map<String, dynamic>>[];
    double saldo = capital;
    
    DateTime fechaActualPago = calcularPrimerPago(fechaCompra, diaCorte, diaPago);

    final List<double> listInteres = [];
    if (esRappi && numCuotas > 1) {
      double tempSaldo = capital;
      for (int k = 1; k <= numCuotas; k++) {
        double interes = 0;
        if (k == 1) {
          interes = double.parse((tempSaldo * tasaMensual * 0.7).toStringAsFixed(2));
        } else if (k == numCuotas) {
          interes = 0;
        } else {
          interes = double.parse((tempSaldo * tasaMensual).toStringAsFixed(2));
        }
        listInteres.add(interes);
        tempSaldo = double.parse(max(0.0, tempSaldo - abonoCapitalRappi).toStringAsFixed(2));
      }
      final reversedInteres = listInteres.reversed.toList();
      listInteres.clear();
      listInteres.addAll(reversedInteres);
    }

    for (int k = 1; k <= numCuotas; k++) {
      double interes = 0;
      double capK = 0;
      
      if (esRappi && numCuotas > 1) {
        interes = listInteres[k - 1];
        capK = abonoCapitalRappi;
      } else {
        interes = double.parse((saldo * tasaMensual).toStringAsFixed(2));
        capK   = double.parse((cuotaFija - interes).toStringAsFixed(2));
      }

      if (k == numCuotas) {
        // Ajuste final de capital por redondeos
        capK = double.parse(saldo.toStringAsFixed(2));
      }
      
      double valK = double.parse((capK + interes).toStringAsFixed(2));

      double saldoFinal = double.parse(max(0.0, saldo - capK).toStringAsFixed(2));

      tabla.add({
        'numero_cuota':      k,
        'fecha_vencimiento': fechaActualPago.toIso8601String().split('T')[0],
        'saldo_inicial':     double.parse(saldo.toStringAsFixed(2)),
        'valor_capital':     capK,
        'valor_interes':     interes,
        'valor_cuota':       valK,
        'saldo_final':       saldoFinal,
        'estado':            'PENDIENTE',
      });

      saldo = saldoFinal;
      
      // Calcular proxima fecha de pago
      DateTime nextMonth = DateTime(fechaActualPago.year, fechaActualPago.month + 1, 1);
      final maxDia = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
      nextMonth = DateTime(nextMonth.year, nextMonth.month, min(diaPago, maxDia));
      fechaActualPago = nextMonth;
    }

    return tabla;
  }
}
