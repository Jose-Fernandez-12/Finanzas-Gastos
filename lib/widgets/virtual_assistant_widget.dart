import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/virtual_assistant_provider.dart';
import '../core/theme.dart';

class GlobalVirtualAssistant extends ConsumerStatefulWidget {
  const GlobalVirtualAssistant({super.key});

  @override
  ConsumerState<GlobalVirtualAssistant> createState() => _GlobalVirtualAssistantState();
}

class _GlobalVirtualAssistantState extends ConsumerState<GlobalVirtualAssistant> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  // Posición inicial (abajo a la derecha)
  double _x = 0;
  double _y = 0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final size = MediaQuery.of(context).size;
      // Posicionar inicialmente en la esquina inferior derecha, dejando espacio para la nav bar
      _x = size.width - 70;
      _y = size.height - 180;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(virtualAssistantProvider);
    final size = MediaQuery.of(context).size;

    return Positioned(
      left: _x,
      top: _y,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _x += details.delta.dx;
            _y += details.delta.dy;
            
            // Mantener dentro de los limites de la pantalla
            if (_x < 0) _x = 0;
            if (_x > size.width - 50) _x = size.width - 50;
            if (_y < 40) _y = 40;
            if (_y > size.height - 100) _y = size.height - 100;
          });
        },
        onTap: () => ref.read(virtualAssistantProvider.notifier).toggleVisibility(),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomRight,
          children: [
            // Burbuja de chat flotante
            if (state.isVisible)
              Positioned(
                bottom: 60, // Encima del marciano
                right: (_x > size.width / 2) ? 0 : null, // Mostrar hacia la izquierda o derecha segun posicion
                left: (_x <= size.width / 2) ? 0 : null,
                child: Material(
                  color: Colors.transparent,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: state.isVisible ? 1.0 : 0.0,
                    child: Container(
                      width: size.width * 0.65,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E), // Dark terminal style
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular((_x <= size.width / 2) ? 4 : 16),
                          bottomRight: Radius.circular((_x > size.width / 2) ? 4 : 16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(40),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: const Color(0xFF333333)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.smart_toy_rounded, color: Color(0xFFD4B886), size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'Asistente 8-Bit',
                                style: AppTheme.monoStyle(color: const Color(0xFFD4B886), fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TypingText(
                            text: state.message,
                            style: const TextStyle(
                              color: Color(0xFFE5E5E5),
                              fontSize: 13,
                              height: 1.4,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // El Avatar animado Pixel Art
            SizedBox(
              width: 72,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const ClawdWidget(),
                  if (state.isVisible && state.themeIcon != null)
                    Positioned(
                      top: -5,
                      right: -5,
                      child: Text(
                        state.themeIcon!,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mascota Clawd animada. Mantiene la proporcion 3:2 (72x48) del pixel art
/// original sin importar el tamano en el que se use.
///
/// Uso:
///   SizedBox(width: 120, child: ClawdWidget())
class ClawdWidget extends StatefulWidget {
  const ClawdWidget({super.key});

  @override
  State<ClawdWidget> createState() => _ClawdWidgetState();
}

class _ClawdWidgetState extends State<ClawdWidget>
    with TickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final AnimationController _blinkController;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();

    // Idle bounce: loop continuo, sube y baja.
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // Parpadeo: dispara en momentos aleatorios, no en loop fijo.
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _scheduleNextBlink();
  }

  void _scheduleNextBlink() {
    final waitMs = 2200 + (DateTime.now().millisecondsSinceEpoch % 1800);
    Future.delayed(Duration(milliseconds: waitMs), () async {
      if (_disposed || !mounted) return;
      await _blinkController.forward();
      if (_disposed || !mounted) return;
      await _blinkController.reverse();
      _scheduleNextBlink();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _bounceController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AspectRatio bloquea el 3:2 (72:48) sin importar el ancho que le den
    // desde afuera (SizedBox, Expanded, etc). Nunca lo envuelvas en algo
    // que fuerce un alto distinto sin pasar por aca.
    return AspectRatio(
      aspectRatio: 72 / 48,
      child: AnimatedBuilder(
        animation: Listenable.merge([_bounceController, _blinkController]),
        builder: (context, _) {
          final bounce = Curves.easeInOut.transform(_bounceController.value);
          return Transform.translate(
            offset: Offset(0, -bounce * 2), // solo eje Y, nunca escala X/Y por separado
            child: CustomPaint(
              size: Size.infinite,
              painter: _ClawdPainter(blink: _blinkController.value),
            ),
          );
        },
      ),
    );
  }
}

class _ClawdPainter extends CustomPainter {
  final double blink; // 0 = ojos abiertos, 1 = ojos cerrados

  _ClawdPainter({required this.blink});

  static const Color body = Color(0xFFD77757);
  static const Color eye = Color(0xFF111111);

  @override
  void paint(Canvas canvas, Size size) {
    // Escala uniforme: el mismo factor para X e Y. Escalarlos distinto
    // deforma el sprite y rompe las proporciones.
    final scale = size.width / 72;
    canvas.save();
    canvas.scale(scale, scale);

    final paint = Paint()..isAntiAlias = false; // bordes nitidos, sin blur

    void rect(double x, double y, double w, double h, Color c) {
      paint.color = c;
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint);
    }

    // Cuerpo (coordenadas de la cuadricula original 72x48)
    rect(9, 0, 54, 10, body);
    rect(9, 10, 54, 9, body);
    rect(0, 19, 72, 10, body);
    rect(9, 29, 54, 9, body);
    rect(13, 38, 5, 10, body);
    rect(22, 38, 5, 10, body);
    rect(45, 38, 4, 10, body);
    rect(54, 38, 4, 10, body);

    // Ojos: la altura se reduce hacia el centro vertical cuando blink -> 1
    final eyeH = 9 * (1 - blink);
    final eyeY = 10 + (9 - eyeH) / 2;
    rect(18, eyeY, 4, eyeH, eye);
    rect(49, eyeY, 5, eyeH, eye);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ClawdPainter old) => old.blink != blink;
}

class TypingText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration typingSpeed;

  const TypingText({
    super.key,
    required this.text,
    required this.style,
    this.typingSpeed = const Duration(milliseconds: 30),
  });

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText> {
  String _displayedText = '';
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  @override
  void didUpdateWidget(TypingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _startTyping();
    }
  }

  void _startTyping() {
    _timer?.cancel();
    _displayedText = '';
    _currentIndex = 0;

    _timer = Timer.periodic(widget.typingSpeed, (timer) {
      if (_currentIndex < widget.text.length) {
        setState(() {
          _displayedText += widget.text[_currentIndex];
          _currentIndex++;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '$_displayedText${_currentIndex < widget.text.length ? '▊' : ''}',
      style: widget.style,
    );
  }
}


