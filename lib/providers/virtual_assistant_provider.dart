import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dashboard_provider.dart';
import '../core/formatters.dart';

enum AssistantAnimation {
  idle, jump, shake, stretch, shrink, spin, flip, glowGreen, glowRed, nod, glitch, sleep, alert, happy, thinking
}

class AssistantState {
  final String message;
  final bool isVisible;
  final bool isAction;
  final AssistantAnimation animation;

  AssistantState({
    required this.message, 
    this.isVisible = false, 
    this.isAction = false,
    this.animation = AssistantAnimation.idle,
  });

  AssistantState copyWith({String? message, bool? isVisible, bool? isAction, AssistantAnimation? animation}) {
    return AssistantState(
      message: message ?? this.message,
      isVisible: isVisible ?? this.isVisible,
      isAction: isAction ?? this.isAction,
      animation: animation ?? this.animation,
    );
  }
}

class VirtualAssistantNotifier extends Notifier<AssistantState> {
  final _random = Random();
  String _lastDashboardDataHash = '';

  bool _hasGreeted = false;
  final DateTime _startupTime = DateTime.now();

  @override
  AssistantState build() {
    ref.listen(dashboardProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        if (!_hasGreeted) {
          _hasGreeted = true;
          return;
        }
        if (DateTime.now().difference(_startupTime).inSeconds < 12) return;
        if (!state.isAction || !state.isVisible) {
          _analyzeDashboardData(next.value!);
        }
      }
    });

    final horaActual = DateTime.now().hour;
    String msg = "";
    AssistantAnimation anim = AssistantAnimation.idle;

    if (horaActual >= 0 && horaActual < 5) {
      final opciones = [
        "¿Trasnochando? Tus finanzas no duermen, pero tú deberías.",
        "Hola noctámbulo. Espero que no estés gastando dinero a estas horas.",
        "Las 3 am no es buena hora para compras compulsivas, solo digo."
      ];
      msg = opciones[_random.nextInt(opciones.length)];
      anim = AssistantAnimation.sleep;
    } else if (horaActual >= 5 && horaActual < 9) {
      final opciones = [
        "¿Recién levantado? Un buen café y a revisar esos números.",
        "¡Buenos días! Vamos a hacer que hoy cuente.",
        "A madrugar se dijo. Revisemos cómo empezamos el día financieramente."
      ];
      msg = opciones[_random.nextInt(opciones.length)];
      anim = AssistantAnimation.stretch;
    } else if (horaActual >= 9 && horaActual < 13) {
      final opciones = [
        "¡Hola! Iniciando sistemas financieros...",
        "Bienvenido. ¿Listo para dominar tus finanzas hoy?",
        "Hola, soy Rocky. Aquí estoy para cuidar tu dinero."
      ];
      msg = opciones[_random.nextInt(opciones.length)];
      anim = AssistantAnimation.idle;
    } else if (horaActual >= 13 && horaActual < 19) {
      final opciones = [
        "¡Buenas tardes! ¿Cómo va el presupuesto de hoy?",
        "Espero que la tarde vaya bien. Vamos a revisar cómo van los números.",
        "Sistemas en línea. Preparado para analizar tu progreso en lo que va del día."
      ];
      msg = opciones[_random.nextInt(opciones.length)];
      anim = AssistantAnimation.nod;
    } else {
      final opciones = [
        "Buenas noches. Hora de cuadrar caja antes de descansar.",
        "El día casi termina, veamos cómo te fue hoy con los gastos.",
        "Un último vistazo a las cuentas antes de dormir nunca está de más."
      ];
      msg = opciones[_random.nextInt(opciones.length)];
      anim = AssistantAnimation.idle;
    }
    
    final initialState = AssistantState(
      message: msg, 
      isVisible: true, 
      isAction: false, 
      animation: anim,
    );
    
    Future.microtask(() => _autoHide());

    return initialState;
  }

  void analyzeTransactionItem(String tipo, double monto, String nombre) {
    String msg = "";
    AssistantAnimation anim = AssistantAnimation.idle;

    if (tipo == 'gasto') {
      msg = "El gasto '$nombre' es de ${formatCOP(monto)}. Asegúrate de que estaba contemplado en el presupuesto de este mes.";
      anim = monto > 100000 ? AssistantAnimation.shrink : AssistantAnimation.nod;
    } else if (tipo == 'ingreso') {
      msg = "Ingreso registrado: '$nombre' por ${formatCOP(monto)}. Una excelente oportunidad para aumentar tus ahorros.";
      anim = AssistantAnimation.jump;
    } else if (tipo == 'pago') {
      msg = "Has registrado el pago de '$nombre' por ${formatCOP(monto)}. Menos deudas, más tranquilidad.";
      anim = AssistantAnimation.glowGreen;
    } else if (tipo == 'cuota') {
      msg = "Esta cuota de '$nombre' es de ${formatCOP(monto)}. ¿Ya consideraste si puedes abonar a capital para salir de ella más rápido?";
      anim = AssistantAnimation.stretch;
    } else {
      msg = "Registro de '$nombre' analizado.";
      anim = AssistantAnimation.nod;
    }

    state = AssistantState(message: msg, isVisible: true, isAction: true, animation: anim);
    _autoHide();
  }

  void analyzeChart(String chartType, Map<String, dynamic> data) {
    String msg = "";
    AssistantAnimation anim = AssistantAnimation.idle;

    switch (chartType) {
      case 'termometro':
        final double disponible = (data['disponible_real'] as num?)?.toDouble() ?? 0.0;
        final double diario = (data['diario_seguro'] as num?)?.toDouble() ?? 0.0;
        final String estado = data['estado'] as String? ?? 'Sano';
        
        if (estado == 'Déficit') {
          final opciones = [
            "Estás en déficit. Frena todo gasto no esencial inmediatamente.",
            "Alerta roja: Tienes menos de lo necesario para cubrir tus gastos fijos.",
            "¡Peligro! Tus compromisos superan tus ingresos actuales. Hay que recortar ya."
          ];
          msg = opciones[_random.nextInt(opciones.length)];
          anim = AssistantAnimation.shake;
        } else if (estado == 'Ajustado') {
          final opciones = [
            "Tu presupuesto está muy ajustado. Tienes un disponible real de ${formatCOP(disponible)}.",
            "Ve con cuidado. No te excedas de ${formatCOP(diario)} por día o habrá problemas.",
            "Margen de error pequeño. Trata de no gastar de más los próximos días."
          ];
          msg = opciones[_random.nextInt(opciones.length)];
          anim = AssistantAnimation.shrink;
        } else {
          final opciones = [
            "Salud financiera buena. Puedes gastar hasta ${formatCOP(diario)} al día con tranquilidad.",
            "Excelente trabajo, tus números están sanos. Tienes liquidez disponible.",
            "Todo bajo control. Sigues teniendo buen margen de maniobra."
          ];
          msg = opciones[_random.nextInt(opciones.length)];
          anim = AssistantAnimation.jump;
        }
        break;

      case 'camino_cero_deuda':
        final mesLibre = data['mesLibreDeDeuda']?.toString() ?? 'pronto';
        final pctAbono = (data['pctAbono'] as num?)?.toDouble() ?? 0.0;
        if (pctAbono > 0) {
          msg = "Simulando... Con un abono extra del $pctAbono%, serás libre de deudas en $mesLibre. ¡Excelente esfuerzo!";
          anim = AssistantAnimation.happy;
        } else {
          msg = "Si no haces abonos extra, terminarás de pagar en $mesLibre. ¿Probamos a subir un poco la barra?";
          anim = AssistantAnimation.thinking;
        }
        break;

      case 'abono_extra':
        final double pct = (data['pct'] as num?)?.toDouble() ?? 0.0;
        final String mesLibre = data['mesLibre']?.toString() ?? 'pronto';
        msg = pct > 0 ? "Calculando... Con $pct% extra de abono, proyectamos que pagarás todo en $mesLibre." : "Manteniendo este ritmo sin abonos extra, serás libre de deudas en $mesLibre.";
        anim = pct > 0 ? AssistantAnimation.thinking : AssistantAnimation.idle;
        break;

      case 'interes_quemado':
        final double pctIngresos = (data['pct_de_ingresos'] as num?)?.toDouble() ?? 0.0;
        final double totalAnual = (data['total_anual'] as num?)?.toDouble() ?? 0.0;
        
        if (pctIngresos > 10) {
          final opciones = [
            "Estás quemando un $pctIngresos% de tus ingresos en intereses. ¡Urge consolidar o refinanciar!",
            "Ese pago de intereses es demasiado alto. El banco se está haciendo rico contigo.",
            "Estás pagando mucho al banco. Necesitamos un plan de rescate para esas deudas altas."
          ];
          msg = opciones[_random.nextInt(opciones.length)];
          anim = AssistantAnimation.shake;
        } else {
          final opciones = [
            "El banco se lleva ${formatCOP(totalAnual)} al año. Considera hacer abonos a capital.",
            "Tus intereses están controlados, pero siempre es bueno pagar más rápido.",
            "Si bajas ese interés anual de ${formatCOP(totalAnual)}, será dinero extra para tu bolsillo."
          ];
          msg = opciones[_random.nextInt(opciones.length)];
          anim = AssistantAnimation.nod;
        }
        break;
        
      case 'estres_efectivo':
        final bool alerta = data['alerta'] as bool? ?? false;
        final int diaPico = data['dia_pico'] as int? ?? 15;
        
        if (alerta) {
          final opciones = [
            "Atención: Hay alta presión financiera alrededor del día $diaPico. Guarda liquidez.",
            "Se viene un pico de gastos el día $diaPico. Prepárate desde ahora.",
            "Cuidado con tu flujo de caja en los próximos días. Guarda efectivo para el día $diaPico."
          ];
          msg = opciones[_random.nextInt(opciones.length)];
          anim = AssistantAnimation.glitch;
        } else {
          final opciones = [
            "Tu flujo de pagos está bien distribuido. No hay días de estrés extremo a la vista.",
            "Este mes tu liquidez parece estar tranquila. Bien planificado.",
            "Todo se ve manejable en tu calendario de pagos."
          ];
          msg = opciones[_random.nextInt(opciones.length)];
          anim = AssistantAnimation.nod;
        }
        break;
        
      case 'endeudamiento':
        final double pct = (data['pct'] as num?)?.toDouble() ?? 0.0;
        final String nivel = data['nivel']?.toString() ?? 'Bajo';
        if (nivel == 'Alto') {
           msg = "¡Alerta! Tu nivel de endeudamiento es $nivel (${pct.toStringAsFixed(1)}%). Recomiendo frenar nuevos créditos y priorizar pagos de capital.";
           anim = AssistantAnimation.alert;
        } else if (nivel == 'Medio') {
           msg = "Estás en un nivel $nivel (${pct.toStringAsFixed(1)}%). Mantén un ojo en las cuotas para que no se te salgan de las manos.";
           anim = AssistantAnimation.nod;
        } else {
          final opciones = [
            "Tu endeudamiento del ${pct.toStringAsFixed(1)}% es manejable. Mantenlo así.",
            "Buen equilibrio, ${pct.toStringAsFixed(1)}% de endeudamiento está en una zona saludable.",
            "Estás usando el crédito de forma razonable. No te confíes demasiado."
          ];
          msg = opciones[_random.nextInt(opciones.length)];
          anim = AssistantAnimation.nod;
        }
        break;

      case 'esclavitud_financiera':
        final libres = (data['dias_libres'] as num?)?.toDouble() ?? 0;
        if (libres > 15) {
          final opciones = [
            "¡Tienes $libres días libres al mes! Eres dueño de gran parte de tu tiempo.",
            "Trabajas más para ti que para el banco. Esos $libres días libres lo demuestran.",
            "Tu independencia financiera es alta con $libres días completamente tuyos."
          ];
          msg = opciones[_random.nextInt(opciones.length)];
          anim = AssistantAnimation.jump;
        } else {
          final opciones = [
            "Solo tienes $libres días libres. Trabajas mucho para pagar deudas. ¡Cámbialo!",
            "Hay que liberar tu tiempo. Trabajar la mayor parte del mes para pagar bancos no es vida.",
            "Tus compromisos consumen gran parte de tu mes. Vamos a intentar subir esos $libres días libres."
          ];
          msg = opciones[_random.nextInt(opciones.length)];
          anim = AssistantAnimation.shrink;
        }
        break;

      case 'resumen':
        final ingresos = (data['ingresos'] as num?)?.toDouble() ?? 0.0;
        final egresos = (data['egresos'] as num?)?.toDouble() ?? 0.0;
        
        if (ingresos > egresos) {
          final balance = ingresos - egresos;
          final opciones = [
            "Tus ingresos superan a los gastos. Tienes un sobrante de ${formatCOP(balance)}. ¡Excelente!",
            "Buen balance este mes. Con ${formatCOP(balance)} a favor, considera enviarlo a ahorros.",
            "Vamos bien, los ingresos son mayores. El flujo neto es positivo por ${formatCOP(balance)}."
          ];
          msg = opciones[_random.nextInt(opciones.length)];
          anim = AssistantAnimation.jump;
        } else if (egresos > ingresos) {
          final def = egresos - ingresos;
          final opciones = [
            "Cuidado: Tus gastos superan tus ingresos por ${formatCOP(def)}. Estás operando en rojo.",
            "La barra de gastos es más grande. Gastaste ${formatCOP(def)} más de lo que ganaste.",
            "¡Alerta! Tienes un déficit de ${formatCOP(def)} este mes. Revisa a dónde se fue el dinero."
          ];
          msg = opciones[_random.nextInt(opciones.length)];
          anim = AssistantAnimation.shake;
        } else {
          msg = "Estás en punto de equilibrio, lo que entra es igual a lo que sale. Ni frío ni calor.";
          anim = AssistantAnimation.nod;
        }
        break;

      case 'flujo_caja':
        final history = data['historical'] as List<dynamic>? ?? [];
        if (history.isNotEmpty) {
          final first = history.first as Map<String, dynamic>;
          final i = (first['ingresos'] as num?)?.toDouble() ?? 0.0;
          final e = (first['egresos'] as num?)?.toDouble() ?? 0.0;
          if (i > e) {
            msg = "El flujo de caja reciente muestra que retuviste liquidez. La barra de ingresos es dominante.";
          } else {
            msg = "El último mes el flujo fue negativo. La barra de gastos superó a la de ingresos, ¡cuidado!";
          }
        } else {
          final opciones = [
            "El flujo te muestra la tendencia. Trata de mantener la barra de ingresos por encima.",
            "Aquí vemos la evolución de tu dinero. Esperemos que el verde siempre supere al rojo."
          ];
          msg = opciones[_random.nextInt(opciones.length)];
        }
        anim = AssistantAnimation.stretch;
        break;

      case 'categorias':
        final opciones = [
          "¿A dónde se va el dinero? Aquí tienes los culpables por categoría.",
          "Revisa estas porciones. Siempre hay una categoría donde podemos recortar un poco.",
          "Analizar tus categorías de gasto es el primer paso para hacer un presupuesto realista."
        ];
        msg = opciones[_random.nextInt(opciones.length)];
        anim = AssistantAnimation.spin;
        break;

      case 'eficiencia_ahorro':
        final tasa = (data['tasa_ahorro'] as num?)?.toDouble() ?? 0;
        if (tasa >= 20) {
          final opciones = [
            "Tu tasa de ahorro es del $tasa%. ¡Eres un maestro del ahorro!",
            "Excelente capacidad de ahorro con un $tasa%. Tu yo del futuro estará muy agradecido.",
            "Guardar el $tasa% de tus ingresos demuestra gran disciplina. ¡Sigue así!"
          ];
          msg = opciones[_random.nextInt(opciones.length)];
          anim = AssistantAnimation.glowGreen;
        } else {
          final opciones = [
            "Tu tasa de ahorro es $tasa%. Intenta llevarla al 20% reduciendo gastos variables.",
            "Ahorras el $tasa%. Cualquier porcentaje es bueno, pero siempre se puede mejorar.",
            "¿Podríamos subir este $tasa% el próximo mes? Revisa los gastos hormiga."
          ];
          msg = opciones[_random.nextInt(opciones.length)];
          anim = AssistantAnimation.nod;
        }
        break;

      case 'radar_hormiga':
        final double anual = (data['total_anual'] as num?)?.toDouble() ?? 0.0;
        final lista = data['lista'] as List<dynamic>? ?? [];
        String topHormiga = "";
        if (lista.isNotEmpty) {
          topHormiga = lista.first['nombre'] ?? '';
        }
        
        if (topHormiga.isNotEmpty) {
          final opciones = [
            "Ese '$topHormiga' te está quitando liquidez constante. El total de fugas suma ${formatCOP(anual)} al año.",
            "El rey de las fugas es '$topHormiga'. En total, se te escapan ${formatCOP(anual)} al año.",
            "Tus pequeños gastos anualizan ${formatCOP(anual)}. Podrías invertir ese dinero en vez de gastarlo en '$topHormiga'."
          ];
          msg = opciones[_random.nextInt(opciones.length)];
        } else {
          msg = "Tienes fugas por ${formatCOP(anual)} al año. Esos micro-gastos terminan haciendo un agujero grande.";
        }
        anim = AssistantAnimation.flip;
        break;

      case 'dependencia_tarjetas':
        final double dependencia = (data['pct_ingresos_cuotas'] as num?)?.toDouble() ?? 0.0;
        final listaTc = data['lista'] as List<dynamic>? ?? [];
        String topBanco = "";
        if (listaTc.isNotEmpty) {
          topBanco = listaTc.first['banco'] ?? '';
        }

        if (dependencia > 25) {
          final opciones = [
            "Tus cuotas consumen el ${dependencia.toStringAsFixed(1)}% de tus ingresos. $topBanco se lleva una gran tajada.",
            "Con un ${dependencia.toStringAsFixed(1)}% de tus ingresos atados a cuotas, estás perdiendo liquidez.",
            "Mucha dependencia de tarjetas. Esa deuda con $topBanco limita tus movimientos mensuales."
          ];
          msg = opciones[_random.nextInt(opciones.length)];
          anim = AssistantAnimation.shake;
        } else {
          final opciones = [
            "Tus cuotas de tarjeta toman el ${dependencia.toStringAsFixed(1)}% de tus ingresos. Es manejable.",
            "Buena gestión del plástico. Tienes margen respecto a tus ingresos.",
            "Mientras no subas mucho del 20-25% de dependencia, estás seguro."
          ];
          msg = opciones[_random.nextInt(opciones.length)];
          anim = AssistantAnimation.nod;
        }
        break;

      case 'dias_trabajo':
        final double diasGastos = (data['dias_en_gastos_fijos'] as num?)?.toDouble() ?? 0.0;
        final double diasCuotas = (data['dias_en_cuotas_tarjeta'] as num?)?.toDouble() ?? 0.0;
        final double diasLibres = (data['dias_libres'] as num?)?.toDouble() ?? 0.0;

        if (diasLibres < 5) {
          final opciones = [
            "Trabajas casi todo el mes solo para obligaciones. ¡Solo te quedan ${diasLibres.toStringAsFixed(1)} días de tu ingreso mensual para ti!",
            "Tienes muy poca libertad. Solo ${diasLibres.toStringAsFixed(1)} días de tu esfuerzo laboral te pertenecen realmente.",
            "Cuidado, estás trabajando demasiado para los bancos. Necesitas liberar días reduciendo gastos fijos o cuotas."
          ];
          msg = opciones[_random.nextInt(opciones.length)];
          anim = AssistantAnimation.shake;
        } else if (diasCuotas > 10) {
          final opciones = [
            "Dedicas ${diasCuotas.toStringAsFixed(1)} días enteros de trabajo solo para pagar tarjetas. Intenta bajar esos abonos.",
            "Muchos días de tu trabajo se van directo al banco en cuotas. ¡Pilas con la tarjeta!"
          ];
          msg = opciones[_random.nextInt(opciones.length)];
          anim = AssistantAnimation.glitch;
        } else {
          final opciones = [
            "Tienes ${diasLibres.toStringAsFixed(1)} días libres. Ese es el fruto de tu trabajo que verdaderamente puedes disfrutar o invertir.",
            "Tu distribución de días es manejable. Procura siempre aumentar esos días libres.",
            "Interesante ver cómo distribuyes tu esfuerzo. ${diasLibres.toStringAsFixed(1)} días de libertad."
          ];
          msg = opciones[_random.nextInt(opciones.length)];
          anim = AssistantAnimation.nod;
        }
        break;

      default:
        final opciones = [
          "Esta gráfica te da otra perspectiva de tus números.",
          "Datos interesantes por aquí. Úsalos a tu favor.",
          "Mientras más analizas, mejores decisiones financieras tomas."
        ];
        msg = opciones[_random.nextInt(opciones.length)];
        anim = AssistantAnimation.idle;
    }

    state = AssistantState(message: msg, isVisible: true, isAction: true, animation: anim);
    _autoHide();
  }

  void analyzeCuota(double monto, String banco, double interes, [int? diaPago]) {
    String msg = "";
    AssistantAnimation anim = AssistantAnimation.stretch;
    String pagoText = diaPago != null && diaPago > 0 ? " Recuerda que toca pagar esta cuota alrededor del día $diaPago de este mes." : "";

    if (interes > 25) {
      final opciones = [
        "Esa tasa del $interes% en $banco es abusiva. Intenta comprar cartera.$pagoText",
        "Un interés del $interes% es altísimo. Esto está quemando tu dinero.$pagoText",
        "¡Alerta! Te están cobrando $interes% en $banco. Busca alternativas urgentemente.$pagoText"
      ];
      msg = opciones[_random.nextInt(opciones.length)];
      anim = AssistantAnimation.alert;
    } else {
      final opciones = [
        "Esta cuota en $banco tiene una tasa del $interes%, bastante manejable.$pagoText",
        "Mantén el ritmo de pagos, las condiciones en $banco están bajo control.$pagoText",
        "Es un crédito saludable dentro de lo normal, en $banco.$pagoText"
      ];
      msg = opciones[_random.nextInt(opciones.length)];
      anim = AssistantAnimation.nod;
    }
    state = AssistantState(message: msg, isVisible: true, isAction: true, animation: anim);
    _autoHide();
  }

  void analyzeCuotaIndividual(Map<String, dynamic> cuota) {
    String msg = "";
    AssistantAnimation anim = AssistantAnimation.nod;
    final estado = cuota['estado'] as String? ?? 'PENDIENTE';
    final numero = cuota['numero_cuota'];
    final capital = cuota['valor_capital'] as num? ?? 0;
    final interes = cuota['valor_interes'] as num? ?? 0;
    
    if (estado == 'PAGADA') {
      final opciones = [
        "Esta cuota ya está pagada. ¡Menos peso encima! 🎉",
        "Excelente, ya saliste de la cuota $numero.",
      ];
      msg = opciones[_random.nextInt(opciones.length)];
      anim = AssistantAnimation.happy;
    } else {
      String fechaStr = cuota['fecha_vencimiento']?.toString() ?? '';
      String dateInfo = '';
      if (fechaStr.length >= 10) {
        final partes = fechaStr.substring(0, 10).split('-');
        if (partes.length == 3) {
           dateInfo = " el ${partes[2]} de ${partes[1]}";
        }
      }
      
      if (interes > capital * 0.5) {
        msg = "¡Wow! En la cuota $numero estás pagando muchísimos intereses comparado con el capital. Toca pagarla$dateInfo.";
        anim = AssistantAnimation.alert;
      } else {
        msg = "La cuota $numero de esta compra la debes pagar$dateInfo. Trata de mantenerte al día para no generar mora.";
        anim = AssistantAnimation.nod;
      }
    }

    state = AssistantState(message: msg, isVisible: true, isAction: true, animation: anim);
    _autoHide();
  }

  void registerAction(String actionType, [double? amount, String? extraContext]) {
    String msg = "";
    AssistantAnimation anim = AssistantAnimation.idle;
    
    switch(actionType) {
      case 'NUEVO_GASTO':
        final frases = [
          "Otro gasto registrado. Espero que no haya sido un gasto hormiga.",
          "Gasto guardado. Vigilaré que no te pases del presupuesto este mes.",
          "Registrado. A veces hay que gastar, pero con responsabilidad.",
          amount != null && amount > 100000 
            ? "Vaya gasto grande. Espero que lo tuvieras planeado." 
            : "Pequeño gasto registrado. Recuerda que de a poco se llena el vaso o se vacía."
        ];
        msg = frases[_random.nextInt(frases.length)];
        final anims = [AssistantAnimation.shrink, AssistantAnimation.glowRed, AssistantAnimation.glitch, AssistantAnimation.flip];
        anim = anims[_random.nextInt(anims.length)];
        break;

      case 'GASTO_PAGADO':
        final frasesPagado = [
          "Gasto marcado como pagado. ¡Excelente responsabilidad!",
          "Una obligación menos. Buen trabajo manteniendo tus cuentas al día.",
          "¡Gasto pagado! Qué alivio ir saliendo de esas deudas mensuales."
        ];
        msg = frasesPagado[_random.nextInt(frasesPagado.length)];
        final animsPagado = [AssistantAnimation.happy, AssistantAnimation.jump, AssistantAnimation.glowGreen];
        anim = animsPagado[_random.nextInt(animsPagado.length)];
        break;

      case 'NUEVO_INGRESO':
        final frases = [
          "Dinero nuevo. Esto me pone muy feliz.",
          "Excelente. Más gasolina para nuestra salud financiera.",
          "Ingreso registrado. ¿Qué tal si guardamos un porcentaje en los ahorros?",
          "Aumentando reservas de liquidez. Buen trabajo."
        ];
        msg = frases[_random.nextInt(frases.length)];
        final anims = [AssistantAnimation.jump, AssistantAnimation.stretch, AssistantAnimation.glowGreen, AssistantAnimation.spin];
        anim = anims[_random.nextInt(anims.length)];
        break;

      case 'PAGO_TARJETA':
        final frases = [
          "Bien hecho. Pagar a tiempo te ahorra intereses.",
          "Un paso más para mantener ese historial crediticio impecable.",
          "Deuda reducida. Es una gran sensación.",
          "Pago registrado. Adiós a esos intereses abusivos."
        ];
        msg = frases[_random.nextInt(frases.length)];
        final anims = [AssistantAnimation.jump, AssistantAnimation.spin, AssistantAnimation.nod];
        anim = anims[_random.nextInt(anims.length)];
        break;

      default:
        msg = "He tomado nota de eso.";
        anim = AssistantAnimation.idle;
    }

    state = AssistantState(message: msg, isVisible: true, isAction: true, animation: anim);
    _autoHide();
  }

  void _analyzeDashboardData(Map<String, dynamic> response) {
    if (response['ok'] != true) return;
    
    final data = response['data'] as Map<String, dynamic>;
    final currentHash = data.toString().hashCode.toString();
    if (_lastDashboardDataHash == currentHash) return;
    _lastDashboardDataHash = currentHash;

    final cap = data['capacidad_crediticia'] as Map<String, dynamic>;
    final pctEndeudamiento = (cap['porcentaje_endeudamiento'] as num).toDouble();
    final liquidez = (cap['liquidez_disponible'] as num).toDouble();
    
    String newMessage = _generateMessage(pctEndeudamiento, liquidez);
    
    state = AssistantState(message: newMessage, isVisible: true, isAction: false);
    _autoHide();
  }

  String _generateMessage(double endeudamiento, double liquidez) {
    List<String> options = [];

    if (endeudamiento > 60) {
      options.add("Tu nivel de endeudamiento está por encima del 60%. Es hora de congelar esas tarjetas.");
    }
    if (liquidez > 500000 && endeudamiento < 30) {
      options.add("Tu liquidez se ve excelente este mes. ¿Has pensado en mover algo a tu bolsillo de ahorros?");
    } else if (liquidez < 0) {
      options.add("Tus gastos fijos y deudas superan tus ingresos mensuales. Necesitas revisar tu presupuesto urgentemente.");
    }

    if (options.isEmpty) {
      options.addAll([
        "Todo parece estar en orden por aquí. Sigue registrando tus movimientos.",
        "Aquí estoy analizando tus datos. Tu salud financiera parece estable hoy.",
        "Recuerda categorizar bien tus gastos para que mis análisis sean más precisos."
      ]);
    }
    return options[_random.nextInt(options.length)];
  }

  void setCurrentView(String viewName) {
    if (state.isAction && state.isVisible) return; 

    final Map<String, List<String>> viewMessages = {
      'dashboard': [
        "Aquí está el resumen de todo. ¿Cómo vas con el presupuesto de este mes?",
        "Vista general lista. Tus números cuentan una historia, ¿la ves?",
        "Panel principal activo. ¿Listo para ver la realidad de tus bolsillos?",
        "Bienvenido a la cabina de mando. Vigilemos de cerca esos saldos."
      ],
      'gastos': [
        "En gastos. Recuerda: cada peso que sale, se registra aquí.",
        "El control de gastos es el primer paso para ahorrar más.",
        "Registremos esos pagos. No dejes escapar nada, ni los chicles.",
        "Gastos. Aquí es donde ponemos a prueba tu disciplina financiera."
      ],
      'ingresos': [
        "Área de ingresos. Aquí entra el dinero.",
        "Registrar ingresos te ayuda a saber exactamente con cuánto cuentas.",
        "Más ingresos, más oportunidades. Asegúrate de categorizarlos bien.",
        "Tu fuente de poder. ¿Hubo algún dinerito extra este mes?"
      ],
      'analitica': [
        "Modo analítico activado. Toca cualquiera de las gráficas para que te dé un análisis detallado.",
        "Los números no mienten. Toca una tarjeta para interpretar los datos.",
        "Amo esta sección. Aquí vemos si realmente estás ahorrando o no.",
        "Veamos tu salud en profundidad. Presiona un gráfico para escuchar mi opinión."
      ],
      'tarjetas': [
        "Gestión de tarjetas de crédito. Toca una cuota para ver qué opino.",
        "Aquí vemos tus tarjetas. Cuidado con el interés.",
        "El plástico puede ser un aliado o un enemigo. Revisemos esos saldos.",
        "Ojo con las compras a muchas cuotas. Mantenlas a raya."
      ],
      'ahorros': [
        "Tus metas y bolsillos de ahorro. ¡Esta es la mejor parte!",
        "Aquí construimos tu futuro financiero paso a paso.",
        "Ahorrar es pagarte a ti primero. ¿Cómo van esas metas?",
        "El dinero que siembras hoy es tu tranquilidad de mañana."
      ],
      'suscripciones': [
        "Tus suscripciones. A veces pagamos por cosas que no usamos, ¡revisa bien!",
        "Los gastos hormiga recurrentes están aquí. Mantén el control.",
        "¿Netflix, Spotify, Gym? Verifica si realmente los estás usando todos.",
        "Las suscripciones suman rápido. Cancela las que ya no necesitas."
      ],
      'cobrar': [
        "Dinero que te deben o que debes. Mantén tus cuentas claras.",
        "Préstamos y deudas personales. Que no se te escape ninguna.",
        "Cuentas claras conservan amistades. Gestiona tus deudas con terceros aquí."
      ],
    };

    final Map<String, AssistantAnimation> viewAnims = {
      'dashboard': AssistantAnimation.spin,
      'gastos': AssistantAnimation.shrink,
      'ingresos': AssistantAnimation.jump,
      'analitica': AssistantAnimation.stretch,
      'tarjetas': AssistantAnimation.shake,
      'ahorros': AssistantAnimation.glowGreen,
      'suscripciones': AssistantAnimation.glitch,
      'cobrar': AssistantAnimation.flip,
    };

    final frases = viewMessages[viewName];
    if (frases == null) return;

    final msg = frases[_random.nextInt(frases.length)];
    state = AssistantState(
      message: msg, 
      isVisible: true, 
      isAction: false, 
      animation: viewAnims[viewName] ?? AssistantAnimation.idle,
    );
    _autoHide();
  }

  void toggleVisibility() {
    state = state.copyWith(isVisible: !state.isVisible);
    if (state.isVisible) {
      _autoHide();
    }
  }

  void hideMessage() {
    state = state.copyWith(isVisible: false);
  }

  void showMessage(String msg) {
    state = AssistantState(message: msg, isVisible: true, isAction: false);
    _autoHide();
  }

  void _autoHide([int? seconds]) {
    final currentMsg = state.message;
    // Base 2 seconds, plus 1 second for every 25 characters, capped at 6 seconds
    final int calcSeconds = seconds ?? (2 + (currentMsg.length / 25).ceil()).clamp(3, 6);
    Future.delayed(Duration(seconds: calcSeconds), () {
      if (state.message == currentMsg) {
        hideMessage();
      }
    });
  }
}

final virtualAssistantProvider = NotifierProvider<VirtualAssistantNotifier, AssistantState>(() {
  return VirtualAssistantNotifier();
});
