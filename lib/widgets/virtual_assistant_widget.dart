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
        _flyTargetX = (_random.nextDouble() > 0.5 ? 1 : -1) * (80.0 + _random.nextDouble() * 80.0);
        _flyPeakY = -150.0 - _random.nextDouble() * 100.0;
      } else if (widget.animation == AssistantAnimation.dance || widget.animation == AssistantAnimation.running) {
        _actionController.duration = const Duration(milliseconds: 1600);
      } else if (widget.animation == AssistantAnimation.rocket) {
        _actionController.duration = const Duration(milliseconds: 2000);
      } else {
        _actionController.duration = const Duration(milliseconds: 800);
      }
      _actionController.forward(from: 0.0);
      
      if (widget.animation == AssistantAnimation.warningSevere || widget.animation == AssistantAnimation.alert || widget.animation == AssistantAnimation.angry) {
        HapticFeedback.heavyImpact();
      } else if (widget.animation == AssistantAnimation.celebration || widget.animation == AssistantAnimation.wealthy || widget.animation == AssistantAnimation.crown || widget.animation == AssistantAnimation.rocket) {
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
        final options = [AssistantAnimation.nod, AssistantAnimation.stretch, AssistantAnimation.shrink, AssistantAnimation.wave, AssistantAnimation.lookAround, AssistantAnimation.flexing];
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
      aspectRatio: 72 / 60,
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

          // Parametros articulados
          double leftArmAngle = 0.0;
          double rightArmAngle = 0.0;
          double leftLegOffset = 0.0;
          double rightLegOffset = 0.0;
          String eyeStyle = 'normal';
          String mouthStyle = 'none';
          List<_PixelObject> pixelObjects = [];

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
                leftArmAngle = sinPi * 0.8;
                rightArmAngle = sinPi * 0.8;
                eyeStyle = 'happy';
                mouthStyle = 'open';
                break;
              case AssistantAnimation.shake:
                dx += math.sin(action * math.pi * 6) * 4;
                leftArmAngle = math.sin(action * math.pi * 6) * 0.3;
                rightArmAngle = -math.sin(action * math.pi * 6) * 0.3;
                eyeStyle = 'angry';
                mouthStyle = 'teeth';
                break;
              case AssistantAnimation.stretch:
                scaleY += sinPi * 0.3;
                scaleX -= sinPi * 0.1;
                leftArmAngle = sinPi * 1.2;
                rightArmAngle = sinPi * 1.2;
                eyeStyle = 'happy';
                mouthStyle = 'open';
                break;
              case AssistantAnimation.shrink:
                scaleY -= sinPi * 0.3;
                scaleX += sinPi * 0.1;
                leftArmAngle = -sinPi * 0.5;
                rightArmAngle = -sinPi * 0.5;
                eyeStyle = 'sad';
                mouthStyle = 'frown';
                break;
              case AssistantAnimation.nod:
                dy += math.sin(action * math.pi * 2) * 3;
                eyeStyle = 'happy';
                mouthStyle = 'smile';
                break;
              case AssistantAnimation.glitch:
                dx += (_random.nextDouble() - 0.5) * 6 * sinPi;
                dy += (_random.nextDouble() - 0.5) * 6 * sinPi;
                leftArmAngle = (_random.nextDouble() - 0.5) * sinPi;
                rightArmAngle = (_random.nextDouble() - 0.5) * sinPi;
                eyeStyle = 'dizzy';
                mouthStyle = 'open';
                for (int i = 0; i < 4; i++) {
                  pixelObjects.add(_PixelObject(
                    type: 'spark',
                    x: 10 + _random.nextDouble() * 52,
                    y: -5 - _random.nextDouble() * 20 * sinPi,
                    progress: action,
                    color: Colors.cyanAccent,
                  ));
                }
                break;
              case AssistantAnimation.glowGreen:
                glowColor = Colors.greenAccent.withAlpha((sinPi * 200).toInt());
                dy -= sinPi * 5;
                leftArmAngle = sinPi * 0.6;
                rightArmAngle = sinPi * 0.6;
                eyeStyle = 'star';
                mouthStyle = 'smile';
                pixelObjects.add(_PixelObject(type: 'sparkle', x: 5, y: -10 - action * 15, progress: action, color: Colors.greenAccent));
                pixelObjects.add(_PixelObject(type: 'sparkle', x: 60, y: -5 - action * 12, progress: action, color: Colors.lightGreenAccent));
                break;
              case AssistantAnimation.glowRed:
                glowColor = Colors.redAccent.withAlpha((sinPi * 200).toInt());
                dx += math.sin(action * math.pi * 4) * 2;
                eyeStyle = 'angry';
                mouthStyle = 'frown';
                pixelObjects.add(_PixelObject(type: 'lightning', x: 55, y: -15 - sinPi * 10, progress: action, color: Colors.redAccent));
                break;
              case AssistantAnimation.spin:
                scaleX = math.cos(action * math.pi * 2).abs();
                leftArmAngle = action * math.pi * 2;
                rightArmAngle = -action * math.pi * 2;
                eyeStyle = 'dizzy';
                break;
              case AssistantAnimation.alert:
                glowColor = Colors.redAccent.withAlpha((sinPi * 200).toInt());
                dx += math.sin(action * math.pi * 12) * 5;
                scaleX += sinPi * 0.1;
                scaleY -= sinPi * 0.1;
                leftArmAngle = -0.5;
                rightArmAngle = -0.5;
                eyeStyle = 'angry';
                mouthStyle = 'teeth';
                pixelObjects.add(_PixelObject(type: 'exclamation', x: 30, y: -25 - sinPi * 10, progress: action, color: Colors.redAccent));
                break;
              case AssistantAnimation.happy:
                glowColor = Colors.yellowAccent.withAlpha((sinPi * 200).toInt());
                dy -= math.sin(action * math.pi * 4).abs() * 15;
                leftArmAngle = sinPi * 1.2;
                rightArmAngle = sinPi * 1.2;
                eyeStyle = 'happy';
                mouthStyle = 'smile';
                pixelObjects.add(_PixelObject(type: 'note', x: -5, y: -10 - action * 20, progress: action, color: Colors.yellowAccent));
                pixelObjects.add(_PixelObject(type: 'note', x: 65, y: -15 - action * 18, progress: action, color: Colors.amberAccent));
                break;
              case AssistantAnimation.thinking:
                rotation = math.sin(action * math.pi * 4) * 0.2;
                dx += math.sin(action * math.pi * 2) * 5;
                rightArmAngle = 0.8 + sinPi * 0.3;
                eyeStyle = 'normal';
                mouthStyle = 'frown';
                pixelObjects.add(_PixelObject(type: 'thought', x: 55, y: -20 - sinPi * 8, progress: action, color: Colors.white70));
                break;
              case AssistantAnimation.confused:
                rotation = math.sin(action * math.pi * 4) * 0.3;
                dx += math.sin(action * math.pi * 2) * 5;
                leftArmAngle = math.sin(action * math.pi * 3) * 0.5;
                rightArmAngle = -math.sin(action * math.pi * 3) * 0.5;
                eyeStyle = 'dizzy';
                mouthStyle = 'open';
                pixelObjects.add(_PixelObject(type: 'question', x: 28, y: -28 - sinPi * 10, progress: action, color: Colors.white));
                pixelObjects.add(_PixelObject(type: 'question', x: 8, y: -12 - sinPi * 5, progress: action, color: Colors.white70));
                pixelObjects.add(_PixelObject(type: 'question', x: 55, y: -18 - sinPi * 12, progress: action, color: Colors.white70));
                break;
              case AssistantAnimation.celebration:
                glowColor = Colors.purpleAccent.withAlpha((sinPi * 200).toInt());
                scaleX = math.cos(action * math.pi * 2).abs();
                dy -= sinPi * 20;
                leftArmAngle = 1.0 + sinPi * 0.5;
                rightArmAngle = 1.0 + sinPi * 0.5;
                eyeStyle = 'star';
                mouthStyle = 'smile';
                final confColors = [Colors.yellowAccent, Colors.cyanAccent, Colors.pinkAccent, Colors.greenAccent, Colors.orangeAccent];
                for (int i = 0; i < 8; i++) {
                  pixelObjects.add(_PixelObject(
                    type: 'confetti',
                    x: 5 + (math.cos(action * math.pi * 4 + i * 0.8) * 30) + i * 5,
                    y: -10 - action * 25 - math.sin(action * math.pi * 3 + i) * 15,
                    progress: action,
                    color: confColors[i % confColors.length],
                  ));
                }
                break;
              case AssistantAnimation.warningSevere:
                glowColor = Colors.red.withAlpha((sinPi * 255).toInt());
                dx += math.sin(action * math.pi * 20) * 8;
                scaleX += math.sin(action * math.pi * 10).abs() * 0.2;
                scaleY += math.sin(action * math.pi * 10).abs() * 0.2;
                leftArmAngle = math.sin(action * math.pi * 10) * 0.8;
                rightArmAngle = -math.sin(action * math.pi * 10) * 0.8;
                eyeStyle = 'angry';
                mouthStyle = 'teeth';
                pixelObjects.add(_PixelObject(type: 'lightning', x: 10, y: -15 - sinPi * 10, progress: action, color: Colors.redAccent));
                pixelObjects.add(_PixelObject(type: 'lightning', x: 55, y: -20 - sinPi * 8, progress: action, color: Colors.orangeAccent));
                pixelObjects.add(_PixelObject(type: 'exclamation', x: 32, y: -30 - sinPi * 12, progress: action, color: Colors.red));
                break;
              case AssistantAnimation.sad:
                glowColor = Colors.blueGrey.withAlpha((sinPi * 150).toInt());
                scaleY -= sinPi * 0.5;
                scaleX += sinPi * 0.2;
                dy += sinPi * 10;
                leftArmAngle = -sinPi * 0.6;
                rightArmAngle = -sinPi * 0.6;
                eyeStyle = 'sad';
                mouthStyle = 'frown';
                pixelObjects.add(_PixelObject(type: 'drop', x: 22, y: 18 + sinPi * 8, progress: action, color: Colors.lightBlueAccent));
                break;
              case AssistantAnimation.wealthy:
                glowColor = Colors.amberAccent.withAlpha((sinPi * 200).toInt());
                scaleY += sinPi * 0.4;
                dy -= sinPi * 10;
                leftArmAngle = sinPi * 0.8;
                rightArmAngle = sinPi * 0.8;
                eyeStyle = 'dollar';
                mouthStyle = 'smile';
                pixelObjects.add(_PixelObject(type: 'coin', x: -8, y: -5 - action * 25, progress: action, color: Colors.amberAccent));
                pixelObjects.add(_PixelObject(type: 'coin', x: 30, y: -30 - action * 30, progress: action, color: Colors.amber));
                pixelObjects.add(_PixelObject(type: 'coin', x: 65, y: -10 - action * 20, progress: action, color: Colors.amberAccent));
                pixelObjects.add(_PixelObject(type: 'bill', x: 15, y: -15 - action * 18, progress: action, color: Colors.greenAccent));
                pixelObjects.add(_PixelObject(type: 'bill', x: 50, y: -5 - action * 35, progress: action, color: Colors.lightGreenAccent));
                break;
              case AssistantAnimation.hide:
                dy += math.sin(action * math.pi) * 30;
                leftArmAngle = sinPi * 0.8;
                rightArmAngle = sinPi * 0.8;
                eyeStyle = sinPi > 0.5 ? 'sad' : 'normal';
                mouthStyle = 'frown';
                break;
              case AssistantAnimation.workout:
                glowColor = Colors.orangeAccent.withAlpha((sinPi * 150).toInt());
                final pushupCycle = math.sin(action * math.pi * 6).abs(); 
                dy += pushupCycle * 15;
                scaleX += pushupCycle * 0.2;
                scaleY -= pushupCycle * 0.2;
                leftArmAngle = -pushupCycle * 0.8;
                rightArmAngle = -pushupCycle * 0.8;
                leftLegOffset = pushupCycle * 3;
                rightLegOffset = -pushupCycle * 3;
                eyeStyle = 'angry';
                mouthStyle = 'teeth';
                pixelObjects.add(_PixelObject(type: 'drop', x: -3, y: 5 + pushupCycle * 5, progress: action, color: Colors.lightBlueAccent));
                pixelObjects.add(_PixelObject(type: 'drop', x: 68, y: 8 + pushupCycle * 4, progress: action, color: Colors.lightBlueAccent));
                break;
              case AssistantAnimation.flyingStars:
                glowColor = Colors.white.withAlpha((sinPi * 200).toInt());
                final smoothAction = Curves.easeInOutSine.transform(action);
                dx += smoothAction * _flyTargetX;
                dy += math.sin(smoothAction * math.pi) * _flyPeakY;
                dx += math.sin(action * math.pi * 2) * 50 * (1 - action);
                dy += math.sin(action * math.pi * 4) * 30 * (1 - action);
                dx += math.sin(action * math.pi * 20) * 5;
                dy += math.cos(action * math.pi * 15) * 5;
                rotation = math.sin(action * math.pi * 6) * 0.4;
                scaleX = 1.0 - math.sin(action * math.pi * 8).abs() * 0.3;
                leftArmAngle = math.sin(action * math.pi * 8) * 1.2;
                rightArmAngle = -math.sin(action * math.pi * 8) * 1.2;
                eyeStyle = 'star';
                mouthStyle = 'open';
                for (int i = 0; i < 6; i++) {
                  pixelObjects.add(_PixelObject(
                    type: 'star4',
                    x: 36 + (math.cos(action * math.pi * 6 + i) * 35),
                    y: 10 + (math.sin(action * math.pi * 6 + i) * 25),
                    progress: action,
                    color: Colors.white,
                  ));
                }
                break;
              case AssistantAnimation.sleep:
                scaleY += sinPi * 0.1;
                scaleX += sinPi * 0.05;
                leftArmAngle = -0.3;
                rightArmAngle = -0.3;
                eyeStyle = 'sleep';
                mouthStyle = 'none';
                pixelObjects.add(_PixelObject(type: 'zzz', x: 55, y: -5 - action * 15, progress: action, color: Colors.white70));
                break;
              case AssistantAnimation.flip:
                dy -= sinPi * 50; 
                rotation = action * math.pi * 2;
                leftArmAngle = action * math.pi;
                rightArmAngle = -action * math.pi;
                eyeStyle = 'dizzy';
                mouthStyle = 'open';
                break;
              // =====================
              // NUEVAS ANIMACIONES
              // =====================
              case AssistantAnimation.wave:
                rightArmAngle = 0.8 + math.sin(action * math.pi * 4) * 0.5;
                eyeStyle = 'happy';
                mouthStyle = 'smile';
                dy -= sinPi * 3;
                break;
              case AssistantAnimation.clap:
                leftArmAngle = 0.6 + math.sin(action * math.pi * 6).abs() * 0.6;
                rightArmAngle = 0.6 + math.sin(action * math.pi * 6).abs() * 0.6;
                eyeStyle = 'happy';
                mouthStyle = 'smile';
                dy -= sinPi * 3;
                if (math.sin(action * math.pi * 6) > 0.8) {
                  pixelObjects.add(_PixelObject(type: 'sparkle', x: 33, y: -5, progress: action, color: Colors.yellowAccent));
                }
                break;
              case AssistantAnimation.dance:
                dy -= math.sin(action * math.pi * 6).abs() * 8;
                dx += math.sin(action * math.pi * 4) * 6;
                leftArmAngle = math.sin(action * math.pi * 4) * 1.0;
                rightArmAngle = -math.sin(action * math.pi * 4) * 1.0;
                leftLegOffset = math.sin(action * math.pi * 4) * 4;
                rightLegOffset = -math.sin(action * math.pi * 4) * 4;
                eyeStyle = 'happy';
                mouthStyle = 'smile';
                pixelObjects.add(_PixelObject(type: 'note', x: -5 + math.sin(action * math.pi * 3) * 10, y: -15 - action * 15, progress: action, color: Colors.pinkAccent));
                pixelObjects.add(_PixelObject(type: 'note', x: 65 + math.cos(action * math.pi * 3) * 8, y: -10 - action * 12, progress: action, color: Colors.cyanAccent));
                break;
              case AssistantAnimation.angry:
                dx += math.sin(action * math.pi * 8) * 3;
                leftArmAngle = -0.5 - sinPi * 0.3;
                rightArmAngle = -0.5 - sinPi * 0.3;
                eyeStyle = 'angry';
                mouthStyle = 'teeth';
                glowColor = Colors.red.withAlpha((sinPi * 120).toInt());
                pixelObjects.add(_PixelObject(type: 'angerCloud', x: 25, y: -25 - sinPi * 8, progress: action, color: Colors.redAccent));
                pixelObjects.add(_PixelObject(type: 'lightning', x: 45, y: -15 - sinPi * 5, progress: action, color: Colors.orangeAccent));
                break;
              case AssistantAnimation.love:
                dy -= sinPi * 5;
                leftArmAngle = 0.8 + sinPi * 0.4;
                rightArmAngle = 0.8 + sinPi * 0.4;
                eyeStyle = 'heart';
                mouthStyle = 'smile';
                glowColor = Colors.pinkAccent.withAlpha((sinPi * 120).toInt());
                pixelObjects.add(_PixelObject(type: 'heart', x: -5, y: -10 - action * 25, progress: action, color: Colors.pinkAccent));
                pixelObjects.add(_PixelObject(type: 'heart', x: 30, y: -25 - action * 20, progress: action, color: Colors.redAccent));
                pixelObjects.add(_PixelObject(type: 'heart', x: 60, y: -8 - action * 22, progress: action, color: Colors.pink));
                break;
              case AssistantAnimation.facepalm:
                rightArmAngle = 0.3 + sinPi * 0.8;
                eyeStyle = sinPi > 0.5 ? 'sad' : 'normal';
                mouthStyle = 'frown';
                dy += sinPi * 3;
                break;
              case AssistantAnimation.thumbsUp:
                rightArmAngle = 0.8 + sinPi * 0.4;
                eyeStyle = 'happy';
                mouthStyle = 'smile';
                dy -= sinPi * 3;
                pixelObjects.add(_PixelObject(type: 'sparkle', x: 62, y: -15 - sinPi * 8, progress: action, color: Colors.yellowAccent));
                break;
              case AssistantAnimation.running:
                dx += math.sin(action * math.pi * 2) * 15;
                leftArmAngle = math.sin(action * math.pi * 8) * 0.8;
                rightArmAngle = -math.sin(action * math.pi * 8) * 0.8;
                leftLegOffset = math.sin(action * math.pi * 8) * 5;
                rightLegOffset = -math.sin(action * math.pi * 8) * 5;
                eyeStyle = 'normal';
                mouthStyle = 'open';
                pixelObjects.add(_PixelObject(type: 'dust', x: 5 - action * 20, y: 40, progress: action, color: Colors.grey));
                pixelObjects.add(_PixelObject(type: 'dust', x: 15 - action * 30, y: 42, progress: action, color: const Color(0xFFBDBDBD)));
                break;
              case AssistantAnimation.typing:
                leftArmAngle = -0.3 + math.sin(action * math.pi * 12) * 0.3;
                rightArmAngle = -0.3 - math.sin(action * math.pi * 12) * 0.3;
                eyeStyle = 'normal';
                mouthStyle = 'none';
                pixelObjects.add(_PixelObject(type: 'number', x: 20 + action * 10, y: -10 - action * 15, progress: action, color: Colors.cyanAccent));
                pixelObjects.add(_PixelObject(type: 'number', x: 45 - action * 5, y: -15 - action * 12, progress: action, color: Colors.lightGreenAccent));
                break;
              case AssistantAnimation.shielding:
                leftArmAngle = 0.5;
                rightArmAngle = 0.5;
                eyeStyle = 'angry';
                mouthStyle = 'teeth';
                dy -= sinPi * 3;
                pixelObjects.add(_PixelObject(type: 'shield', x: 22, y: -5 + sinPi * -10, progress: action, color: Colors.blueAccent));
                break;
              case AssistantAnimation.rocket:
                dy -= action * 60;
                leftArmAngle = 1.0 + sinPi * 0.5;
                rightArmAngle = 1.0 + sinPi * 0.5;
                eyeStyle = 'star';
                mouthStyle = 'open';
                glowColor = Colors.orangeAccent.withAlpha((sinPi * 200).toInt());
                pixelObjects.add(_PixelObject(type: 'flame', x: 30, y: 48 + 5, progress: action, color: Colors.orangeAccent));
                pixelObjects.add(_PixelObject(type: 'flame', x: 25, y: 48 + 10, progress: action, color: Colors.redAccent));
                pixelObjects.add(_PixelObject(type: 'flame', x: 38, y: 48 + 8, progress: action, color: Colors.yellow));
                for (int i = 0; i < 4; i++) {
                  pixelObjects.add(_PixelObject(
                    type: 'star4',
                    x: 10 + i * 18.0,
                    y: 5 + action * 40 + i * 5.0,
                    progress: action,
                    color: Colors.white70,
                  ));
                }
                break;
              case AssistantAnimation.crown:
                dy -= sinPi * 18;
                leftArmAngle = sinPi * 1.0;
                rightArmAngle = sinPi * 1.0;
                eyeStyle = 'star';
                mouthStyle = 'smile';
                glowColor = Colors.amberAccent.withAlpha((sinPi * 150).toInt());
                pixelObjects.add(_PixelObject(type: 'crown', x: 20, y: -20 - sinPi * 15, progress: action, color: Colors.amberAccent));
                pixelObjects.add(_PixelObject(type: 'sparkle', x: 10, y: -25 - sinPi * 10, progress: action, color: Colors.yellowAccent));
                pixelObjects.add(_PixelObject(type: 'sparkle', x: 55, y: -22 - sinPi * 12, progress: action, color: Colors.amberAccent));
                break;
              case AssistantAnimation.rainy:
                dy += sinPi * 5;
                scaleY -= sinPi * 0.15;
                leftArmAngle = -sinPi * 0.4;
                rightArmAngle = -sinPi * 0.4;
                eyeStyle = 'sad';
                mouthStyle = 'frown';
                pixelObjects.add(_PixelObject(type: 'cloud', x: 15, y: -22, progress: action, color: Colors.blueGrey));
                for (int i = 0; i < 4; i++) {
                  pixelObjects.add(_PixelObject(
                    type: 'drop',
                    x: 20 + i * 10.0,
                    y: -10 + (action * 25 + i * 5) % 30,
                    progress: action,
                    color: Colors.lightBlueAccent,
                  ));
                }
                break;
              case AssistantAnimation.flexing:
                rightArmAngle = 0.6 + sinPi * 0.5;
                leftArmAngle = -0.2;
                eyeStyle = 'happy';
                mouthStyle = 'smile';
                scaleX += sinPi * 0.1;
                dy -= sinPi * 3;
                pixelObjects.add(_PixelObject(type: 'sparkle', x: 62, y: 10 - sinPi * 10, progress: action, color: Colors.yellowAccent));
                break;
              case AssistantAnimation.lookAround:
                final lookPhase = math.sin(action * math.pi * 2);
                if (lookPhase > 0.3) {
                  eyeStyle = 'lookRight';
                } else if (lookPhase < -0.3) {
                  eyeStyle = 'lookLeft';
                } else {
                  eyeStyle = 'normal';
                }
                mouthStyle = 'none';
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
                leftArmAngle: leftArmAngle,
                rightArmAngle: rightArmAngle,
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

// Objeto pixel decorativo
class _PixelObject {
  final String type;
  final double x;
  final double y;
  final double progress;
  final Color color;
  _PixelObject({required this.type, required this.x, required this.y, required this.progress, required this.color});
}

class _ClawdPainter extends CustomPainter {
  final double blink; 
  final Color? glowColor;
  final bool isSleeping;
  final AssistantAnimation activeAnim;
  final double actionProgress;
  final double leftArmAngle;
  final double rightArmAngle;
  final double leftLegOffset;
  final double rightLegOffset;
  final String eyeStyle;
  final String mouthStyle;
  final List<_PixelObject> pixelObjects;

  _ClawdPainter({
    required this.blink, 
    this.glowColor, 
    this.isSleeping = false,
    this.activeAnim = AssistantAnimation.idle,
    this.actionProgress = 0.0,
    this.leftArmAngle = 0.0,
    this.rightArmAngle = 0.0,
    this.leftLegOffset = 0.0,
    this.rightLegOffset = 0.0,
    this.eyeStyle = 'normal',
    this.mouthStyle = 'none',
    this.pixelObjects = const [],
  });

  static const Color body = Color(0xFF6C63FF);
  static const Color bodyDark = Color(0xFF5549E0);
  static const Color bodyLight = Color(0xFF8B85FF);
  static const Color eye = Color(0xFF111111);
  static const double px = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 72;
    canvas.save();
    canvas.scale(scale, scale);

    final paint = Paint()..isAntiAlias = false;
    
    if (glowColor != null) {
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 72, 60), 
        Paint()..color = glowColor!..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
      );
    }

    void rect(double x, double y, double w, double h, Color c) {
      paint.color = c;
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint);
    }

    // ====== BRAZOS (debajo del cuerpo) ======
    _drawArm(canvas, paint, true, leftArmAngle);
    _drawArm(canvas, paint, false, rightArmAngle);

    // ====== CUERPO PRINCIPAL ======
    // Cabeza (parte superior)
    rect(9, 0, 54, 10, body);
    // Reflejo en cabeza (detalle pixel)
    rect(12, 1, 6, 2, bodyLight);
    
    // Cara
    rect(9, 10, 54, 9, body);
    
    // Torso (mas ancho)
    rect(0, 19, 72, 10, body);
    // Sombra abdominal sutil
    rect(20, 24, 32, 3, bodyDark);
    
    // Cadera
    rect(9, 29, 54, 9, body);

    // ====== PIERNAS (articuladas) ======
    rect(13 + leftLegOffset, 38, 5, 10, body);
    rect(22 + leftLegOffset * 0.5, 38, 5, 10, body);
    rect(45 + rightLegOffset * 0.5, 38, 4, 10, body);
    rect(54 + rightLegOffset, 38, 4, 10, body);
    // Zapatos pixel
    rect(12 + leftLegOffset, 46, 7, 2, bodyDark);
    rect(21 + leftLegOffset * 0.5, 46, 7, 2, bodyDark);
    rect(44 + rightLegOffset * 0.5, 46, 6, 2, bodyDark);
    rect(53 + rightLegOffset, 46, 6, 2, bodyDark);

    // ====== OJOS (expresivos) ======
    _drawEyes(canvas, paint, eyeStyle, blink);

    // ====== BOCA ======
    _drawMouth(canvas, paint, mouthStyle);

    // ====== OBJETOS PIXEL DECORATIVOS ======
    for (final obj in pixelObjects) {
      _drawPixelObject(canvas, paint, obj);
    }

    canvas.restore();
  }

  void _drawArm(Canvas canvas, Paint paint, bool isLeft, double angle) {
    canvas.save();
    
    if (isLeft) {
      canvas.translate(5, 20);
    } else {
      canvas.translate(67, 20);
    }
    
    canvas.rotate(isLeft ? -angle : angle);
    
    // Brazo (2 segmentos pixel)
    paint.color = body;
    canvas.drawRect(Rect.fromLTWH(isLeft ? -6 : 0, 0, 6, px), paint);
    paint.color = bodyDark;
    canvas.drawRect(Rect.fromLTWH(isLeft ? -6 : 0, px, 6, px * 2), paint);
    // Mano (pixel mas claro)
    paint.color = bodyLight;
    canvas.drawRect(Rect.fromLTWH(isLeft ? -6 : 2, px * 3, 4, px), paint);
    
    canvas.restore();
  }

  void _drawEyes(Canvas canvas, Paint paint, String style, double blink) {
    switch (style) {
      case 'happy':
        paint.color = eye;
        canvas.drawRect(Rect.fromLTWH(16, 14, px, px), paint);
        canvas.drawRect(Rect.fromLTWH(19, 12, px, px), paint);
        canvas.drawRect(Rect.fromLTWH(22, 14, px, px), paint);
        canvas.drawRect(Rect.fromLTWH(47, 14, px, px), paint);
        canvas.drawRect(Rect.fromLTWH(50, 12, px, px), paint);
        canvas.drawRect(Rect.fromLTWH(53, 14, px, px), paint);
        break;
      case 'sad':
        paint.color = eye;
        canvas.drawRect(Rect.fromLTWH(16, 12, px, px), paint);
        canvas.drawRect(Rect.fromLTWH(19, 14, px, px), paint);
        canvas.drawRect(Rect.fromLTWH(22, 12, px, px), paint);
        canvas.drawRect(Rect.fromLTWH(47, 12, px, px), paint);
        canvas.drawRect(Rect.fromLTWH(50, 14, px, px), paint);
        canvas.drawRect(Rect.fromLTWH(53, 12, px, px), paint);
        break;
      case 'angry':
        final eyeH = 9 * (1 - blink);
        final eyeY = 10 + (9 - eyeH) / 2;
        paint.color = eye;
        canvas.drawRect(Rect.fromLTWH(18, eyeY, 4, eyeH), paint);
        canvas.drawRect(Rect.fromLTWH(49, eyeY, 5, eyeH), paint);
        paint.color = const Color(0xFF333333);
        canvas.drawRect(Rect.fromLTWH(15, 8, 10, 2), paint);
        canvas.drawRect(Rect.fromLTWH(17, 7, 4, 2), paint);
        canvas.drawRect(Rect.fromLTWH(47, 8, 10, 2), paint);
        canvas.drawRect(Rect.fromLTWH(52, 7, 4, 2), paint);
        break;
      case 'star':
        _drawMiniStar(canvas, paint, 19, 13, Colors.yellowAccent);
        _drawMiniStar(canvas, paint, 50, 13, Colors.yellowAccent);
        break;
      case 'dollar':
        paint.color = Colors.greenAccent;
        canvas.drawRect(Rect.fromLTWH(17, 10, 6, px), paint);
        canvas.drawRect(Rect.fromLTWH(17, 10 + px, px, px), paint);
        canvas.drawRect(Rect.fromLTWH(17, 10 + px * 2, 6, px), paint);
        canvas.drawRect(Rect.fromLTWH(20, 10 + px * 3, px, px), paint);
        canvas.drawRect(Rect.fromLTWH(17, 10 + px * 4, 6, px), paint);
        canvas.drawRect(Rect.fromLTWH(48, 10, 6, px), paint);
        canvas.drawRect(Rect.fromLTWH(48, 10 + px, px, px), paint);
        canvas.drawRect(Rect.fromLTWH(48, 10 + px * 2, 6, px), paint);
        canvas.drawRect(Rect.fromLTWH(51, 10 + px * 3, px, px), paint);
        canvas.drawRect(Rect.fromLTWH(48, 10 + px * 4, 6, px), paint);
        break;
      case 'heart':
        _drawMiniHeart(canvas, paint, 17, 11, Colors.pinkAccent);
        _drawMiniHeart(canvas, paint, 48, 11, Colors.pinkAccent);
        break;
      case 'dizzy':
        paint.color = eye;
        canvas.drawRect(Rect.fromLTWH(17, 11, px, px), paint);
        canvas.drawRect(Rect.fromLTWH(23, 11, px, px), paint);
        canvas.drawRect(Rect.fromLTWH(20, 13, px, px), paint);
        canvas.drawRect(Rect.fromLTWH(17, 15, px, px), paint);
        canvas.drawRect(Rect.fromLTWH(23, 15, px, px), paint);
        canvas.drawRect(Rect.fromLTWH(48, 11, px, px), paint);
        canvas.drawRect(Rect.fromLTWH(54, 11, px, px), paint);
        canvas.drawRect(Rect.fromLTWH(51, 13, px, px), paint);
        canvas.drawRect(Rect.fromLTWH(48, 15, px, px), paint);
        canvas.drawRect(Rect.fromLTWH(54, 15, px, px), paint);
        break;
      case 'sleep':
        paint.color = eye;
        canvas.drawRect(Rect.fromLTWH(16, 14, 10, 2), paint);
        canvas.drawRect(Rect.fromLTWH(47, 14, 10, 2), paint);
        break;
      case 'lookLeft':
        final eyeH = 9 * (1 - blink);
        final eyeY = 10 + (9 - eyeH) / 2;
        paint.color = eye;
        canvas.drawRect(Rect.fromLTWH(15, eyeY, 4, eyeH), paint);
        canvas.drawRect(Rect.fromLTWH(46, eyeY, 5, eyeH), paint);
        break;
      case 'lookRight':
        final eyeH = 9 * (1 - blink);
        final eyeY = 10 + (9 - eyeH) / 2;
        paint.color = eye;
        canvas.drawRect(Rect.fromLTWH(21, eyeY, 4, eyeH), paint);
        canvas.drawRect(Rect.fromLTWH(52, eyeY, 5, eyeH), paint);
        break;
      default:
        final eyeH = 9 * (1 - blink);
        final eyeY = 10 + (9 - eyeH) / 2;
        paint.color = eye;
        canvas.drawRect(Rect.fromLTWH(18, eyeY, 4, eyeH), paint);
        canvas.drawRect(Rect.fromLTWH(49, eyeY, 5, eyeH), paint);
    }
  }

  void _drawMouth(Canvas canvas, Paint paint, String style) {
    switch (style) {
      case 'smile':
        paint.color = const Color(0xFF222222);
        canvas.drawRect(Rect.fromLTWH(28, 25, px, px), paint);
        canvas.drawRect(Rect.fromLTWH(31, 27, 10, px), paint);
        canvas.drawRect(Rect.fromLTWH(41, 25, px, px), paint);
        break;
      case 'frown':
        paint.color = const Color(0xFF222222);
        canvas.drawRect(Rect.fromLTWH(28, 27, px, px), paint);
        canvas.drawRect(Rect.fromLTWH(31, 25, 10, px), paint);
        canvas.drawRect(Rect.fromLTWH(41, 27, px, px), paint);
        break;
      case 'open':
        paint.color = const Color(0xFF222222);
        canvas.drawRect(Rect.fromLTWH(30, 24, 12, 6), paint);
        paint.color = const Color(0xFF661111);
        canvas.drawRect(Rect.fromLTWH(31, 25, 10, 4), paint);
        break;
      case 'teeth':
        paint.color = const Color(0xFF222222);
        canvas.drawRect(Rect.fromLTWH(28, 24, 16, 6), paint);
        paint.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(29, 24, 14, 2), paint);
        paint.color = const Color(0xFF222222);
        canvas.drawRect(Rect.fromLTWH(33, 24, 1, 2), paint);
        canvas.drawRect(Rect.fromLTWH(37, 24, 1, 2), paint);
        canvas.drawRect(Rect.fromLTWH(41, 24, 1, 2), paint);
        break;
      case 'tongue':
        paint.color = const Color(0xFF222222);
        canvas.drawRect(Rect.fromLTWH(30, 24, 12, 5), paint);
        paint.color = Colors.pinkAccent;
        canvas.drawRect(Rect.fromLTWH(33, 27, 6, 4), paint);
        break;
      default:
        break;
    }
  }

  void _drawMiniStar(Canvas canvas, Paint paint, double cx, double cy, Color c) {
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
    canvas.drawRect(Rect.fromLTWH(cx, cy + 2, 8, 2), paint);
    canvas.drawRect(Rect.fromLTWH(cx + 1, cy + 4, 6, 2), paint);
    canvas.drawRect(Rect.fromLTWH(cx + 2, cy + 6, 4, 1), paint);
    canvas.drawRect(Rect.fromLTWH(cx + 3, cy + 7, 2, 1), paint);
  }

  void _drawPixelObject(Canvas canvas, Paint paint, _PixelObject obj) {
    final x = obj.x;
    final y = obj.y;
    final sinPi = math.sin(obj.progress * math.pi);
    final alpha = ((1.0 - obj.progress) * 255).clamp(0, 255).toInt();
    final fadeColor = obj.color.withAlpha(alpha);
    paint.color = fadeColor;

    switch (obj.type) {
      case 'coin':
        canvas.drawRect(Rect.fromLTWH(x + 1, y, 4, 1), paint);
        canvas.drawRect(Rect.fromLTWH(x, y + 1, 6, 4), paint);
        canvas.drawRect(Rect.fromLTWH(x + 1, y + 5, 4, 1), paint);
        paint.color = Colors.amber.shade800.withAlpha(alpha);
        canvas.drawRect(Rect.fromLTWH(x + 2, y + 2, 2, 2), paint);
        break;
      case 'bill':
        paint.color = fadeColor;
        canvas.drawRect(Rect.fromLTWH(x, y, 10, 6), paint);
        paint.color = Colors.green.shade900.withAlpha(alpha);
        canvas.drawRect(Rect.fromLTWH(x + 1, y + 1, 8, 4), paint);
        paint.color = fadeColor;
        canvas.drawRect(Rect.fromLTWH(x + 3, y + 2, 4, 2), paint);
        break;
      case 'heart':
        _drawMiniHeart(canvas, paint, x, y, fadeColor);
        break;
      case 'star4':
        _drawMiniStar(canvas, paint, x, y, fadeColor);
        break;
      case 'lightning':
        paint.color = fadeColor;
        canvas.drawRect(Rect.fromLTWH(x + 3, y, 3, 2), paint);
        canvas.drawRect(Rect.fromLTWH(x + 2, y + 2, 3, 2), paint);
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
        canvas.drawRect(Rect.fromLTWH(x, y + 5, 30, 5), paint);
        canvas.drawRect(Rect.fromLTWH(x, y + 2, 3, 3), paint);
        canvas.drawRect(Rect.fromLTWH(x + 13, y, 4, 5), paint);
        canvas.drawRect(Rect.fromLTWH(x + 27, y + 2, 3, 3), paint);
        paint.color = Colors.redAccent.withAlpha(alpha);
        canvas.drawRect(Rect.fromLTWH(x + 7, y + 6, 3, 2), paint);
        paint.color = Colors.blueAccent.withAlpha(alpha);
        canvas.drawRect(Rect.fromLTWH(x + 20, y + 6, 3, 2), paint);
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
      case 'sparkle':
        paint.color = fadeColor;
        canvas.drawRect(Rect.fromLTWH(x + 1, y, 1, 1), paint);
        canvas.drawRect(Rect.fromLTWH(x, y + 1, 1, 1), paint);
        canvas.drawRect(Rect.fromLTWH(x + 2, y + 1, 1, 1), paint);
        canvas.drawRect(Rect.fromLTWH(x + 1, y + 2, 1, 1), paint);
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
      case 'thought':
        paint.color = fadeColor;
        canvas.drawRect(Rect.fromLTWH(x + 2, y, 10, 2), paint);
        canvas.drawRect(Rect.fromLTWH(x, y + 2, 14, 6), paint);
        canvas.drawRect(Rect.fromLTWH(x + 2, y + 8, 10, 2), paint);
        canvas.drawRect(Rect.fromLTWH(x - 2, y + 12, 3, 2), paint);
        canvas.drawRect(Rect.fromLTWH(x - 5, y + 16, 2, 2), paint);
        paint.color = body.withAlpha((alpha * 0.8).toInt());
        canvas.drawRect(Rect.fromLTWH(x + 3, y + 4, 2, 2), paint);
        canvas.drawRect(Rect.fromLTWH(x + 6, y + 4, 2, 2), paint);
        canvas.drawRect(Rect.fromLTWH(x + 9, y + 4, 2, 2), paint);
        break;
      case 'angerCloud':
        paint.color = fadeColor;
        canvas.drawRect(Rect.fromLTWH(x + 2, y, 6, 3), paint);
        canvas.drawRect(Rect.fromLTWH(x, y + 3, 10, 4), paint);
        canvas.drawRect(Rect.fromLTWH(x + 1, y + 7, 8, 2), paint);
        paint.color = Colors.white.withAlpha(alpha);
        canvas.drawRect(Rect.fromLTWH(x + 3, y + 4, 1, 1), paint);
        canvas.drawRect(Rect.fromLTWH(x + 6, y + 4, 1, 1), paint);
        break;
    }
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
      '$_displayedText${_currentIndex < widget.text.length ? '\u258A' : ''}',
      style: widget.style,
    );
  }
}
