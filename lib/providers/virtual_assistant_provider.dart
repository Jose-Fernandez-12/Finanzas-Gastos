import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dashboard_provider.dart';
import '../core/formatters.dart';

enum AssistantAnimation {
  idle, jump, shake, stretch, shrink, spin, flip, glowGreen, glowRed, nod, glitch
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

  @override
  AssistantState build() {
    ref.listen(dashboardProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        if (!state.isAction || !state.isVisible) {
          _analyzeDashboardData(next.value!);
        }
      }
    });

    return AssistantState(message: "Iniciando sistemas financieros...", isVisible: false);
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
    _autoHide(8);
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
          msg = "Estás en déficit. Tienes menos de lo necesario para cubrir tus gastos. Frena todo gasto no esencial inmediatamente.";
          anim = AssistantAnimation.shake;
        } else if (estado == 'Ajustado') {
          msg = "Tu presupuesto está muy ajustado. Tienes un disponible real de ${formatCOP(disponible)}. No te excedas de ${formatCOP(diario)} por día.";
          anim = AssistantAnimation.shrink;
        } else {
          msg = "Tu salud financiera es buena. Puedes gastar hasta ${formatCOP(diario)} al día sin afectar tus compromisos. Excelente trabajo.";
          anim = AssistantAnimation.jump;
        }
        break;

      case 'camino_cero_deuda':
        final mesLibre = data['mesLibreDeDeuda']?.toString() ?? 'pronto';
        msg = "Si mantienes este nivel de pagos y abonos extra, proyectamos que serás completamente libre de deudas en $mesLibre. Sigue así.";
        anim = AssistantAnimation.stretch;
        break;

      case 'interes_quemado':
        final double pctIngresos = (data['pct_de_ingresos'] as num?)?.toDouble() ?? 0.0;
        final double totalAnual = (data['total_anual'] as num?)?.toDouble() ?? 0.0;
        
        if (pctIngresos > 10) {
          msg = "Estás quemando un $pctIngresos% de tus ingresos solo en intereses. Es urgente consolidar o refinanciar esa deuda.";
          anim = AssistantAnimation.shake;
        } else {
          msg = "El banco se está llevando ${formatCOP(totalAnual)} tuyos al año. Considera hacer abonos a capital para reducir esto.";
          anim = AssistantAnimation.nod;
        }
        break;
        
      case 'estres_efectivo':
        final bool alerta = data['alerta'] as bool? ?? false;
        final int diaPico = data['dia_pico'] as int? ?? 15;
        
        if (alerta) {
          msg = "Atención: Hay alta presión financiera alrededor del día $diaPico. Guarda liquidez antes de esa fecha.";
          anim = AssistantAnimation.glitch;
        } else {
          msg = "Tu flujo de pagos está bien distribuido este mes. No veo días de estrés extremo.";
          anim = AssistantAnimation.nod;
        }
        break;
        
      case 'endeudamiento':
        final double pct = (data['pct'] as num?)?.toDouble() ?? 0.0;
        if (pct > 60) {
          msg = "Tu endeudamiento está en un ${pct.toStringAsFixed(1)}%. Es un nivel crítico que limita tu libertad financiera.";
          anim = AssistantAnimation.shake;
        } else {
          msg = "Tienes un endeudamiento del ${pct.toStringAsFixed(1)}%. Mantenlo bajo control.";
          anim = AssistantAnimation.nod;
        }
        break;
      case 'esclavitud_financiera':
        final libres = (data['dias_libres'] as num?)?.toDouble() ?? 0;
        if (libres > 15) {
          msg = "¡Tienes $libres días libres! Eres dueño de la mayor parte de tu mes. Excelente.";
          anim = AssistantAnimation.jump;
        } else {
          msg = "Trabajas muchos días solo para pagar obligaciones. Tienes $libres días libres. ¡Hay que liberar tu tiempo!";
          anim = AssistantAnimation.shrink;
        }
        break;
      case 'resumen':
        msg = "Tus ingresos y gastos del mes en un vistazo. Si la barra de ingresos es más grande, vamos bien.";
        anim = AssistantAnimation.nod;
        break;
      case 'flujo_caja':
        msg = "El flujo de caja te muestra la tendencia. Trata de mantener la barra verde siempre encima de la roja.";
        anim = AssistantAnimation.stretch;
        break;
      case 'categorias':
        msg = "Aquí puedes ver a dónde se va tu dinero exactamente. ¿Hay alguna categoría que te sorprenda?";
        anim = AssistantAnimation.spin;
        break;
      case 'eficiencia_ahorro':
        final tasa = (data['tasa_ahorro'] as num?)?.toDouble() ?? 0;
        if (tasa >= 20) {
          msg = "Tu tasa de ahorro es del $tasa%. ¡Eres un maestro del ahorro!";
          anim = AssistantAnimation.glowGreen;
        } else {
          msg = "Tu tasa de ahorro es $tasa%. Intenta llevarla al menos al 20% reduciendo gastos variables.";
          anim = AssistantAnimation.nod;
        }
        break;
      default:
        msg = "He analizado esta gráfica. Estos números te ayudan a entender mejor tus finanzas.";
        anim = AssistantAnimation.idle;
    }

    state = AssistantState(message: msg, isVisible: true, isAction: true, animation: anim);
    _autoHide(8);
  }

  void analyzeCuota(double monto, String banco, double interes) {
    String msg = "";
    AssistantAnimation anim = AssistantAnimation.stretch;
    if (interes > 25) {
      msg = "Esa tasa de interés del $interes% en $banco es muy alta. Considera comprar esa cartera.";
      anim = AssistantAnimation.shake;
    } else {
      msg = "Esta cuota en $banco es manejable. Mantén el ritmo de pagos.";
      anim = AssistantAnimation.nod;
    }
    state = AssistantState(message: msg, isVisible: true, isAction: true, animation: anim);
    _autoHide(8);
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
    _autoHide(8);
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
    _autoHide(12);
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
      ],
      'gastos': [
        "En gastos. Recuerda: cada peso que sale, se registra aquí.",
        "El control de gastos es el primer paso para ahorrar más.",
      ],
      'ingresos': [
        "Área de ingresos. Aquí entra el dinero.",
        "Registrar ingresos te ayuda a saber exactamente con cuánto cuentas.",
      ],
      'analitica': [
        "Modo analítico activado. Toca cualquiera de las gráficas para que te dé un análisis detallado.",
        "Los números no mienten. Toca una tarjeta para interpretar los datos.",
      ],
      'tarjetas': [
        "Gestión de tarjetas de crédito. Toca una cuota para ver qué opino.",
        "Aquí vemos tus tarjetas. Cuidado con el interés.",
      ],
      'ahorros': [
        "Tus metas y bolsillos de ahorro. ¡Esta es la mejor parte!",
        "Aquí construimos tu futuro financiero paso a paso.",
      ],
      'suscripciones': [
        "Tus suscripciones. A veces pagamos por cosas que no usamos, ¡revisa bien!",
        "Los gastos hormiga recurrentes están aquí. Mantén el control.",
      ],
      'cobrar': [
        "Dinero que te deben o que debes. Mantén tus cuentas claras.",
        "Préstamos y deudas personales. Que no se te escape ninguna.",
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
    _autoHide(10);
  }

  void toggleVisibility() {
    state = state.copyWith(isVisible: !state.isVisible);
    if (state.isVisible) {
      _autoHide(10);
    }
  }

  void hideMessage() {
    state = state.copyWith(isVisible: false);
  }

  void showMessage(String msg) {
    state = AssistantState(message: msg, isVisible: true, isAction: false);
    _autoHide(8);
  }

  void _autoHide(int seconds) {
    final currentMsg = state.message;
    Future.delayed(Duration(seconds: seconds), () {
      if (state.message == currentMsg) {
        hideMessage();
      }
    });
  }
}

final virtualAssistantProvider = NotifierProvider<VirtualAssistantNotifier, AssistantState>(() {
  return VirtualAssistantNotifier();
});
