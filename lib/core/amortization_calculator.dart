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

  /// Calcula el desglose y ahorro de intereses al anticipar N cuotas pendientes.
  /// Al anticipar cuotas, el usuario paga unicamente el componente de capital,
  /// ahorrando el 100% de los intereses futuros programados para esas cuotas.
  static Map<String, dynamic> calcularAhorroAnticipo(
    List<Map<String, dynamic>> cuotasPendientes, 
    int cantidadCuotas
  ) {
    if (cuotasPendientes.isEmpty || cantidadCuotas <= 0) {
      return {
        'cuotasSeleccionadas': <Map<String, dynamic>>[],
        'cantidad': 0,
        'capitalTotal': 0.0,
        'interesAhorrado': 0.0,
        'totalOriginal': 0.0,
        'totalPagar': 0.0,
      };
    }

    final n = min(cantidadCuotas, cuotasPendientes.length);
    final seleccionadas = cuotasPendientes.sublist(0, n);

    double capitalTotal = 0.0;
    double interesAhorrado = 0.0;
    double totalOriginal = 0.0;

    for (var c in seleccionadas) {
      final cap = (c['valor_capital'] as num?)?.toDouble() ?? 0.0;
      final intVal = (c['valor_interes'] as num?)?.toDouble() ?? 0.0;
      final cuotaVal = (c['valor_cuota'] as num?)?.toDouble() ?? (cap + intVal);

      capitalTotal += cap;
      interesAhorrado += intVal;
      totalOriginal += cuotaVal;
    }

    return {
      'cuotasSeleccionadas': seleccionadas,
      'cantidad': n,
      'capitalTotal': double.parse(capitalTotal.toStringAsFixed(2)),
      'interesAhorrado': double.parse(interesAhorrado.toStringAsFixed(2)),
      'totalOriginal': double.parse(totalOriginal.toStringAsFixed(2)),
      'totalPagar': double.parse(capitalTotal.toStringAsFixed(2)),
    };
  }

  /// Simula la distribución de un pago libre en cascada (estilo Nu / RappiCard)
  /// sobre una lista de cuotas pendientes de toda la tarjeta.
  static Map<String, dynamic> simularAbonoCascadaTarjeta({
    required List<Map<String, dynamic>> cuotasPendientes,
    required double montoAbono,
  }) {
    if (montoAbono <= 0 || cuotasPendientes.isEmpty) {
      return {
        'cuotasPagadas': <Map<String, dynamic>>[],
        'cuotaParcial': null,
        'capitalAmortizado': 0.0,
        'interesAhorrado': 0.0,
        'excedenteCupo': montoAbono > 0 ? montoAbono : 0.0,
        'totalCuotasImpactadas': 0,
      };
    }

    double saldoRestante = montoAbono;
    double capitalAmortizado = 0.0;
    double interesAhorrado = 0.0;
    final List<Map<String, dynamic>> cuotasPagadas = [];
    Map<String, dynamic>? cuotaParcial;

    for (var cuota in cuotasPendientes) {
      if (saldoRestante <= 0.001) break;

      final cap = (cuota['valor_capital'] as num?)?.toDouble() ?? 0.0;
      final intVal = (cuota['valor_interes'] as num?)?.toDouble() ?? 0.0;

      // Al anticipar, el costo para liquidar la cuota es solo el capital (ahorrando el interés futuro)
      if (saldoRestante >= cap - 0.001) {
        // Cubre la cuota completamente
        cuotasPagadas.add(cuota);
        capitalAmortizado += cap;
        interesAhorrado += intVal;
        saldoRestante -= cap;
      } else {
        // Cubre parcialmente esta cuota
        final abonoParcial = saldoRestante;
        cuotaParcial = {
          'cuota': cuota,
          'abonoCapital': abonoParcial,
          'nuevoCapital': max(0.0, cap - abonoParcial),
        };
        capitalAmortizado += abonoParcial;
        saldoRestante = 0.0;
        break;
      }
    }

    return {
      'cuotasPagadas': cuotasPagadas,
      'cuotaParcial': cuotaParcial,
      'capitalAmortizado': double.parse(capitalAmortizado.toStringAsFixed(2)),
      'interesAhorrado': double.parse(interesAhorrado.toStringAsFixed(2)),
      'excedenteCupo': double.parse(max(0.0, saldoRestante).toStringAsFixed(2)),
      'totalCuotasImpactadas': cuotasPagadas.length + (cuotaParcial != null ? 1 : 0),
    };
  }
}

