import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/virtual_assistant_provider.dart';
import '../core/theme.dart';
import 'rocky_animations.dart';

class GlobalVirtualAssistant extends ConsumerStatefulWidget {
  const GlobalVirtualAssistant({super.key});

  @override
  ConsumerState<GlobalVirtualAssistant> createState() => _GlobalVirtualAssistantState();
}

class _GlobalVirtualAssistantState extends ConsumerState<GlobalVirtualAssistant> {
  Timer? _dismissTimer;
  String _lastMessage = '';

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _startDismissTimer(String message) {
    _dismissTimer?.cancel();
    final int calcSeconds = (3 + (message.length / 20).ceil()).clamp(5, 10);
    _dismissTimer = Timer(Duration(seconds: calcSeconds), () {
      if (mounted) {
        ref.read(virtualAssistantProvider.notifier).hideMessage();
      }
    });
  }

  void _showExpandedRocky(BuildContext context, AssistantState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, child) {
            final currentState = ref.watch(virtualAssistantProvider);
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: Color(0xFF333333))),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 54,
                        child: ClawdWidget(
                          animation: currentState.animation,
                          actionId: currentState.actionId,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
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
                              text: currentState.message,
                              style: const TextStyle(
                                color: Color(0xFFE5E5E5),
                                fontSize: 14,
                                height: 1.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Escucha cambios de estado UNA SOLA VEZ — no en cada build
    ref.listen<AssistantState>(virtualAssistantProvider, (previous, next) {
      if (next.isVisible && next.message.isNotEmpty && next.message != _lastMessage) {
        _lastMessage = next.message;
        _startDismissTimer(next.message);
      }
      if (!next.isVisible) {
        _dismissTimer?.cancel();
        _lastMessage = '';
      }
    });

    final state = ref.watch(virtualAssistantProvider);
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final visible = state.isVisible && state.message.isNotEmpty;
    final isBottom = state.isInitialGreeting;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      top: isBottom ? null : (visible ? topPadding + 8 : -(120 + topPadding)),
      bottom: isBottom ? (visible ? bottomPadding + 80 : -(120 + bottomPadding)) : null,
      left: 12,
      right: 12,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: visible ? () => _showExpandedRocky(context, state) : null,
          child: Container(
            padding: const EdgeInsets.only(left: 8, right: 12, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(60),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: const Color(0xFF333333)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ClawdWidget SOLO cuando el banner es visible (no anima en background)
                if (visible)
                  SizedBox(
                    width: 64,
                    height: 44,
                    child: ClawdWidget(
                      animation: state.animation,
                      actionId: state.actionId,
                    ),
                  )
                else
                  const SizedBox(width: 64, height: 44),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Rocky',
                        style: AppTheme.monoStyle(color: AppTheme.primary, fontSize: 10),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.message,
                        style: const TextStyle(
                          color: Color(0xFFE5E5E5),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _dismissTimer?.cancel();
                    ref.read(virtualAssistantProvider.notifier).hideMessage();
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, color: Color(0xFF888888), size: 18),
                  ),
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
    if (widget.animation != oldWidget.animation || widget.actionId != oldWidget.actionId) {
      _actionController.stop();
      
      if (widget.animation != AssistantAnimation.idle) {
        final spec = rockyAnimations[widget.animation.name];
        if (spec != null) {
          _actionController.duration = spec.duration;
          if (spec.loop) {
            _actionController.repeat();
          } else {
            _actionController.forward(from: 0.0);
          }
        } else if (widget.animation == AssistantAnimation.flyingStars) {
          _actionController.duration = const Duration(milliseconds: 4000);
          _flyTargetX = (_random.nextDouble() > 0.5 ? 1 : -1) * (80.0 + _random.nextDouble() * 80.0);
          _flyPeakY = -150.0 - _random.nextDouble() * 100.0;
          _actionController.forward(from: 0.0);
        } else {
          _actionController.duration = const Duration(milliseconds: 800);
          _actionController.forward(from: 0.0);
        }
        
        if (widget.animation == AssistantAnimation.warningSevere || widget.animation == AssistantAnimation.alert) {
          HapticFeedback.heavyImpact();
        } else if (widget.animation == AssistantAnimation.celebration || widget.animation == AssistantAnimation.wealthy) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.lightImpact();
        }
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
          final isActing = _actionController.isAnimating || (action > 0 && action < 1);
          
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

          double leftArmAngle = 0.0;
          double rightArmAngle = 0.0;
          double rightArmOffsetX = 0.0;
          double leftLegOffset = 0.0;
          double rightLegOffset = 0.0;
          String eyeStyle = 'normal';
          String mouthStyle = 'none';
          List<PixelObject> pixelObjects = [];

          if (isActing) {
            final spec = rockyAnimations[activeAnim.name];

            if (spec != null) {
              final pose = spec.evaluate(action);
              scaleX = pose.bodyScaleX;
              scaleY = pose.bodyScaleY;
              rotation = pose.bodyRotation;
              dx += pose.bodyOffset.dx * 0.35;
              dy += pose.bodyOffset.dy * 0.35;
              leftArmAngle = pose.leftArmAngle;
              rightArmAngle = pose.rightArmAngle;
              rightArmOffsetX = pose.rightArmOffsetX;
              leftLegOffset = pose.leftLegOffset;
              rightLegOffset = pose.rightLegOffset;
              eyeStyle = pose.eyeState.name;
              mouthStyle = pose.mouthState.name;
              glowColor = pose.glowColor ?? glowColor;
              pixelObjects = pose.particles;
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
                leftArmAngle: leftArmAngle,
                rightArmAngle: rightArmAngle,
                rightArmOffsetX: rightArmOffsetX,
                leftLegOffset: leftLegOffset,
                rightLegOffset: rightLegOffset,
                eyeStyle: eyeStyle,
                mouthStyle: mouthStyle,
                pixelObjects: pixelObjects,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ClawdPainter extends CustomPainter {
  static const Color body = Color(0xFF6C63FF);
  static const Color eye = Color(0xFF111111);

  final double blink; 
  final Color? glowColor;
  final bool isSleeping;
  final AssistantAnimation activeAnim;
  final double actionProgress;
  final double leftArmAngle;
  final double rightArmAngle;
  final double rightArmOffsetX;
  final double leftLegOffset;
  final double rightLegOffset;
  final String eyeStyle;
  final String mouthStyle;
  final List<PixelObject> pixelObjects;

  _ClawdPainter({
    required this.blink, 
    this.glowColor, 
    this.isSleeping = false,
    this.activeAnim = AssistantAnimation.idle,
    this.actionProgress = 0.0,
    this.leftArmAngle = 0.0,
    this.rightArmAngle = 0.0,
    this.rightArmOffsetX = 0.0,
    this.leftLegOffset = 0.0,
    this.rightLegOffset = 0.0,
    this.eyeStyle = 'normal',
    this.mouthStyle = 'none',
    this.pixelObjects = const [],
  });

  void _drawEyes(Canvas canvas, Paint paint, String style, double blink) {
    const px = 3.0;
    const eyeColor = Color(0xFF111111);
    switch (style) {
      case 'happy':
        final eyeH = 9 * (1 - blink);
        final eyeY = 8 + (9 - eyeH) / 2;
        paint.color = eyeColor;
        canvas.drawRect(Rect.fromLTWH(18, eyeY, 4, eyeH), paint);
        canvas.drawRect(Rect.fromLTWH(49, eyeY, 5, eyeH), paint);
        break;
      case 'sad':
        final eyeH = 9 * (1 - blink);
        final eyeY = 12 + (9 - eyeH) / 2;
        paint.color = eyeColor;
        canvas.drawRect(Rect.fromLTWH(18, eyeY, 4, eyeH), paint);
        canvas.drawRect(Rect.fromLTWH(49, eyeY, 5, eyeH), paint);
        break;
      case 'angry':
        final eyeH = 11 * (1 - blink);
        final eyeY = 9 + (11 - eyeH) / 2;
        paint.color = eyeColor;
        canvas.drawRect(Rect.fromLTWH(17, eyeY, 6, eyeH), paint);
        canvas.drawRect(Rect.fromLTWH(48, eyeY, 6, eyeH), paint);
        break;
      case 'star':
        final eyeH = 9 * (1 - blink);
        final eyeY = 10 + (9 - eyeH) / 2;
        paint.color = Colors.yellowAccent;
        canvas.drawRect(Rect.fromLTWH(18, eyeY, 4, eyeH), paint);
        canvas.drawRect(Rect.fromLTWH(49, eyeY, 5, eyeH), paint);
        break;
      case 'dollar':
        final eyeH = 9 * (1 - blink);
        final eyeY = 10 + (9 - eyeH) / 2;
        paint.color = Colors.greenAccent;
        canvas.drawRect(Rect.fromLTWH(18, eyeY, 4, eyeH), paint);
        canvas.drawRect(Rect.fromLTWH(49, eyeY, 5, eyeH), paint);
        break;
      case 'heart':
        final eyeH = 9 * (1 - blink);
        final eyeY = 10 + (9 - eyeH) / 2;
        paint.color = Colors.pinkAccent;
        canvas.drawRect(Rect.fromLTWH(18, eyeY, 4, eyeH), paint);
        canvas.drawRect(Rect.fromLTWH(49, eyeY, 5, eyeH), paint);
        break;
      case 'dizzy':
        final eyeH = 9 * (1 - blink);
        final eyeY = 10 + (9 - eyeH) / 2;
        paint.color = eyeColor;
        canvas.drawRect(Rect.fromLTWH(18, eyeY - 2, 4, eyeH), paint);
        canvas.drawRect(Rect.fromLTWH(49, eyeY + 2, 5, eyeH), paint);
        break;
      case 'closed':
      case 'sleep':
        final eyeH = 9 * (1 - 0.9);
        final eyeY = 10 + (9 - eyeH) / 2;
        paint.color = eyeColor;
        canvas.drawRect(Rect.fromLTWH(18, eyeY, 4, eyeH), paint);
        canvas.drawRect(Rect.fromLTWH(49, eyeY, 5, eyeH), paint);
        break;
      case 'lookLeft':
        final eyeH = 9 * (1 - blink);
        final eyeY = 10 + (9 - eyeH) / 2;
        paint.color = eyeColor;
        canvas.drawRect(Rect.fromLTWH(13, eyeY, 4, eyeH), paint);
        canvas.drawRect(Rect.fromLTWH(44, eyeY, 5, eyeH), paint);
        break;
      case 'lookRight':
        final eyeH = 9 * (1 - blink);
        final eyeY = 10 + (9 - eyeH) / 2;
        paint.color = eyeColor;
        canvas.drawRect(Rect.fromLTWH(23, eyeY, 4, eyeH), paint);
        canvas.drawRect(Rect.fromLTWH(54, eyeY, 5, eyeH), paint);
        break;
      default:
        final eyeH = 9 * (1 - blink);
        final eyeY = 10 + (9 - eyeH) / 2;
        paint.color = eyeColor;
        canvas.drawRect(Rect.fromLTWH(18, eyeY, 4, eyeH), paint);
        canvas.drawRect(Rect.fromLTWH(49, eyeY, 5, eyeH), paint);
    }
  }

  void _drawMouth(Canvas canvas, Paint paint, String style) {
    const px = 3.0;
    switch (style) {
      case 'smile':
        paint.color = const Color(0xFF222222);
        canvas.drawRect(const Rect.fromLTWH(28, 25, px, px), paint);
        canvas.drawRect(const Rect.fromLTWH(31, 27, 10, px), paint);
        canvas.drawRect(const Rect.fromLTWH(41, 25, px, px), paint);
        break;
      case 'frown':
        paint.color = const Color(0xFF222222);
        canvas.drawRect(const Rect.fromLTWH(28, 27, px, px), paint);
        canvas.drawRect(const Rect.fromLTWH(31, 25, 10, px), paint);
        canvas.drawRect(const Rect.fromLTWH(41, 27, px, px), paint);
        break;
      case 'open':
        paint.color = const Color(0xFF222222);
        canvas.drawRect(const Rect.fromLTWH(30, 24, 12, 6), paint);
        paint.color = const Color(0xFF661111);
        canvas.drawRect(const Rect.fromLTWH(31, 25, 10, 4), paint);
        break;
      case 'teeth':
        paint.color = const Color(0xFF222222);
        canvas.drawRect(const Rect.fromLTWH(28, 26, 16, 2), paint);
        break;
      case 'tight':
        paint.color = const Color(0xFF222222);
        canvas.drawRect(const Rect.fromLTWH(30, 26, 12, 2), paint);
        break;
      default:
        break;
    }
  }

  void _drawMiniStar(Canvas canvas, Paint paint, double cx, double cy, Color c) {
    const px = 3.0;
    paint.color = c;
    canvas.drawRect(Rect.fromLTWH(cx, cy - px, px, px), paint);
    canvas.drawRect(Rect.fromLTWH(cx - px, cy, px, px), paint);
    canvas.drawRect(Rect.fromLTWH(cx, cy, px, px), paint);
    canvas.drawRect(Rect.fromLTWH(cx + px, cy, px, px), paint);
    canvas.drawRect(Rect.fromLTWH(cx, cy + px, px, px), paint);
  }

  void _drawMiniHeart(Canvas canvas, Paint paint, double cx, double cy, Color c) {
    paint.color = c;
    canvas.drawRect(Rect.fromLTWH(cx + 1, cy, 2, 2), paint);
    canvas.drawRect(Rect.fromLTWH(cx + 5, cy, 2, 2), paint);
    canvas.drawRect(Rect.fromLTWH(cx, cy + 2, 8, 3), paint);
    canvas.drawRect(Rect.fromLTWH(cx + 2, cy + 5, 4, 2), paint);
    canvas.drawRect(Rect.fromLTWH(cx + 3, cy + 7, 2, 1), paint);
  }

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

    // ====== BRAZO IZQUIERDO (ARTICULADO) ======
    if (leftArmAngle != 0.0) {
      canvas.save();
      canvas.translate(9, 24);
      canvas.rotate(-leftArmAngle);
      rect(-9, -5, 9, 10, body);
      canvas.restore();
    } else {
      rect(0, 19, 9, 10, body);
    }

    // ====== BRAZO DERECHO (ARTICULADO) ======
    if (rightArmAngle != 0.0 || rightArmOffsetX != 0.0) {
      canvas.save();
      canvas.translate(63 + rightArmOffsetX, 24);
      canvas.rotate(rightArmAngle);
      rect(0, -5, 9, 10, body);
      canvas.restore();
    } else {
      rect(63, 19, 9, 10, body);
    }

    // ====== CABEZA Y TORSO BASE DE ROCKY ======
    rect(9, 0, 54, 10, body);
    rect(9, 10, 54, 9, body);
    rect(9, 19, 54, 10, body); // Torso central
    rect(9, 29, 54, 9, body);

    // ====== PIERNAS (ARTICULADAS) ======
    // leftLegOffset y rightLegOffset son grados de la animacion: negativo = pierna hacia adelante/arriba
    final leftLiftY = (leftLegOffset < 0) ? (leftLegOffset * 0.35).clamp(-12.0, 0.0) : 0.0;
    final rightLiftY = (rightLegOffset < 0) ? (rightLegOffset * 0.35).clamp(-12.0, 0.0) : 0.0;
    final leftStepX = leftLegOffset * 0.15;
    final rightStepX = rightLegOffset * 0.15;
    // Pierna izquierda
    rect(13 + leftStepX, 38 + leftLiftY, 5, 10 - leftLiftY.abs(), body);
    rect(22 + leftStepX * 0.4, 38 + leftLiftY * 0.5, 5, 10 - leftLiftY.abs() * 0.5, body);
    // Pierna derecha
    rect(45 + rightStepX * 0.4, 38 + rightLiftY * 0.5, 4, 10 - rightLiftY.abs() * 0.5, body);
    rect(54 + rightStepX, 38 + rightLiftY, 4, 10 - rightLiftY.abs(), body);


    // ====== OJOS (expresivos) ======
    _drawEyes(canvas, paint, eyeStyle, blink);

    // ====== BOCA ======
    _drawMouth(canvas, paint, mouthStyle);

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

    if (pixelObjects.isNotEmpty) {
      for (final obj in pixelObjects) {
        _drawPixelObject(canvas, paint, obj);
      }
    } else if (activeAnim == AssistantAnimation.confused) {
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
    old.actionProgress != actionProgress ||
    old.leftArmAngle != leftArmAngle ||
    old.rightArmAngle != rightArmAngle ||
    old.leftLegOffset != leftLegOffset ||
    old.rightLegOffset != rightLegOffset ||
    old.eyeStyle != eyeStyle ||
    old.mouthStyle != mouthStyle ||
    old.pixelObjects.length != pixelObjects.length;

  void _drawPixelObject(Canvas canvas, Paint paint, PixelObject obj) {
    final x = obj.x;
    final y = obj.y;
    final alpha = ((1.0 - obj.progress) * 255).clamp(0, 255).toInt();
    final fadeColor = obj.color.withAlpha(alpha);
    paint.color = fadeColor;

    switch (obj.type) {
      case 'coin':
        canvas.drawRect(Rect.fromLTWH(x + 1, y, 4, 1), paint);
        canvas.drawRect(Rect.fromLTWH(x, y + 1, 6, 4), paint);
        canvas.drawRect(Rect.fromLTWH(x + 1, y + 5, 4, 1), paint);
        paint.color = Colors.yellow.withAlpha(alpha);
        canvas.drawRect(Rect.fromLTWH(x + 2, y + 2, 2, 2), paint);
        break;
      case 'bill':
        canvas.drawRect(Rect.fromLTWH(x, y, 10, 5), paint);
        paint.color = Colors.green.withAlpha(alpha);
        canvas.drawRect(Rect.fromLTWH(x + 4, y + 2, 2, 1), paint);
        break;
      case 'heart':
        canvas.drawRect(Rect.fromLTWH(x + 1, y, 2, 1), paint);
        canvas.drawRect(Rect.fromLTWH(x + 4, y, 2, 1), paint);
        canvas.drawRect(Rect.fromLTWH(x, y + 1, 7, 2), paint);
        canvas.drawRect(Rect.fromLTWH(x + 1, y + 3, 5, 1), paint);
        canvas.drawRect(Rect.fromLTWH(x + 2, y + 4, 3, 1), paint);
        canvas.drawRect(Rect.fromLTWH(x + 3, y + 5, 1, 1), paint);
        break;
      case 'star4':
        canvas.drawRect(Rect.fromLTWH(x + 2, y, 1, 5), paint);
        canvas.drawRect(Rect.fromLTWH(x, y + 2, 5, 1), paint);
        break;
      case 'lightning':
        canvas.drawRect(Rect.fromLTWH(x + 2, y, 3, 2), paint);
        canvas.drawRect(Rect.fromLTWH(x + 1, y + 2, 3, 2), paint);
        canvas.drawRect(Rect.fromLTWH(x, y + 4, 5, 2), paint);
        canvas.drawRect(Rect.fromLTWH(x + 2, y + 6, 3, 2), paint);
        canvas.drawRect(Rect.fromLTWH(x + 1, y + 8, 3, 2), paint);
        break;
      case 'cloud':
        paint.color = fadeColor;
        canvas.drawRect(Rect.fromLTWH(x + 5, y, 10, 3), paint);
        canvas.drawRect(Rect.fromLTWH(x + 2, y + 3, 18, 4), paint);
        canvas.drawRect(Rect.fromLTWH(x, y + 5, 22, 3), paint);
        canvas.drawRect(Rect.fromLTWH(x + 15, y - 1, 6, 3), paint);
        break;
      case 'drop':
        paint.color = fadeColor;
        canvas.drawRect(Rect.fromLTWH(x + 1, y, 1, 2), paint);
        canvas.drawRect(Rect.fromLTWH(x, y + 2, 3, 2), paint);
        canvas.drawRect(Rect.fromLTWH(x + 1, y + 4, 1, 1), paint);
        break;
      case 'note':
        paint.color = fadeColor;
        canvas.drawRect(Rect.fromLTWH(x + 4, y, 1, 8), paint);
        canvas.drawRect(Rect.fromLTWH(x + 4, y, 3, 2), paint);
        canvas.drawRect(Rect.fromLTWH(x, y + 6, 4, 3), paint);
        break;
      case 'crown':
        paint.color = fadeColor;
        // Bajar la corona sumando 12 al eje Y
        final cy = y + 12;
        canvas.drawRect(Rect.fromLTWH(x, cy + 5, 30, 5), paint);
        canvas.drawRect(Rect.fromLTWH(x, cy + 2, 3, 3), paint);
        canvas.drawRect(Rect.fromLTWH(x + 13, cy, 4, 5), paint);
        canvas.drawRect(Rect.fromLTWH(x + 27, cy + 2, 3, 3), paint);
        paint.color = Colors.redAccent.withAlpha(alpha);
        canvas.drawRect(Rect.fromLTWH(x + 7, cy + 6, 3, 2), paint);
        paint.color = Colors.blueAccent.withAlpha(alpha);
        canvas.drawRect(Rect.fromLTWH(x + 20, cy + 6, 3, 2), paint);
        break;
      case 'shield':
        paint.color = fadeColor;
        canvas.drawRect(Rect.fromLTWH(x, y, 20, 4), paint);
        canvas.drawRect(Rect.fromLTWH(x + 1, y + 4, 18, 4), paint);
        canvas.drawRect(Rect.fromLTWH(x + 3, y + 8, 14, 4), paint);
        canvas.drawRect(Rect.fromLTWH(x + 5, y + 12, 10, 3), paint);
        canvas.drawRect(Rect.fromLTWH(x + 8, y + 15, 4, 2), paint);
        paint.color = Colors.white.withAlpha(alpha);
        canvas.drawRect(Rect.fromLTWH(x + 8, y + 3, 4, 8), paint);
        canvas.drawRect(Rect.fromLTWH(x + 5, y + 5, 10, 4), paint);
        break;
      case 'flame':
        paint.color = fadeColor;
        canvas.drawRect(Rect.fromLTWH(x + 2, y, 3, 3), paint);
        canvas.drawRect(Rect.fromLTWH(x + 1, y + 3, 5, 3), paint);
        canvas.drawRect(Rect.fromLTWH(x, y + 6, 7, 3), paint);
        paint.color = Colors.yellow.withAlpha(alpha);
        canvas.drawRect(Rect.fromLTWH(x + 2, y + 3, 3, 3), paint);
        break;
      case 'exclamation':
        paint.color = fadeColor;
        canvas.drawRect(Rect.fromLTWH(x + 1, y, 3, 8), paint);
        canvas.drawRect(Rect.fromLTWH(x + 1, y + 10, 3, 3), paint);
        break;
      case 'question':
        paint.color = fadeColor;
        canvas.drawRect(Rect.fromLTWH(x + 1, y, 5, 2), paint);
        canvas.drawRect(Rect.fromLTWH(x + 5, y + 2, 2, 3), paint);
        canvas.drawRect(Rect.fromLTWH(x + 2, y + 5, 4, 2), paint);
        canvas.drawRect(Rect.fromLTWH(x + 2, y + 7, 2, 2), paint);
        canvas.drawRect(Rect.fromLTWH(x + 2, y + 11, 2, 2), paint);
        break;
      case 'confetti':
        paint.color = fadeColor;
        canvas.drawRect(Rect.fromLTWH(x, y, 3, 2), paint);
        break;
      case 'dust':
        paint.color = fadeColor;
        canvas.drawRect(Rect.fromLTWH(x, y, 4, 2), paint);
        canvas.drawRect(Rect.fromLTWH(x + 3, y - 1, 3, 2), paint);
        canvas.drawRect(Rect.fromLTWH(x + 5, y + 1, 2, 2), paint);
        break;
      case 'number':
        paint.color = fadeColor;
        canvas.drawRect(Rect.fromLTWH(x, y + 1, 5, 1), paint);
        canvas.drawRect(Rect.fromLTWH(x, y + 3, 5, 1), paint);
        canvas.drawRect(Rect.fromLTWH(x + 1, y, 1, 5), paint);
        canvas.drawRect(Rect.fromLTWH(x + 3, y, 1, 5), paint);
        break;
      case 'zzz':
        paint.color = fadeColor;
        canvas.drawRect(Rect.fromLTWH(x, y + 10, 4, 1), paint);
        canvas.drawRect(Rect.fromLTWH(x + 2, y + 11, 1, 1), paint);
        canvas.drawRect(Rect.fromLTWH(x + 1, y + 12, 1, 1), paint);
        canvas.drawRect(Rect.fromLTWH(x, y + 13, 4, 1), paint);
        canvas.drawRect(Rect.fromLTWH(x + 6, y, 6, 2), paint);
        canvas.drawRect(Rect.fromLTWH(x + 10, y + 2, 2, 2), paint);
        canvas.drawRect(Rect.fromLTWH(x + 8, y + 4, 2, 2), paint);
        canvas.drawRect(Rect.fromLTWH(x + 6, y + 6, 2, 2), paint);
        canvas.drawRect(Rect.fromLTWH(x + 6, y + 8, 6, 2), paint);
        break;
      case 'spark':
        paint.color = fadeColor;
        canvas.drawRect(Rect.fromLTWH(x, y, 2, 2), paint);
        break;
    }
  }
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
