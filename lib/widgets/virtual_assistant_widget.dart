import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      _x = size.width - 75;
      _y = size.height - 180;
      _initialized = true;
    }
  }

  void _snapToEdge(Size size) {
    setState(() {
      if (_x > size.width / 2) {
        _x = size.width - 75; // Borde derecho
      } else {
        _x = 0; // Borde izquierdo
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(virtualAssistantProvider);
    final size = MediaQuery.of(context).size;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    double displayY = _y;
    double displayX = _x;

    if (isKeyboardOpen) {
      displayY = 50; 
      displayX = size.width - 75; 
    } else {
      if (_y > size.height - 100) _y = size.height - 100;
      if (_x > size.width - 75) _x = size.width - 75;
    }

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutQuint,
      left: displayX,
      top: displayY,
      child: IgnorePointer(
        ignoring: isKeyboardOpen,
        child: GestureDetector(
          onPanUpdate: (details) {
            if (isKeyboardOpen) return;
            setState(() {
              _x += details.delta.dx;
              _y += details.delta.dy;
              if (_x < 0) _x = 0;
              if (_x > size.width - 75) _x = size.width - 75;
              if (_y < 40) _y = 40;
              if (_y > size.height - 100) _y = size.height - 100;
            });
          },
          onPanEnd: (details) {
            if (!isKeyboardOpen) _snapToEdge(size);
          },
          onTap: () => ref.read(virtualAssistantProvider.notifier).toggleVisibility(),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: (isKeyboardOpen && !state.isAction) ? 0.25 : 1.0,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomRight,
              children: [
                if (state.isVisible && (!isKeyboardOpen || state.isAction))
                  Positioned(
                    bottom: 60,
                    right: (displayX > size.width / 2) ? 0 : null,
                    left: (displayX <= size.width / 2) ? 0 : null,
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
                                  const Icon(Icons.smart_toy_rounded, color: AppTheme.primary, size: 14),
                                  const SizedBox(width: 6),
                                  Text('Rocky', style: AppTheme.monoStyle(color: AppTheme.primary, fontSize: 11)),
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
                  child: ClawdWidget(animation: state.animation, actionId: state.actionId),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ClawdWidget extends StatefulWidget {
  final AssistantAnimation animation;
  final String actionId;
  const ClawdWidget({super.key, this.animation = AssistantAnimation.idle, this.actionId = ''});

  @override
  State<ClawdWidget> createState() => _ClawdWidgetState();
}

class _ClawdWidgetState extends State<ClawdWidget> with TickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final AnimationController _blinkController;
  late final AnimationController _actionController;
  bool _disposed = false;
  final _random = math.Random();
  AssistantAnimation _currentIdleAnim = AssistantAnimation.idle;
  
  // Parametros para vuelo aleatorio
  double _flyTargetX = 0;
  double _flyPeakY = 0;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 160));
    _actionController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    
    _scheduleNextBlink();
    _scheduleNextIdleAction();
    if (widget.animation != AssistantAnimation.idle) {
      _actionController.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(ClawdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.animation != oldWidget.animation || widget.actionId != oldWidget.actionId) && widget.animation != AssistantAnimation.idle) {
      if (widget.animation == AssistantAnimation.flyingStars) {
        _actionController.duration = const Duration(milliseconds: 4000);
        // Generar nueva ruta aleatoria pero manteniendolo dentro de la pantalla
        _flyTargetX = (_random.nextDouble() > 0.5 ? 1 : -1) * (80.0 + _random.nextDouble() * 80.0); // Entre 80 y 160 px (no sale de pantalla)
        _flyPeakY = -150.0 - _random.nextDouble() * 100.0; // Altura pico controlada entre -150 y -250
      } else {
        _actionController.duration = const Duration(milliseconds: 800);
      }
      _actionController.forward(from: 0.0);
      
      if (widget.animation == AssistantAnimation.warningSevere || widget.animation == AssistantAnimation.alert) {
        HapticFeedback.heavyImpact();
      } else if (widget.animation == AssistantAnimation.celebration || widget.animation == AssistantAnimation.wealthy) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
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

  void _scheduleNextIdleAction() {
    final waitMs = 4000 + _random.nextInt(6000);
    Future.delayed(Duration(milliseconds: waitMs), () {
      if (_disposed || !mounted) return;
      if (widget.animation == AssistantAnimation.idle && !_actionController.isAnimating) {
        final options = [AssistantAnimation.nod, AssistantAnimation.stretch, AssistantAnimation.shrink];
        _currentIdleAnim = options[_random.nextInt(options.length)];
        _actionController.forward(from: 0.0);
      }
      _scheduleNextIdleAction();
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
          double rotation = 0.0;
          Color? glowColor;
          bool isSleeping = false;

          if (widget.animation == AssistantAnimation.sleep) {
            dy = -math.sin(bounce * math.pi) * 4;
            glowColor = Colors.indigoAccent.withAlpha(40);
            isSleeping = true;
          }

          final activeAnim = widget.animation != AssistantAnimation.idle ? widget.animation : _currentIdleAnim;

          if (isActing) {
            final sinPi = math.sin(action * math.pi);

            switch (activeAnim) {
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
              case AssistantAnimation.alert:
                glowColor = Colors.redAccent.withAlpha((sinPi * 200).toInt());
                dx += math.sin(action * math.pi * 12) * 5; // Fast shake
                scaleX += sinPi * 0.1;
                scaleY -= sinPi * 0.1;
                break;
              case AssistantAnimation.happy:
                glowColor = Colors.yellowAccent.withAlpha((sinPi * 200).toInt());
                dy -= math.sin(action * math.pi * 4).abs() * 15; // Jumps
                break;
              case AssistantAnimation.thinking:
                rotation = math.sin(action * math.pi * 4) * 0.2; // Wobble
                dx += math.sin(action * math.pi * 2) * 5;
                break;
              case AssistantAnimation.confused:
                rotation = math.sin(action * math.pi * 4) * 0.3; // Fuerte wobble
                dx += math.sin(action * math.pi * 2) * 5;
                break;
              case AssistantAnimation.celebration:
                glowColor = Colors.purpleAccent.withAlpha((sinPi * 200).toInt());
                scaleX = math.cos(action * math.pi * 2).abs(); // Spin
                dy -= sinPi * 20; // Alto salto
                break;
              case AssistantAnimation.warningSevere:
                glowColor = Colors.red.withAlpha((sinPi * 255).toInt());
                dx += math.sin(action * math.pi * 20) * 8; // Shake muy violento
                scaleX += math.sin(action * math.pi * 10).abs() * 0.2; // Latido
                scaleY += math.sin(action * math.pi * 10).abs() * 0.2;
                break;
              case AssistantAnimation.sad:
                glowColor = Colors.blueGrey.withAlpha((sinPi * 150).toInt());
                scaleY -= sinPi * 0.5; // Encogimiento extremo
                scaleX += sinPi * 0.2;
                dy += sinPi * 10; // Se hunde
                break;
              case AssistantAnimation.wealthy:
                glowColor = Colors.amberAccent.withAlpha((sinPi * 200).toInt());
                scaleY += sinPi * 0.4; // Se estira
                dy -= sinPi * 10;
                break;
              case AssistantAnimation.hide:
                dy += math.sin(action * math.pi) * 30; // Baja casi escondiéndose
                break;
              case AssistantAnimation.workout:
                glowColor = Colors.orangeAccent.withAlpha((sinPi * 150).toInt());
                final pushupCycle = math.sin(action * math.pi * 6).abs(); 
                dy += pushupCycle * 15;
                scaleX += pushupCycle * 0.2;
                scaleY -= pushupCycle * 0.2;
                break;
              case AssistantAnimation.flyingStars:
                glowColor = Colors.white.withAlpha((sinPi * 200).toInt());
                final smoothAction = Curves.easeInOutSine.transform(action);
                
                // Ruta base suave (arco hacia _flyTargetX)
                dx += smoothAction * _flyTargetX;
                dy += math.sin(smoothAction * math.pi) * _flyPeakY;
                
                // Movimientos organicos (sweeps)
                dx += math.sin(action * math.pi * 2) * 50 * (1 - action);
                dy += math.sin(action * math.pi * 4) * 30 * (1 - action);
                
                // Micro turbulencia o aleteo rápido
                dx += math.sin(action * math.pi * 20) * 5;
                dy += math.cos(action * math.pi * 15) * 5;
                
                rotation = math.sin(action * math.pi * 6) * 0.4;
                scaleX = 1.0 - math.sin(action * math.pi * 8).abs() * 0.3; // Flapping/Spinning
                break;
              case AssistantAnimation.sleep:
                scaleY += sinPi * 0.1;
                scaleX += sinPi * 0.05;
                break;
              case AssistantAnimation.flip:
                dy -= sinPi * 50; 
                rotation = action * math.pi * 2; // Giro 360 grados
                break;
              default:
                break;
            }
          }

          return Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              ..translate(dx, dy)
              ..rotateZ(rotation)
              ..scale(scaleX, scaleY),
            child: CustomPaint(
              size: Size.infinite,
              painter: _ClawdPainter(
                blink: isSleeping ? 0.9 : _blinkController.value, 
                glowColor: glowColor,
                isSleeping: isSleeping,
                activeAnim: isActing ? activeAnim : AssistantAnimation.idle,
                actionProgress: action,
              ),
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
  final bool isSleeping;
  final AssistantAnimation activeAnim;
  final double actionProgress;

  _ClawdPainter({
    required this.blink, 
    this.glowColor, 
    this.isSleeping = false,
    this.activeAnim = AssistantAnimation.idle,
    this.actionProgress = 0.0,
  });

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

    if (isSleeping) {
      final textPainter = TextPainter(
        text: TextSpan(text: 'z', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, const Offset(55, -5));
      final textPainter2 = TextPainter(
        text: TextSpan(text: 'Z', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      );
      textPainter2.layout();
      textPainter2.paint(canvas, const Offset(62, -15));
    }

    if (activeAnim == AssistantAnimation.confused) {
      final textPainter = TextPainter(
        text: TextSpan(text: '?', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(26, -30 - (math.sin(actionProgress * math.pi) * 10)));
      
      final textPainter2 = TextPainter(
        text: TextSpan(text: '?', style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      );
      textPainter2.layout();
      textPainter2.paint(canvas, Offset(5, -15 - (math.sin(actionProgress * math.pi) * 5)));
      textPainter2.paint(canvas, Offset(55, -20 - (math.sin(actionProgress * math.pi) * 12)));
    } else if (activeAnim == AssistantAnimation.wealthy) {
      final textPainter = TextPainter(
        text: TextSpan(text: '\$', style: TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      );
      final textPainterBig = TextPainter(
        text: TextSpan(text: '\$', style: TextStyle(color: Colors.lightGreen, fontSize: 22, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainterBig.layout();
      textPainter.paint(canvas, Offset(-10, -5 - (actionProgress * 25)));
      textPainterBig.paint(canvas, Offset(28, -35 - (actionProgress * 30)));
      textPainter.paint(canvas, Offset(70, -10 - (actionProgress * 20)));
      textPainter.paint(canvas, Offset(15, -15 - (actionProgress * 15)));
      textPainter.paint(canvas, Offset(50, 0 - (actionProgress * 35)));
    } else if (activeAnim == AssistantAnimation.celebration) {
      final paintStar = Paint()..color = Colors.yellowAccent;
      canvas.drawCircle(Offset(10 + (math.cos(actionProgress * math.pi * 4) * 20), -10 - (actionProgress * 20)), 2, paintStar);
      canvas.drawCircle(Offset(60 + (math.sin(actionProgress * math.pi * 4) * 20), -5 - (actionProgress * 15)), 2, paintStar);
      canvas.drawCircle(Offset(35, -20 - (actionProgress * 25)), 3, paintStar);
    } else if (activeAnim == AssistantAnimation.flyingStars) {
      final paintStar = Paint()..color = Colors.white;
      for (int i = 0; i < 6; i++) {
        canvas.drawCircle(
          Offset(36 + (math.cos(actionProgress * math.pi * 6 + i) * 35), 10 + (math.sin(actionProgress * math.pi * 6 + i) * 25)), 
          1.5 + (i % 2), 
          paintStar
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ClawdPainter old) => 
    old.blink != blink || 
    old.glowColor != glowColor || 
    old.isSleeping != isSleeping ||
    old.activeAnim != activeAnim ||
    old.actionProgress != actionProgress;
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
