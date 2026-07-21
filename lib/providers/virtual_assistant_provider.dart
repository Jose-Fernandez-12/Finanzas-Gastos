import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dashboard_provider.dart';

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
    // Escuchar los cambios del dashboard para análisis general
    ref.listen(dashboardProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        // Solo analizamos el dashboard si no estamos mostrando un mensaje de acción
        if (!state.isAction || !state.isVisible) {
          _analyzeDashboardData(next.value!);
        }
      }
    });

    return AssistantState(message: "Iniciando sistemas financieros...", isVisible: false);
  }

  void registerAction(String actionType, [double? amount, String? extraContext]) {
    String msg = "";
    AssistantAnimation anim = AssistantAnimation.idle;
    
    switch(actionType) {
      case 'NUEVO_GASTO':
        final frases = [
          "Malo malo malo. Dinero ido. Duele billetera.",
          "Gasto nuevo. ¿Por qué salir dinero, pregunta?",
          "Registrado. Cuidar dinero es importante importante importante.",
          "Dinero gastado. Yo vigilo presupuesto. No gastar más.",
          amount != null && amount > 100000 
            ? "Malo malo malo. Gasto muy grande. ¿Estaba planeado, pregunta?" 
            : "Gasto pequeño. Muchos gastos pequeños hacen vaso vacío."
        ];
        msg = frases[_random.nextInt(frases.length)];
        final anims = [AssistantAnimation.shake, AssistantAnimation.shrink, AssistantAnimation.glowRed, AssistantAnimation.glitch, AssistantAnimation.flip];
        anim = anims[_random.nextInt(anims.length)];
        break;

      case 'NUEVO_INGRESO':
        final frases = [
          "Feliz feliz feliz. Dinero nuevo. Buen trabajo.",
          "Dinero entra. Salud financiera sube sube sube.",
          "Ingreso listo. ¿Guardar porcentaje en ahorro, pregunta?",
          "Bien bien bien. Día grande para finanzas."
        ];
        msg = frases[_random.nextInt(frases.length)];
        final anims = [AssistantAnimation.jump, AssistantAnimation.stretch, AssistantAnimation.glowGreen, AssistantAnimation.spin, AssistantAnimation.nod];
        anim = anims[_random.nextInt(anims.length)];
        break;

      case 'PAGO_TARJETA':
        final frases = [
          "Bien hecho. Pagar a tiempo evita intereses. Inteligente inteligente inteligente.",
          "Deuda baja. Historial sube. Buen humano.",
          "Sentimiento bueno. Deuda pequeña ahora, ¿verdad pregunta?"
        ];
        msg = frases[_random.nextInt(frases.length)];
        final anims = [AssistantAnimation.jump, AssistantAnimation.spin, AssistantAnimation.nod];
        anim = anims[_random.nextInt(anims.length)];
        break;

      case 'NUEVO_AHORRO':
        final frases = [
          "Feliz feliz feliz. Pagar a ti mismo es mejor inversión.",
          "Meta cerca. Seguir así es bueno bueno bueno.",
          "Ahorrar necesita disciplina. Tú tienes disciplina."
        ];
        msg = frases[_random.nextInt(frases.length)];
        final anims = [AssistantAnimation.jump, AssistantAnimation.nod, AssistantAnimation.stretch, AssistantAnimation.glowGreen];
        anim = anims[_random.nextInt(anims.length)];
        break;

      case 'NUEVA_DEUDA_A_COBRAR':
        final frases = [
          "Dinero prestado. Yo vigilo. Espero devuelvan pronto.",
          "Anotado. ¿Recuerdas cobrar en fecha, pregunta?"
        ];
        msg = frases[_random.nextInt(frases.length)];
        final anims = [AssistantAnimation.shrink, AssistantAnimation.nod];
        anim = anims[_random.nextInt(anims.length)];
        break;
        
      case 'COBRO_RECIBIDO':
        final frases = [
          "¡Dinero vuelve! Pago recibido. Bien bien bien.",
          "Justicia ocurre. Deuda saldada. Feliz."
        ];
        msg = frases[_random.nextInt(frases.length)];
        final anims = [AssistantAnimation.glowGreen, AssistantAnimation.spin, AssistantAnimation.jump];
        anim = anims[_random.nextInt(anims.length)];
        break;

      default:
        msg = "Nota tomada. Entendido.";
        anim = AssistantAnimation.idle;
    }

    state = AssistantState(message: msg, isVisible: true, isAction: true, animation: anim);
    
    // Auto ocultar más rápido para acciones
    Future.delayed(const Duration(seconds: 8), () {
      if (state.message == msg) {
        hideMessage();
      }
    });
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
    
    final cuentasMora = data['cuentas_en_mora'] as List<dynamic>;
    final proximasCuotas = data['proximas_cuotas'] as List<dynamic>;

    String newMessage = _generateMessage(pctEndeudamiento, liquidez, cuentasMora, proximasCuotas);
    
    state = AssistantState(message: newMessage, isVisible: true, isAction: false);
    
    Future.delayed(const Duration(seconds: 12), () {
      if (state.message == newMessage) {
        hideMessage();
      }
    });
  }

  String _generateMessage(double endeudamiento, double liquidez, List<dynamic> mora, List<dynamic> cuotas) {
    List<String> options = [];

    if (endeudamiento > 60) {
      options.add("Tu nivel de endeudamiento está por encima del 60%. ¡Es hora de congelar esas tarjetas!");
      options.add("Alerta roja con las deudas. Te recomiendo no registrar más gastos innecesarios este mes.");
    }

    if (mora.isNotEmpty) {
      options.add("Veo que tienes deudores en mora. ¡No dejes que se queden con tu dinero, hazles un cobro amigable!");
    }

    if (liquidez > 500000 && endeudamiento < 30) {
      options.add("Tu liquidez se ve excelente este mes. ¿Has pensado en mover algo a tu bolsillo de ahorros?");
    } else if (liquidez < 0) {
      options.add("Tus gastos fijos y deudas superan tus ingresos mensuales. Necesitas revisar tu presupuesto urgentemente.");
    }

    int cuotasCercanas = 0;
    final now = DateTime.now();
    for (var c in cuotas) {
      final f = DateTime.tryParse(c['fecha_vencimiento']?.toString() ?? '');
      if (f != null && f.difference(now).inDays <= 5) {
        cuotasCercanas++;
      }
    }

    if (cuotasCercanas > 0) {
      options.add("Tienes $cuotasCercanas cuota(s) a punto de vencer. Que no se te pase la fecha de pago.");
    }

    if (options.isEmpty) {
      options.addAll([
        "Todo parece estar en orden por aquí. Sigue registrando tus movimientos.",
        "Aquí estoy analizando tus datos. Tu salud financiera parece estable hoy.",
        "Recuerda categorizar bien tus gastos para que mis análisis sean más precisos.",
        "Un buen control financiero te dará paz mental. ¡Vas por buen camino!"
      ]);
    }

    return options[_random.nextInt(options.length)];
  }

  void toggleVisibility() {
    state = state.copyWith(isVisible: !state.isVisible);
    if (state.isVisible) {
      Future.delayed(const Duration(seconds: 10), () {
        if (state.isVisible) hideMessage();
      });
    }
  }

  void hideMessage() {
    state = state.copyWith(isVisible: false);
  }

  void showMessage(String msg) {
    state = AssistantState(message: msg, isVisible: true, isAction: false);
    Future.delayed(const Duration(seconds: 8), () {
      if (state.message == msg) hideMessage();
    });
  }
}

final virtualAssistantProvider = NotifierProvider<VirtualAssistantNotifier, AssistantState>(() {
  return VirtualAssistantNotifier();
});
