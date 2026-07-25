import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/virtual_assistant_provider.dart';

class AnimacionesTestScreen extends ConsumerWidget {
  const AnimacionesTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: const Text('Test Animaciones Rocky', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppTheme.textPrimary)),
        backgroundColor: AppTheme.bgCanvas,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Pulsa cualquier botón para forzar una animación de Rocky.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 20),
          
          // Todas las animaciones enumeradas
          _buildAnim(ref, 'Idle (Reposo)', AssistantAnimation.idle, Icons.accessibility_new_rounded, Colors.grey),
          _buildAnim(ref, 'Jump (Salto)', AssistantAnimation.jump, Icons.arrow_upward_rounded, Colors.blueAccent),
          _buildAnim(ref, 'Shake (Sacudida)', AssistantAnimation.shake, Icons.vibration_rounded, Colors.orangeAccent),
          _buildAnim(ref, 'Stretch (Estirarse)', AssistantAnimation.stretch, Icons.height_rounded, Colors.teal),
          _buildAnim(ref, 'Shrink (Encogerse)', AssistantAnimation.shrink, Icons.compress_rounded, Colors.brown),
          _buildAnim(ref, 'Nod (Asentir)', AssistantAnimation.nod, Icons.check_rounded, Colors.green),
          _buildAnim(ref, 'Glitch (Error temporal)', AssistantAnimation.glitch, Icons.bug_report_rounded, Colors.red),
          _buildAnim(ref, 'Glow Green (Acierto)', AssistantAnimation.glowGreen, Icons.lightbulb_rounded, Colors.greenAccent),
          _buildAnim(ref, 'Glow Red (Peligro)', AssistantAnimation.glowRed, Icons.lightbulb_rounded, Colors.redAccent),
          _buildAnim(ref, 'Spin (Giro)', AssistantAnimation.spin, Icons.rotate_right_rounded, Colors.pinkAccent),
          _buildAnim(ref, 'Alert (Alerta)', AssistantAnimation.alert, Icons.warning_amber_rounded, Colors.deepOrange),
          _buildAnim(ref, 'Happy (Feliz)', AssistantAnimation.happy, Icons.sentiment_very_satisfied_rounded, Colors.yellow),
          _buildAnim(ref, 'Thinking (Pensando)', AssistantAnimation.thinking, Icons.psychology_rounded, Colors.deepPurpleAccent),
          _buildAnim(ref, 'Sleep (Dormir)', AssistantAnimation.sleep, Icons.bedtime_rounded, Colors.indigoAccent),
          _buildAnim(ref, 'Flip (Voltereta)', AssistantAnimation.flip, Icons.flip_camera_android_rounded, Colors.cyan),
          _buildAnim(ref, 'Confused (Confundido)', AssistantAnimation.confused, Icons.question_mark_rounded, Colors.purpleAccent),
          _buildAnim(ref, 'Celebration (Celebración)', AssistantAnimation.celebration, Icons.celebration_rounded, Colors.yellowAccent),
          _buildAnim(ref, 'Warning Severe (Pánico)', AssistantAnimation.warningSevere, Icons.warning_rounded, Colors.redAccent),
          _buildAnim(ref, 'Sad (Triste)', AssistantAnimation.sad, Icons.sentiment_dissatisfied_rounded, Colors.blueGrey),
          _buildAnim(ref, 'Wealthy (Lluvia Dinero)', AssistantAnimation.wealthy, Icons.attach_money_rounded, Colors.green),
          _buildAnim(ref, 'Hide (Esconderse)', AssistantAnimation.hide, Icons.visibility_off_rounded, Colors.grey),
          _buildAnim(ref, 'Workout (Flexiones)', AssistantAnimation.workout, Icons.fitness_center_rounded, Colors.orangeAccent),
          _buildAnim(ref, 'Flying Stars (Volar con Estrellas)', AssistantAnimation.flyingStars, Icons.stars_rounded, Colors.white, bg: Colors.blueAccent),
        ],
      ),
    );
  }

  Widget _buildAnim(WidgetRef ref, String title, AssistantAnimation anim, IconData icon, Color color, {Color? bg}) {
    return _AnimButton(
      title: title,
      icon: icon,
      color: color,
      bg: bg,
      onTap: () {
        ref.read(virtualAssistantProvider.notifier).forceAnimation(
          anim, 
          'Probando animación: $title',
        );
      },
    );
  }
}

class _AnimButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Color? bg;
  final VoidCallback onTap;

  const _AnimButton({required this.title, required this.icon, required this.color, this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: bg ?? AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: bg != null ? Colors.white : AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(Icons.play_arrow_rounded, color: bg != null ? Colors.white70 : AppTheme.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
