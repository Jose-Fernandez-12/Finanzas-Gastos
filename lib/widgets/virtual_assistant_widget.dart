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
            Stack(
              alignment: Alignment.topRight,
              children: [
                AnimatedAvatar(
                  animation: state.animation,
                  controller: _controller,
                ),
                if (state.themeIcon != null && state.isVisible)
                  Positioned(
                    top: -10,
                    right: -10,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Text(
                            state.themeIcon!,
                            style: const TextStyle(fontSize: 22),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PixelArtPainter extends CustomPainter {
  final Color color;
  _PixelArtPainter({required this.color});

  // Sprite exacto de Rocky (igual a la imagen de referencia)
  static const List<String> sprite = [
    "   ##################   ", // 0
    "   ##################   ", // 1
    "   ##################   ", // 2
    "   ###   ######   ###   ", // 3 (Eyes)
    "   ###   ######   ###   ", // 4
    "   ###   ######   ###   ", // 5
    "   ###   ######   ###   ", // 6
    "########################", // 7 (Arms)
    "########################", // 8
    "########################", // 9
    "   ##################   ", // 10 (Body below arms)
    "   ##################   ", // 11
    "   ##################   ", // 12 (Solid body instead of legs gap!)
    "   ###   ##  ##   ###   ", // 13 (Legs perfectly aligned with eyes)
    "   ###   ##  ##   ###   ", // 14
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    // Resplandor
    final glowPaint = Paint()
      ..color = color.withAlpha(80)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);

    final rows = sprite.length;
    final cols = sprite[0].length;
    
    // Forzar píxeles perfectamente cuadrados (3x3)
    const double pixelSize = 3.0; 
    final double spriteW = cols * pixelSize; 
    final double spriteH = rows * pixelSize; 
    
    // Centrar el sprite dentro del canvas
    final double offsetX = (size.width - spriteW) / 2;
    final double offsetY = (size.height - spriteH) / 2;

    final path = Path();

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        if (sprite[y][x] == '#') {
          path.addRect(Rect.fromLTWH(offsetX + x * pixelSize, offsetY + y * pixelSize, pixelSize, pixelSize));
        }
      }
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

class AnimatedAvatar extends StatelessWidget {
  final AssistantAnimation animation;
  final AnimationController controller;
  
  const AnimatedAvatar({super.key, required this.animation, required this.controller});
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final floatOffset = math.sin(controller.value * math.pi) * 8.0;
        
        double scaleX = 1.0;
        double scaleY = 1.0;
        double transX = 0.0;
        double transY = floatOffset;
        double rotZ = 0.0;
        double rotY = 0.0;
        Color filterColor = const Color(0xFFD4B886);
        
        final v = controller.value;
        
        switch (animation) {
          case AssistantAnimation.jump:
            transY = -math.sin(v * math.pi) * 20.0;
            break;
          case AssistantAnimation.shake:
            transX = math.sin(v * math.pi * 12) * 8.0;
            break;
          case AssistantAnimation.stretch:
            scaleY = 1.0 + math.sin(v * math.pi) * 0.5;
            scaleX = 1.0 - math.sin(v * math.pi) * 0.3;
            break;
          case AssistantAnimation.shrink:
            scaleY = 1.0 - math.sin(v * math.pi) * 0.5;
            scaleX = 1.0 + math.sin(v * math.pi) * 0.3;
            transY = floatOffset + 15;
            break;
          case AssistantAnimation.spin:
            rotZ = v * 2 * math.pi;
            break;
          case AssistantAnimation.flip:
            rotY = v * 2 * math.pi;
            break;
          case AssistantAnimation.glowGreen:
            filterColor = Color.lerp(const Color(0xFFD4B886), Colors.greenAccent, math.sin(v * math.pi))!;
            scaleX = 1.0 + math.sin(v * math.pi) * 0.2;
            scaleY = 1.0 + math.sin(v * math.pi) * 0.2;
            break;
          case AssistantAnimation.glowRed:
            filterColor = Color.lerp(const Color(0xFFD4B886), Colors.redAccent, math.sin(v * math.pi))!;
            transX = math.sin(v * math.pi * 12) * 5.0; 
            break;
          case AssistantAnimation.nod:
            rotZ = math.sin(v * math.pi * 6) * 0.4;
            break;
          case AssistantAnimation.glitch:
            transX = (math.Random().nextDouble() - 0.5) * 15.0;
            transY = floatOffset + (math.Random().nextDouble() - 0.5) * 15.0;
            filterColor = math.Random().nextBool() ? Colors.cyanAccent : Colors.redAccent;
            break;
          case AssistantAnimation.idle:
          default:
            break;
        }

        return Transform(
          transform: Matrix4.identity()
            ..translate(transX, transY)
            ..rotateZ(rotZ)
            ..rotateY(rotY)
            ..scale(scaleX, scaleY),
          alignment: Alignment.center,
          child: SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: _PixelArtPainter(color: filterColor),
            ),
          ),
        );
      },
    );
  }
}

