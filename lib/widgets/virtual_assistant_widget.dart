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
  // Posición inicial (abajo a la derecha)
  double _x = 0;
  double _y = 0;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final size = MediaQuery.of(context).size;
      _x = size.width - 70;
      _y = size.height - 180;
      _initialized = true;
    }
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
            if (state.isVisible)
              Positioned(
                bottom: 60,
                right: (_x > size.width / 2) ? 0 : null,
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
                        color: const Color(0xFF1E1E1E), 
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
                              Text('Rocky', style: AppTheme.monoStyle(color: const Color(0xFFD4B886), fontSize: 11)),
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

            SizedBox(
              width: 72,
              child: ClawdWidget(animation: state.animation),
            ),
          ],
        ),
      ),
    );
  }
}

class ClawdWidget extends StatefulWidget {
  final AssistantAnimation animation;
  const ClawdWidget({super.key, this.animation = AssistantAnimation.idle});

  @override
  State<ClawdWidget> createState() => _ClawdWidgetState();
}

class _ClawdWidgetState extends State<ClawdWidget> with TickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final AnimationController _blinkController;
  late final AnimationController _actionController;
  bool _disposed = false;
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 160));
    _actionController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    
    _scheduleNextBlink();
    if (widget.animation != AssistantAnimation.idle) {
      _actionController.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(ClawdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animation != oldWidget.animation && widget.animation != AssistantAnimation.idle) {
      _actionController.forward(from: 0.0);
    }
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
    _actionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 72 / 48,
      child: AnimatedBuilder(
        animation: Listenable.merge([_bounceController, _blinkController, _actionController]),
        builder: (context, _) {
          final bounce = Curves.easeInOut.transform(_bounceController.value);
          final action = _actionController.value;
          final isActing = _actionController.isAnimating || action > 0 && action < 1;
          
          double dx = 0;
          double dy = -bounce * 2;
          double scaleX = 1.0;
          double scaleY = 1.0;
          Color? glowColor;

          if (isActing) {
            final sinPi = math.sin(action * math.pi);
            switch (widget.animation) {
              case AssistantAnimation.jump:
                dy -= sinPi * 15;
                break;
              case AssistantAnimation.shake:
                dx += math.sin(action * math.pi * 6) * 4;
                break;
              case AssistantAnimation.stretch:
                scaleY += sinPi * 0.3;
                scaleX -= sinPi * 0.1;
                break;
              case AssistantAnimation.shrink:
                scaleY -= sinPi * 0.3;
                scaleX += sinPi * 0.1;
                break;
              case AssistantAnimation.nod:
                dy += math.sin(action * math.pi * 2) * 3;
                break;
              case AssistantAnimation.glitch:
                dx += (_random.nextDouble() - 0.5) * 6 * sinPi;
                dy += (_random.nextDouble() - 0.5) * 6 * sinPi;
                break;
              case AssistantAnimation.glowGreen:
                glowColor = Colors.greenAccent.withAlpha((sinPi * 200).toInt());
                dy -= sinPi * 5; // pequeño salto también
                break;
              case AssistantAnimation.glowRed:
                glowColor = Colors.redAccent.withAlpha((sinPi * 200).toInt());
                dx += math.sin(action * math.pi * 4) * 2; // pequeña sacudida
                break;
              case AssistantAnimation.spin:
                // Simulamos spin haciendo shrink horizontal y volviendo
                scaleX = math.cos(action * math.pi * 2).abs();
                break;
              default:
                break;
            }
          }

          return Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              ..translate(dx, dy)
              ..scale(scaleX, scaleY),
            child: CustomPaint(
              size: Size.infinite,
              painter: _ClawdPainter(blink: _blinkController.value, glowColor: glowColor),
            ),
          );
        },
      ),
    );
  }
}

class _ClawdPainter extends CustomPainter {
  final double blink; 
  final Color? glowColor;

  _ClawdPainter({required this.blink, this.glowColor});

  static const Color body = Color(0xFF6C63FF);
  static const Color eye = Color(0xFF111111);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 72;
    canvas.save();
    canvas.scale(scale, scale);

    final paint = Paint()..isAntiAlias = false;
    
    if (glowColor != null) {
      paint.imageFilter = null;
      // Añadir sombra para el glow
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 72, 48), 
        Paint()..color = glowColor!..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
      );
    }

    void rect(double x, double y, double w, double h, Color c) {
      paint.color = c;
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint);
    }

    rect(9, 0, 54, 10, body);
    rect(9, 10, 54, 9, body);
    rect(0, 19, 72, 10, body);
    rect(9, 29, 54, 9, body);
    rect(13, 38, 5, 10, body);
    rect(22, 38, 5, 10, body);
    rect(45, 38, 4, 10, body);
    rect(54, 38, 4, 10, body);

    final eyeH = 9 * (1 - blink);
    final eyeY = 10 + (9 - eyeH) / 2;
    rect(18, eyeY, 4, eyeH, eye);
    rect(49, eyeY, 5, eyeH, eye);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ClawdPainter old) => old.blink != blink || old.glowColor != glowColor;
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
