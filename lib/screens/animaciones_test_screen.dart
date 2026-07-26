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
          const Text('Pulsa cualquier boton para forzar una animacion de Rocky.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 12),
          _sectionHeader('Animaciones Clasicas'),
          const SizedBox(height: 8),
          
          // Animaciones existentes
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
          _buildAnim(ref, 'Celebration (Celebracion)', AssistantAnimation.celebration, Icons.celebration_rounded, Colors.yellowAccent),
          _buildAnim(ref, 'Warning Severe (Panico)', AssistantAnimation.warningSevere, Icons.warning_rounded, Colors.redAccent),
          _buildAnim(ref, 'Sad (Triste)', AssistantAnimation.sad, Icons.sentiment_dissatisfied_rounded, Colors.blueGrey),
          _buildAnim(ref, 'Wealthy (Lluvia Dinero)', AssistantAnimation.wealthy, Icons.attach_money_rounded, Colors.green),
          _buildAnim(ref, 'Hide (Esconderse)', AssistantAnimation.hide, Icons.visibility_off_rounded, Colors.grey),
          _buildAnim(ref, 'Workout (Flexiones)', AssistantAnimation.workout, Icons.fitness_center_rounded, Colors.orangeAccent),
          _buildAnim(ref, 'Flying Stars (Volar con Estrellas)', AssistantAnimation.flyingStars, Icons.stars_rounded, Colors.white, bg: Colors.blueAccent),
          
          const SizedBox(height: 24),
          _sectionHeader('Nuevas Animaciones Articuladas'),
          const SizedBox(height: 8),
          
          // Nuevas animaciones
          _buildAnim(ref, 'Wave (Saludo)', AssistantAnimation.wave, Icons.waving_hand_rounded, Colors.amberAccent),
          _buildAnim(ref, 'Clap (Aplaudir)', AssistantAnimation.clap, Icons.back_hand_rounded, Colors.yellowAccent),
          _buildAnim(ref, 'Dance (Bailar)', AssistantAnimation.dance, Icons.music_note_rounded, Colors.pinkAccent),
          _buildAnim(ref, 'Angry (Enojado)', AssistantAnimation.angry, Icons.mood_bad_rounded, Colors.red),
          _buildAnim(ref, 'Love (Enamorado)', AssistantAnimation.love, Icons.favorite_rounded, Colors.pinkAccent),
          _buildAnim(ref, 'Facepalm (Mano en cara)', AssistantAnimation.facepalm, Icons.face_rounded, Colors.brown),
          _buildAnim(ref, 'Thumbs Up (Pulgar arriba)', AssistantAnimation.thumbsUp, Icons.thumb_up_rounded, Colors.blueAccent),
          _buildAnim(ref, 'Running (Corriendo)', AssistantAnimation.running, Icons.directions_run_rounded, Colors.orangeAccent),
          _buildAnim(ref, 'Typing (Calculando)', AssistantAnimation.typing, Icons.keyboard_rounded, Colors.cyanAccent),
          _buildAnim(ref, 'Shielding (Protegiendo)', AssistantAnimation.shielding, Icons.shield_rounded, Colors.blueAccent),
          _buildAnim(ref, 'Rocket (Despegue)', AssistantAnimation.rocket, Icons.rocket_launch_rounded, Colors.orangeAccent, bg: const Color(0xFF1A237E)),
          _buildAnim(ref, 'Crown (Victoria)', AssistantAnimation.crown, Icons.emoji_events_rounded, Colors.amberAccent),
          _buildAnim(ref, 'Rainy (Dia lluvioso)', AssistantAnimation.rainy, Icons.water_drop_rounded, Colors.lightBlueAccent),
          _buildAnim(ref, 'Flexing (Musculo)', AssistantAnimation.flexing, Icons.fitness_center_rounded, Colors.yellowAccent),
          _buildAnim(ref, 'Look Around (Mirando)', AssistantAnimation.lookAround, Icons.visibility_rounded, Colors.tealAccent),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withAlpha(40)),
      ),
      child: Row(
        children: [
          Icon(Icons.animation_rounded, color: AppTheme.primary, size: 18),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 14)),
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
          'Probando animacion: $title',
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
