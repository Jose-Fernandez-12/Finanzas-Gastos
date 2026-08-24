import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

enum EyeState {
  normal,
  happy,
  sad,
  angry,
  dizzy,
  star,
  dollar,
  heart,
  closed,
  lookLeft,
  lookRight,
  teeth,
  sleep,
}

enum MouthState { neutral, smile, open, teeth, tight, frown, none }

enum ParticleType {
  sparks,
  greenSparkles,
  redLightning,
  yellowSparkles,
  confetti,
  coins,
  sweatDrops,
  starTrail,
  zzz,
  billFlutter,
  musicNotes,
  angerCloud,
  hearts,
  dustTrail,
  numbersCyanGreen,
  shieldBlue,
  flame,
  crownDescend,
  rainCloud,
  sparksAtFists,
  questionMarks,
  thoughtBubble,
  tear,
  exclamation,
}

class PixelObject {
  final String type;
  final double x;
  final double y;
  final double progress;
  final double delay;
  final Color color;
  PixelObject({
    required this.type,
    required this.x,
    required this.y,
    required this.progress,
    this.delay = 0.0,
    required this.color,
  });
}

class RockyRig {
  static const Offset center = Offset(36, 24);
  static const Offset leftShoulder = Offset(5, 20);
  static const Offset rightShoulder = Offset(67, 20);
  static const Offset leftHip = Offset(18, 38);
  static const Offset rightHip = Offset(48, 38);
}

class RockyPose {
  final Offset bodyOffset;
  final double bodyScaleX;
  final double bodyScaleY;
  final double bodyRotation;
  final double leftArmAngle;
  final double rightArmAngle;
  final double rightArmOffsetX;
  final double leftLegAngle;
  final double rightLegAngle;
  final double leftLegOffset;
  final double rightLegOffset;
  final EyeState eyeState;
  final MouthState mouthState;
  final Color? glowColor;
  final List<PixelObject> particles;

  const RockyPose({
    this.bodyScaleX = 1.0,
    this.bodyScaleY = 1.0,
    this.bodyRotation = 0.0,
    this.bodyOffset = Offset.zero,
    this.leftArmAngle = 0.0,
    this.rightArmAngle = 0.0,
    this.rightArmOffsetX = 0.0,
    this.leftLegAngle = 0.0,
    this.rightLegAngle = 0.0,
    this.leftLegOffset = 0.0,
    this.rightLegOffset = 0.0,
    this.eyeState = EyeState.normal,
    this.mouthState = MouthState.none,
    this.glowColor,
    this.particles = const [],
  });

  RockyPose copyWith({
    Offset? bodyOffset,
    double? bodyScaleX,
    double? bodyScaleY,
    double? bodyRotation,
    double? leftArmAngle,
    double? rightArmAngle,
    double? rightArmOffsetX,
    double? leftLegAngle,
    double? rightLegAngle,
    double? leftLegOffset,
    double? rightLegOffset,
    EyeState? eyeState,
    MouthState? mouthState,
    Color? glowColor,
    List<PixelObject>? particles,
  }) {
    return RockyPose(
      bodyOffset: bodyOffset ?? this.bodyOffset,
      bodyScaleX: bodyScaleX ?? this.bodyScaleX,
      bodyScaleY: bodyScaleY ?? this.bodyScaleY,
      bodyRotation: bodyRotation ?? this.bodyRotation,
      leftArmAngle: leftArmAngle ?? this.leftArmAngle,
      rightArmAngle: rightArmAngle ?? this.rightArmAngle,
      rightArmOffsetX: rightArmOffsetX ?? this.rightArmOffsetX,
      leftLegAngle: leftLegAngle ?? this.leftLegAngle,
      rightLegAngle: rightLegAngle ?? this.rightLegAngle,
      leftLegOffset: leftLegOffset ?? this.leftLegOffset,
      rightLegOffset: rightLegOffset ?? this.rightLegOffset,
      eyeState: eyeState ?? this.eyeState,
      mouthState: mouthState ?? this.mouthState,
      glowColor: glowColor ?? this.glowColor,
      particles: particles ?? this.particles,
    );
  }

  RockyPose lerp(RockyPose other, double t) {
    return RockyPose(
      bodyScaleX: lerpDouble(bodyScaleX, other.bodyScaleX, t) ?? 1.0,
      bodyScaleY: lerpDouble(bodyScaleY, other.bodyScaleY, t) ?? 1.0,
      bodyRotation: lerpDouble(bodyRotation, other.bodyRotation, t) ?? 0.0,
      bodyOffset: Offset.lerp(bodyOffset, other.bodyOffset, t) ?? Offset.zero,
      leftArmAngle: lerpDouble(leftArmAngle, other.leftArmAngle, t) ?? 0.0,
      rightArmAngle: lerpDouble(rightArmAngle, other.rightArmAngle, t) ?? 0.0,
      rightArmOffsetX: lerpDouble(rightArmOffsetX, other.rightArmOffsetX, t) ?? 0.0,
      leftLegAngle: lerpDouble(leftLegAngle, other.leftLegAngle, t) ?? 0.0,
      rightLegAngle: lerpDouble(rightLegAngle, other.rightLegAngle, t) ?? 0.0,
      leftLegOffset: lerpDouble(leftLegOffset, other.leftLegOffset, t) ?? 0.0,
      rightLegOffset: lerpDouble(rightLegOffset, other.rightLegOffset, t) ?? 0.0,
      eyeState: t > 0.5 ? other.eyeState : eyeState,
      mouthState: t > 0.5 ? other.mouthState : mouthState,
      glowColor: Color.lerp(glowColor, other.glowColor, t),
      particles: t > 0.5 ? other.particles : particles,
    );
  }
}

class BoneKeyframe {
  final double t;
  final double angle;
  final Curve curve;
  const BoneKeyframe(this.t, this.angle, [this.curve = Curves.linear]);
}

class RockyAnimationSpec {
  final String name;
  final Duration duration;
  final bool loop;
  final List<BoneKeyframe> leftArm, rightArm, rightArmOffsetX, leftLeg, rightLeg;
  final List<BoneKeyframe> bodyScaleX, bodyScaleY, bodyRotation;
  final List<BoneKeyframe> bodyOffsetX, bodyOffsetY;
  final EyeState eyeState;
  final List<MapEntry<double, EyeState>>? eyeSequence;
  final MouthState mouthState;
  final List<MapEntry<double, MouthState>>? mouthSequence;
  final Color? glowColor;
  final ParticleType? particleType;
  final double particleTriggerT;
  final bool particleContinuous;

  const RockyAnimationSpec({
    required this.name,
    required this.duration,
    this.loop = false,
    this.leftArm = const [],
    this.rightArm = const [],
    this.rightArmOffsetX = const [],
    this.leftLeg = const [],
    this.rightLeg = const [],
    this.bodyScaleX = const [],
    this.bodyScaleY = const [],
    this.bodyRotation = const [],
    this.bodyOffsetX = const [],
    this.bodyOffsetY = const [],
    this.eyeState = EyeState.normal,
    this.eyeSequence,
    this.mouthState = MouthState.neutral,
    this.mouthSequence,
    this.glowColor,
    this.particleType,
    this.particleTriggerT = 0.5,
    this.particleContinuous = false,
  });

  double evaluateTrack(
    List<BoneKeyframe> track,
    double t,
    double defaultValue,
  ) {
    if (track.isEmpty) return defaultValue;
    if (t <= track.first.t) return track.first.angle;
    if (t >= track.last.t) return track.last.angle;

    for (int i = 0; i < track.length - 1; i++) {
      final a = track[i];
      final b = track[i + 1];
      if (t >= a.t && t <= b.t) {
        final localT = (t - a.t) / (b.t - a.t);
        final curvedT = b.curve.transform(localT);
        return a.angle + (b.angle - a.angle) * curvedT;
      }
    }
    return defaultValue;
  }

  T _evaluateSequence<T>(double t, List<MapEntry<double, T>>? sequence, T defaultValue) {
    if (sequence == null || sequence.isEmpty) return defaultValue;
    T current = defaultValue;
    for (final entry in sequence) {
      if (t >= entry.key) {
        current = entry.value;
      }
    }
    return current;
  }

  List<PixelObject> _generateParticles(double t) {
    if (particleType == null) return const [];
    if (!particleContinuous && t < particleTriggerT) return const [];

    final List<PixelObject> objs = [];
    final p = (particleContinuous ? t : ((t - particleTriggerT) / (1.0 - particleTriggerT)).clamp(0.0, 1.0));

    switch (particleType!) {
      case ParticleType.coins:
      case ParticleType.billFlutter:
        final offsets = [Offset(-18, -10), Offset(8, -30), Offset(28, -12), Offset(-5, -38), Offset(42, -20)];
        for (int i = 0; i < offsets.length; i++) {
          final localP = ((p - i * 0.08) % 1.0).clamp(0.0, 1.0);
          objs.add(PixelObject(
            type: particleType == ParticleType.billFlutter ? 'bill' : 'coin',
            x: 36 + offsets[i].dx,
            y: offsets[i].dy - localP * 20,
            progress: localP,
            color: particleType == ParticleType.billFlutter ? const Color(0xFF4CD964) : const Color(0xFFFFCC00),
          ));
        }
        break;

      case ParticleType.greenSparkles:
      case ParticleType.sparks:
      case ParticleType.sparksAtFists:
        final positions = particleType == ParticleType.sparksAtFists
            ? [Offset(-20, 20), Offset(80, 20)]
            : [Offset(-15, -5), Offset(75, -5), Offset(30, -35), Offset(-5, -20), Offset(60, -20)];
        final color = particleType == ParticleType.greenSparkles ? const Color(0xFF4CD964) : const Color(0xFFFFE066);
        for (int i = 0; i < positions.length; i++) {
          final localP = ((p + i * 0.15) % 1.0);
          objs.add(PixelObject(
            type: 'star4',
            x: positions[i].dx + localP * 5,
            y: positions[i].dy - localP * 15,
            progress: localP,
            color: color,
          ));
        }
        break;

      case ParticleType.redLightning:
        for (int i = 0; i < 3; i++) {
          final lp = ((p + i * 0.33) % 1.0);
          objs.add(PixelObject(
            type: 'lightning',
            x: [-20, 70, 30][i].toDouble(),
            y: -15 - lp * 10,
            progress: lp,
            color: const Color(0xFFFF3B30),
          ));
        }
        break;

      case ParticleType.yellowSparkles:
        for (int i = 0; i < 4; i++) {
          final lp = ((p + i * 0.25) % 1.0);
          objs.add(PixelObject(
            type: 'star4',
            x: [-10, 70, 20, 55][i].toDouble(),
            y: -20 - lp * 15,
            progress: lp,
            color: const Color(0xFFFFD60A),
          ));
        }
        break;

      case ParticleType.confetti:
        final colors = [const Color(0xFFFF6B6B), const Color(0xFF4ECDC4), const Color(0xFFFFD93D), const Color(0xFF6BCB77), const Color(0xFFBB77FF)];
        for (int i = 0; i < 8; i++) {
          final lp = ((p + i * 0.12) % 1.0);
          objs.add(PixelObject(
            type: 'confetti',
            x: -15 + i * 12.0,
            y: -30 + lp * 50,
            progress: lp,
            color: colors[i % colors.length],
          ));
        }
        break;

      case ParticleType.hearts:
        for (int i = 0; i < 4; i++) {
          final lp = ((p + i * 0.22) % 1.0);
          objs.add(PixelObject(
            type: 'heart',
            x: [-18, 68, 15, 50][i].toDouble(),
            y: -10 - lp * 30,
            progress: lp,
            color: const Color(0xFFFF69B4),
          ));
        }
        break;

      case ParticleType.zzz:
        for (int i = 0; i < 3; i++) {
          final lp = ((p + i * 0.33) % 1.0);
          objs.add(PixelObject(
            type: 'zzz',
            x: 52 + i * 8.0,
            y: -5 - lp * 25,
            progress: lp,
            color: const Color(0xFF9B9BEF),
          ));
        }
        break;

      case ParticleType.musicNotes:
        for (int i = 0; i < 3; i++) {
          final lp = ((p + i * 0.33) % 1.0);
          objs.add(PixelObject(
            type: 'note',
            x: [-18, 68, 26][i].toDouble(),
            y: -10 - lp * 30,
            progress: lp,
            color: const Color(0xFFFFD60A),
          ));
        }
        break;

      case ParticleType.angerCloud:
        objs.add(PixelObject(
          type: 'angerCloud',
          x: 22,
          y: -28 + math.sin(p * math.pi * 4) * 4,
          progress: p < 0.5 ? 0 : (p - 0.5) * 2,
          color: const Color(0xFFFF6B6B),
        ));
        break;

      case ParticleType.dustTrail:
        for (int i = 0; i < 3; i++) {
          final lp = ((p + i * 0.25) % 1.0);
          objs.add(PixelObject(
            type: 'dust',
            x: -10 - i * 12.0,
            y: 35 - lp * 10,
            progress: lp,
            color: const Color(0xFFB0B0B0),
          ));
        }
        break;

      case ParticleType.numbersCyanGreen:
        for (int i = 0; i < 4; i++) {
          final lp = ((p + i * 0.2) % 1.0);
          objs.add(PixelObject(
            type: 'number',
            x: [-15, 70, 20, 50][i].toDouble(),
            y: -10 - lp * 25,
            progress: lp,
            color: i % 2 == 0 ? const Color(0xFF00FFCC) : const Color(0xFF00FF88),
          ));
        }
        break;

      case ParticleType.shieldBlue:
        objs.add(PixelObject(
          type: 'shield',
          x: 26,
          y: -22 - math.sin(p * math.pi) * 5,
          progress: p < 0.5 ? 0.0 : (p - 0.5) * 2,
          color: const Color(0xFF4DA6FF),
        ));
        break;

      case ParticleType.flame:
        for (int i = 0; i < 3; i++) {
          final lp = ((p + i * 0.2) % 1.0);
          objs.add(PixelObject(
            type: 'flame',
            x: [20, 36, 50][i].toDouble(),
            y: 38 + lp * 10,
            progress: lp,
            color: const Color(0xFFFF6D00),
          ));
        }
        break;

      case ParticleType.crownDescend:
        objs.add(PixelObject(
          type: 'crown',
          x: 21,
          y: -40 + p * 25, // Before: -40 + p * 10
          progress: p < 0.5 ? 0 : (p - 0.5) * 2,
          color: const Color(0xFFFFBF00),
        ));
        break;

      case ParticleType.rainCloud:
        // Nube encima
        objs.add(PixelObject(
          type: 'cloud',
          x: 16,
          y: -42,
          progress: 0,
          color: const Color(0xFF9DB8C8),
        ));
        // Gotas
        for (int i = 0; i < 5; i++) {
          final lp = ((p + i * 0.2) % 1.0);
          objs.add(PixelObject(
            type: 'drop',
            x: 15 + i * 10.0,
            y: -25 + lp * 35,
            progress: lp > 0.8 ? (lp - 0.8) * 5 : 0,
            color: const Color(0xFF6EB5E0),
          ));
        }
        break;

      case ParticleType.starTrail:
        for (int i = 0; i < 5; i++) {
          final lp = ((p + i * 0.15) % 1.0);
          objs.add(PixelObject(
            type: 'star4',
            x: -18 + lp * 90,
            y: -20 + i * 8.0,
            progress: lp,
            color: Colors.white,
          ));
        }
        break;

      case ParticleType.sweatDrops:
        for (int i = 0; i < 3; i++) {
          final lp = ((p + i * 0.3) % 1.0);
          objs.add(PixelObject(
            type: 'drop',
            x: [-16, 68, 26][i].toDouble(),
            y: -10 + lp * 20,
            progress: lp > 0.7 ? (lp - 0.7) * 3 : 0,
            color: const Color(0xFF6EB5E0),
          ));
        }
        break;

      case ParticleType.exclamation:
        objs.add(PixelObject(
          type: 'exclamation',
          x: 28,
          y: -40 + math.sin(p * math.pi * 4) * 5,
          progress: p > 0.8 ? (p - 0.8) * 5 : 0,
          color: const Color(0xFFFF3B30),
        ));
        break;

      case ParticleType.questionMarks:
        for (int i = 0; i < 3; i++) {
          final lp = ((p + i * 0.3) % 1.0);
          objs.add(PixelObject(
            type: 'question',
            x: [-15, 60, 22][i].toDouble(),
            y: -25 - lp * 15,
            progress: lp > 0.7 ? (lp - 0.7) * 3 : 0,
            color: Colors.white,
          ));
        }
        break;

      case ParticleType.thoughtBubble:
        objs.add(PixelObject(
          type: 'thought',
          x: 48,
          y: -32,
          progress: p < 0.4 ? 0 : (p - 0.4) / 0.6,
          color: Colors.white,
        ));
        break;

      case ParticleType.tear:
        for (int i = 0; i < 2; i++) {
          final lp = ((p + i * 0.4) % 1.0);
          objs.add(PixelObject(
            type: 'drop',
            x: [14, 54][i].toDouble(),
            y: 18 + lp * 20,
            progress: lp > 0.8 ? (lp - 0.8) * 5 : 0,
            color: const Color(0xFF6EB5E0),
          ));
        }
        break;
    }

    return objs;
  }

  RockyPose evaluate(double t) {
    final lArmDeg = evaluateTrack(leftArm, t, 0.0);
    final rArmDeg = evaluateTrack(rightArm, t, 0.0);

    return RockyPose(
      bodyScaleX: evaluateTrack(bodyScaleX, t, 1.0),
      bodyScaleY: evaluateTrack(bodyScaleY, t, 1.0),
      bodyRotation: evaluateTrack(bodyRotation, t, 0.0),
      bodyOffset: Offset(
        evaluateTrack(bodyOffsetX, t, 0.0),
        evaluateTrack(bodyOffsetY, t, 0.0),
      ),
      leftArmAngle: lArmDeg * (math.pi / 180.0),
      rightArmAngle: rArmDeg * (math.pi / 180.0),
      rightArmOffsetX: evaluateTrack(rightArmOffsetX, t, 0.0),
      leftLegOffset: evaluateTrack(leftLeg, t, 0.0),
      rightLegOffset: evaluateTrack(rightLeg, t, 0.0),
      eyeState: _evaluateSequence(t, eyeSequence, eyeState),
      mouthState: _evaluateSequence(t, mouthSequence, mouthState),
      glowColor: glowColor,
      particles: _generateParticles(t),
    );
  }

}

// 1. JUMP
final jump = RockyAnimationSpec(
  name: 'jump',
  duration: const Duration(milliseconds: 700),
  bodyScaleY: const [
    BoneKeyframe(0.0, 1.0), BoneKeyframe(0.15, 0.8, Curves.easeOut),
    BoneKeyframe(0.35, 1.25, Curves.easeOut), BoneKeyframe(0.6, 1.25),
    BoneKeyframe(0.85, 0.9, Curves.easeIn), BoneKeyframe(1.0, 1.0, Curves.easeOut),
  ],
  bodyScaleX: const [
    BoneKeyframe(0.0, 1.0), BoneKeyframe(0.15, 1.2, Curves.easeOut),
    BoneKeyframe(0.35, 0.85, Curves.easeOut), BoneKeyframe(0.6, 0.85),
    BoneKeyframe(0.85, 1.15, Curves.easeIn), BoneKeyframe(1.0, 1.0, Curves.easeOut),
  ],
  bodyOffsetY: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.35, -40, Curves.easeOut),
    BoneKeyframe(0.6, -40), BoneKeyframe(0.85, 0, Curves.easeIn), BoneKeyframe(1.0, 0),
  ],
  leftArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.3, 120, Curves.easeOut),
    BoneKeyframe(0.6, 120), BoneKeyframe(1.0, 0, Curves.easeIn),
  ],
  rightArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.3, -120, Curves.easeOut),
    BoneKeyframe(0.6, -120), BoneKeyframe(1.0, 0, Curves.easeIn),
  ],
  eyeState: EyeState.happy,
  mouthState: MouthState.smile,
);

// 2. SHAKE
final shake = RockyAnimationSpec(
  name: 'shake',
  duration: const Duration(milliseconds: 600),
  bodyOffsetX: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.1, 8), BoneKeyframe(0.2, -8),
    BoneKeyframe(0.3, 6), BoneKeyframe(0.4, -6), BoneKeyframe(0.5, 4),
    BoneKeyframe(0.6, -4), BoneKeyframe(0.7, 2), BoneKeyframe(0.8, -2),
    BoneKeyframe(1.0, 0),
  ],
  leftArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.2, -15), BoneKeyframe(0.4, 15),
    BoneKeyframe(0.6, -10), BoneKeyframe(0.8, 10), BoneKeyframe(1.0, 0),
  ],
  rightArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.2, 15), BoneKeyframe(0.4, -15),
    BoneKeyframe(0.6, 10), BoneKeyframe(0.8, -10), BoneKeyframe(1.0, 0),
  ],
  eyeState: EyeState.angry,
);

// 3. STRETCH
final stretch = RockyAnimationSpec(
  name: 'stretch',
  duration: const Duration(milliseconds: 900),
  bodyScaleY: const [
    BoneKeyframe(0.0, 1.0), BoneKeyframe(0.3, 1.28, Curves.easeOut),
    BoneKeyframe(0.7, 1.28), BoneKeyframe(1.0, 1.0, Curves.easeIn),
  ],
  bodyScaleX: const [
    BoneKeyframe(0.0, 1.0), BoneKeyframe(0.3, 0.85, Curves.easeOut),
    BoneKeyframe(0.7, 0.85), BoneKeyframe(1.0, 1.0, Curves.easeIn),
  ],
  bodyOffsetY: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.3, -15, Curves.easeOut),
    BoneKeyframe(0.7, -15), BoneKeyframe(1.0, 0, Curves.easeIn),
  ],
  leftArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.3, 140, Curves.easeOut),
    BoneKeyframe(0.7, 140), BoneKeyframe(1.0, 0, Curves.easeIn),
  ],
  rightArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.3, -140, Curves.easeOut),
    BoneKeyframe(0.7, -140), BoneKeyframe(1.0, 0, Curves.easeIn),
  ],
  eyeState: EyeState.happy,
);

// 4. SHRINK
final shrink = RockyAnimationSpec(
  name: 'shrink',
  duration: const Duration(milliseconds: 800),
  bodyScaleY: const [
    BoneKeyframe(0.0, 1.0), BoneKeyframe(0.35, 0.75, Curves.easeOut),
    BoneKeyframe(0.7, 0.75), BoneKeyframe(1.0, 1.0, Curves.easeIn),
  ],
  bodyScaleX: const [
    BoneKeyframe(0.0, 1.0), BoneKeyframe(0.35, 1.15, Curves.easeOut),
    BoneKeyframe(0.7, 1.15), BoneKeyframe(1.0, 1.0, Curves.easeIn),
  ],
  bodyOffsetY: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.35, 12, Curves.easeOut),
    BoneKeyframe(0.7, 12), BoneKeyframe(1.0, 0, Curves.easeIn),
  ],
  leftArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.35, 25, Curves.easeOut), BoneKeyframe(1.0, 0),
  ],
  rightArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.35, -25, Curves.easeOut), BoneKeyframe(1.0, 0),
  ],
  eyeState: EyeState.sad,
);

// 5. NOD
final nod = RockyAnimationSpec(
  name: 'nod',
  duration: const Duration(milliseconds: 700),
  loop: true,
  bodyOffsetY: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.25, 8, Curves.easeOut),
    BoneKeyframe(0.5, 0, Curves.easeIn), BoneKeyframe(0.75, 6, Curves.easeOut),
    BoneKeyframe(1.0, 0, Curves.easeIn),
  ],
  bodyScaleY: const [
    BoneKeyframe(0.0, 1.0), BoneKeyframe(0.25, 0.95), BoneKeyframe(0.5, 1.0),
    BoneKeyframe(0.75, 0.97), BoneKeyframe(1.0, 1.0),
  ],
  eyeState: EyeState.happy,
  mouthState: MouthState.smile,
);

// 6. GLITCH
final glitch = RockyAnimationSpec(
  name: 'glitch',
  duration: const Duration(milliseconds: 500),
  loop: true,
  bodyOffsetX: const [
    BoneKeyframe(0.0, 0, Curves.linear), BoneKeyframe(0.12, -10, Curves.linear),
    BoneKeyframe(0.24, 14, Curves.linear), BoneKeyframe(0.36, -6, Curves.linear),
    BoneKeyframe(0.5, 9, Curves.linear), BoneKeyframe(0.65, -12, Curves.linear),
    BoneKeyframe(0.8, 4, Curves.linear), BoneKeyframe(1.0, 0, Curves.linear),
  ],
  bodyOffsetY: const [
    BoneKeyframe(0.0, 0, Curves.linear), BoneKeyframe(0.2, 6, Curves.linear),
    BoneKeyframe(0.45, -8, Curves.linear), BoneKeyframe(0.7, 5, Curves.linear),
    BoneKeyframe(1.0, 0, Curves.linear),
  ],
  leftArm: const [
    BoneKeyframe(0.0, 0, Curves.linear), BoneKeyframe(0.3, -60, Curves.linear),
    BoneKeyframe(0.55, 40, Curves.linear), BoneKeyframe(0.8, -20, Curves.linear),
    BoneKeyframe(1.0, 0, Curves.linear),
  ],
  rightArm: const [
    BoneKeyframe(0.0, 0, Curves.linear), BoneKeyframe(0.25, 50, Curves.linear),
    BoneKeyframe(0.5, -70, Curves.linear), BoneKeyframe(0.75, 30, Curves.linear),
    BoneKeyframe(1.0, 0, Curves.linear),
  ],
  eyeState: EyeState.dizzy,
  particleType: ParticleType.sparks,
  particleContinuous: true,
);

// 7. GLOW GREEN
final glowGreen = RockyAnimationSpec(
  name: 'glowGreen',
  duration: const Duration(milliseconds: 700),
  bodyOffsetY: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.4, -35, Curves.easeOut),
    BoneKeyframe(0.7, -35), BoneKeyframe(1.0, 0, Curves.easeIn),
  ],
  leftArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.35, 120, Curves.easeOut), BoneKeyframe(1.0, 0, Curves.easeIn),
  ],
  rightArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.35, -120, Curves.easeOut), BoneKeyframe(1.0, 0, Curves.easeIn),
  ],
  eyeState: EyeState.star,
  glowColor: const Color(0xFF4CD964),
  particleType: ParticleType.greenSparkles,
  particleTriggerT: 0.4,
);

// 8. GLOW RED
final glowRed = RockyAnimationSpec(
  name: 'glowRed',
  duration: const Duration(milliseconds: 600),
  loop: true,
  bodyOffsetX: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.25, 6), BoneKeyframe(0.5, -6),
    BoneKeyframe(0.75, 4), BoneKeyframe(1.0, 0),
  ],
  eyeState: EyeState.angry,
  mouthState: MouthState.teeth,
  glowColor: const Color(0xFFFF3B30),
  particleType: ParticleType.redLightning,
  particleContinuous: true,
);

// 9. SPIN
final spin = RockyAnimationSpec(
  name: 'spin',
  duration: const Duration(milliseconds: 800),
  bodyScaleX: const [
    BoneKeyframe(0.0, 1.0), BoneKeyframe(0.25, 0.1, Curves.easeIn),
    BoneKeyframe(0.5, 1.0, Curves.easeOut), BoneKeyframe(0.75, 0.1, Curves.easeIn),
    BoneKeyframe(1.0, 1.0, Curves.easeOut),
  ],
  leftArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.5, 180), BoneKeyframe(1.0, 360),
  ],
  rightArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.5, -180), BoneKeyframe(1.0, -360),
  ],
  eyeState: EyeState.dizzy,
);

// 10. ALERT
final alert = RockyAnimationSpec(
  name: 'alert',
  duration: const Duration(milliseconds: 500),
  loop: true,
  bodyOffsetX: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.15, -10), BoneKeyframe(0.3, 10),
    BoneKeyframe(0.45, -6), BoneKeyframe(0.6, 6), BoneKeyframe(1.0, 0),
  ],
  bodyScaleY: const [
    BoneKeyframe(0.0, 1.0), BoneKeyframe(0.2, 0.92, Curves.easeOut), BoneKeyframe(1.0, 1.0),
  ],
  eyeState: EyeState.angry,
  glowColor: const Color(0xFFFF3B30),
  particleType: ParticleType.exclamation,
  particleTriggerT: 0.15,
);

// 11. HAPPY
final happy = RockyAnimationSpec(
  name: 'happy',
  duration: const Duration(milliseconds: 900),
  loop: true,
  bodyOffsetY: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.15, -18, Curves.easeOut),
    BoneKeyframe(0.3, 0, Curves.easeIn), BoneKeyframe(0.45, -18, Curves.easeOut),
    BoneKeyframe(0.6, 0, Curves.easeIn), BoneKeyframe(0.75, -14, Curves.easeOut),
    BoneKeyframe(1.0, 0, Curves.easeIn),
  ],
  leftArm: const [
    BoneKeyframe(0.0, 100), BoneKeyframe(1.0, 100),
  ],
  rightArm: const [
    BoneKeyframe(0.0, -100), BoneKeyframe(1.0, -100),
  ],
  eyeState: EyeState.happy,
  mouthState: MouthState.smile,
  glowColor: const Color(0xFFFFD60A),
  particleType: ParticleType.musicNotes,
  particleContinuous: true,
);

// 12. THINKING
final thinking = RockyAnimationSpec(
  name: 'thinking',
  duration: const Duration(milliseconds: 1400),
  loop: true,
  bodyRotation: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.5, 0.04, Curves.easeInOut),
    BoneKeyframe(1.0, 0, Curves.easeInOut),
  ],
  bodyOffsetX: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.5, 4, Curves.easeInOut), BoneKeyframe(1.0, 0),
  ],
  rightArm: const [
    BoneKeyframe(0.0, 0, Curves.easeOut), BoneKeyframe(0.3, -150, Curves.easeOut), BoneKeyframe(1.0, -150),
  ],
  eyeState: EyeState.lookRight,
  particleType: ParticleType.thoughtBubble,
  particleTriggerT: 0.35,
);

// 13. CONFUSED
final confused = RockyAnimationSpec(
  name: 'confused',
  duration: const Duration(milliseconds: 1000),
  loop: true,
  bodyRotation: const [
    BoneKeyframe(0.0, -0.05), BoneKeyframe(0.5, 0.05, Curves.easeInOut),
    BoneKeyframe(1.0, -0.05, Curves.easeInOut),
  ],
  bodyOffsetX: const [
    BoneKeyframe(0.0, -5), BoneKeyframe(0.5, 5, Curves.easeInOut), BoneKeyframe(1.0, -5),
  ],
  leftArm: const [
    BoneKeyframe(0.0, 90), BoneKeyframe(1.0, 90),
  ],
  rightArm: const [
    BoneKeyframe(0.0, 30), BoneKeyframe(1.0, 30),
  ],
  eyeState: EyeState.dizzy,
  particleType: ParticleType.questionMarks,
  particleContinuous: true,
);

// 14. CELEBRATION
final celebration = RockyAnimationSpec(
  name: 'celebration',
  duration: const Duration(milliseconds: 1000),
  bodyScaleY: const [
    BoneKeyframe(0.0, 1.0), BoneKeyframe(0.15, 0.7, Curves.easeOut),
    BoneKeyframe(0.4, 1.35, Curves.elasticOut), BoneKeyframe(0.7, 1.35),
    BoneKeyframe(1.0, 1.0, Curves.easeIn),
  ],
  bodyOffsetY: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.4, -55, Curves.easeOut),
    BoneKeyframe(0.7, -55), BoneKeyframe(1.0, 0, Curves.easeIn),
  ],
  leftArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.4, 150, Curves.elasticOut), BoneKeyframe(1.0, 0, Curves.easeIn),
  ],
  rightArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.4, -150, Curves.elasticOut), BoneKeyframe(1.0, 0, Curves.easeIn),
  ],
  eyeState: EyeState.star,
  mouthState: MouthState.smile,
  glowColor: const Color(0xFFAF52DE),
  particleType: ParticleType.confetti,
  particleTriggerT: 0.4,
);

// 15. WARNING SEVERE
final warningSevere = RockyAnimationSpec(
  name: 'warningSevere',
  duration: const Duration(milliseconds: 400),
  loop: true,
  bodyOffsetX: const [
    BoneKeyframe(0.0, 0, Curves.linear), BoneKeyframe(0.2, -14, Curves.linear),
    BoneKeyframe(0.4, 12, Curves.linear), BoneKeyframe(0.6, -10, Curves.linear),
    BoneKeyframe(0.8, 8, Curves.linear), BoneKeyframe(1.0, 0, Curves.linear),
  ],
  bodyOffsetY: const [
    BoneKeyframe(0.0, 0, Curves.linear), BoneKeyframe(0.3, -6, Curves.linear),
    BoneKeyframe(0.6, 4, Curves.linear), BoneKeyframe(1.0, 0, Curves.linear),
  ],
  leftArm: const [
    BoneKeyframe(0.0, 40, Curves.linear), BoneKeyframe(0.3, -30, Curves.linear),
    BoneKeyframe(0.6, 50, Curves.linear), BoneKeyframe(1.0, 40, Curves.linear),
  ],
  rightArm: const [
    BoneKeyframe(0.0, -40, Curves.linear), BoneKeyframe(0.3, 30, Curves.linear),
    BoneKeyframe(0.6, -50, Curves.linear), BoneKeyframe(1.0, -40, Curves.linear),
  ],
  eyeState: EyeState.angry,
  mouthState: MouthState.teeth,
  glowColor: const Color(0xFFFF0000),
  particleType: ParticleType.exclamation,
  particleContinuous: true,
);

// 16. SAD
final sad = RockyAnimationSpec(
  name: 'sad',
  duration: const Duration(milliseconds: 1200),
  bodyScaleY: const [
    BoneKeyframe(0.0, 1.0), BoneKeyframe(0.4, 0.82, Curves.easeOut), BoneKeyframe(1.0, 0.82),
  ],
  bodyRotation: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.4, 0.08, Curves.easeOut), BoneKeyframe(1.0, 0.08),
  ],
  leftArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.4, 15, Curves.easeOut), BoneKeyframe(1.0, 15),
  ],
  rightArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.4, -15, Curves.easeOut), BoneKeyframe(1.0, -15),
  ],
  eyeState: EyeState.sad,
  glowColor: const Color(0xFF8E9AAF),
  particleType: ParticleType.tear,
  particleContinuous: true,
);

// 17. WEALTHY
final wealthy = RockyAnimationSpec(
  name: 'wealthy',
  duration: const Duration(milliseconds: 800),
  bodyOffsetY: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.35, -38, Curves.easeOut),
    BoneKeyframe(0.65, -38), BoneKeyframe(1.0, 0, Curves.easeIn),
  ],
  leftArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.3, 130, Curves.easeOut), BoneKeyframe(1.0, 0, Curves.easeIn),
  ],
  rightArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.3, -130, Curves.easeOut), BoneKeyframe(1.0, 0, Curves.easeIn),
  ],
  eyeState: EyeState.dollar,
  glowColor: const Color(0xFFD4AF37),
  particleType: ParticleType.coins,
  particleContinuous: true,
);

// 18. HIDE
final hide = RockyAnimationSpec(
  name: 'hide',
  duration: const Duration(milliseconds: 700),
  bodyOffsetY: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.6, 45, Curves.easeIn), BoneKeyframe(1.0, 45),
  ],
  bodyScaleY: const [
    BoneKeyframe(0.0, 1.0), BoneKeyframe(0.6, 0.7, Curves.easeIn), BoneKeyframe(1.0, 0.7),
  ],
  bodyScaleX: const [
    BoneKeyframe(0.0, 1.0), BoneKeyframe(0.6, 1.1, Curves.easeIn), BoneKeyframe(1.0, 1.1),
  ],
  leftArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.6, 100, Curves.easeIn), BoneKeyframe(1.0, 100),
  ],
  rightArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.6, -100, Curves.easeIn), BoneKeyframe(1.0, -100),
  ],
  eyeSequence: const [
    MapEntry(0.0, EyeState.normal), MapEntry(0.6, EyeState.sad),
  ],
);

// 19. WORKOUT
final workout = RockyAnimationSpec(
  name: 'workout',
  duration: const Duration(milliseconds: 700),
  loop: true,
  bodyScaleY: const [
    BoneKeyframe(0.0, 1.0), BoneKeyframe(0.5, 0.8, Curves.easeInOut), BoneKeyframe(1.0, 1.0, Curves.easeInOut),
  ],
  bodyScaleX: const [
    BoneKeyframe(0.0, 1.0), BoneKeyframe(0.5, 1.1, Curves.easeInOut), BoneKeyframe(1.0, 1.0, Curves.easeInOut),
  ],
  leftLeg: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.5, -20, Curves.easeInOut), BoneKeyframe(1.0, 0, Curves.easeInOut),
  ],
  rightLeg: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.5, 20, Curves.easeInOut), BoneKeyframe(1.0, 0, Curves.easeInOut),
  ],
  leftArm: const [
    BoneKeyframe(0.0, -150), BoneKeyframe(0.5, -140), BoneKeyframe(1.0, -150),
  ],
  rightArm: const [
    BoneKeyframe(0.0, 150), BoneKeyframe(0.5, 140), BoneKeyframe(1.0, 150),
  ],
  eyeSequence: const [
    MapEntry(0.0, EyeState.normal), MapEntry(0.5, EyeState.angry), MapEntry(1.0, EyeState.normal),
  ],
  mouthState: MouthState.teeth,
  glowColor: const Color(0xFFFF9500),
  particleType: ParticleType.sweatDrops,
  particleContinuous: true,
);

// 20. FLYING STARS
final flyingStars = RockyAnimationSpec(
  name: 'flyingStars',
  duration: const Duration(milliseconds: 1800),
  bodyOffsetX: const [
    BoneKeyframe(0.0, -120, Curves.easeOut), BoneKeyframe(1.0, 120, Curves.easeIn),
  ],
  bodyOffsetY: const [
    BoneKeyframe(0.0, 40), BoneKeyframe(0.5, -60, Curves.easeOut), BoneKeyframe(1.0, 40, Curves.easeIn),
  ],
  bodyRotation: const [
    BoneKeyframe(0.0, -0.15), BoneKeyframe(0.5, 0), BoneKeyframe(1.0, 0.15),
  ],
  leftArm: const [
    BoneKeyframe(0.0, 90), BoneKeyframe(1.0, 90),
  ],
  rightArm: const [
    BoneKeyframe(0.0, -90), BoneKeyframe(1.0, -90),
  ],
  eyeState: EyeState.star,
  mouthState: MouthState.open,
  glowColor: const Color(0xFFFFFFFF),
  particleType: ParticleType.starTrail,
  particleContinuous: true,
);

// 21. SLEEP
final sleep = RockyAnimationSpec(
  name: 'sleep',
  duration: const Duration(milliseconds: 2400),
  loop: true,
  bodyScaleX: const [
    BoneKeyframe(0.0, 1.0), BoneKeyframe(0.5, 1.04, Curves.easeInOut), BoneKeyframe(1.0, 1.0, Curves.easeInOut),
  ],
  bodyScaleY: const [
    BoneKeyframe(0.0, 1.0), BoneKeyframe(0.5, 1.05, Curves.easeInOut), BoneKeyframe(1.0, 1.0, Curves.easeInOut),
  ],
  eyeState: EyeState.sleep,
  glowColor: const Color(0x334B0082),
  particleType: ParticleType.zzz,
  particleContinuous: true,
);

// 22. FLIP
final flip = RockyAnimationSpec(
  name: 'flip',
  duration: const Duration(milliseconds: 900),
  bodyOffsetY: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.5, -70, Curves.easeOut), BoneKeyframe(1.0, 0, Curves.easeIn),
  ],
  bodyRotation: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(1.0, 6.283, Curves.easeInOut),
  ],
  leftArm: const [
    BoneKeyframe(0.0, 90), BoneKeyframe(1.0, 90),
  ],
  rightArm: const [
    BoneKeyframe(0.0, -90), BoneKeyframe(1.0, -90),
  ],
  eyeState: EyeState.dizzy,
);

// 23. WALKING
final walking = RockyAnimationSpec(
  name: 'walking',
  duration: const Duration(milliseconds: 800),
  loop: true,
  bodyOffsetY: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.25, -6, Curves.easeOut),
    BoneKeyframe(0.5, 0, Curves.easeIn), BoneKeyframe(0.75, -6, Curves.easeOut),
    BoneKeyframe(1.0, 0, Curves.easeIn),
  ],
  bodyRotation: const [
    BoneKeyframe(0.0, -0.02), BoneKeyframe(0.5, 0.02), BoneKeyframe(1.0, -0.02),
  ],
  leftArm: const [
    BoneKeyframe(0.0, 25), BoneKeyframe(0.5, -25), BoneKeyframe(1.0, 25),
  ],
  rightArm: const [
    BoneKeyframe(0.0, -25), BoneKeyframe(0.5, 25), BoneKeyframe(1.0, -25),
  ],
  leftLeg: const [
    BoneKeyframe(0.0, -20), BoneKeyframe(0.5, 20), BoneKeyframe(1.0, -20),
  ],
  rightLeg: const [
    BoneKeyframe(0.0, 20), BoneKeyframe(0.5, -20), BoneKeyframe(1.0, 20),
  ],
  eyeState: EyeState.normal,
);

// 24. BILL WAVER
final billWaver = RockyAnimationSpec(
  name: 'billWaver',
  duration: const Duration(milliseconds: 700),
  loop: true,
  rightArm: const [
    BoneKeyframe(0.0, -90, Curves.easeInOut), BoneKeyframe(0.3, -70, Curves.easeInOut),
    BoneKeyframe(0.6, -100, Curves.easeInOut), BoneKeyframe(1.0, -90, Curves.easeInOut),
  ],
  eyeState: EyeState.dollar,
  mouthState: MouthState.smile,
  particleType: ParticleType.billFlutter,
  particleContinuous: true,
);

// 25. WAVE
final wave = RockyAnimationSpec(
  name: 'wave',
  duration: const Duration(milliseconds: 1200),
  bodyOffsetX: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.2, -12, Curves.easeOut),
    BoneKeyframe(0.8, -12), BoneKeyframe(1.0, 0, Curves.easeIn),
  ],
  bodyScaleY: const [
    BoneKeyframe(0.0, 1.0), BoneKeyframe(0.2, 1.06, Curves.easeOut),
    BoneKeyframe(0.5, 1.0, Curves.easeIn), BoneKeyframe(0.7, 1.04, Curves.easeOut),
    BoneKeyframe(1.0, 1.0, Curves.easeIn),
  ],
  rightArm: const [
    BoneKeyframe(0.0, 0, Curves.easeOut),
    BoneKeyframe(0.2, -135, Curves.easeInOut),
    BoneKeyframe(0.4, -105, Curves.easeInOut),
    BoneKeyframe(0.6, -135, Curves.easeInOut),
    BoneKeyframe(0.8, -105, Curves.easeInOut),
    BoneKeyframe(1.0, 0, Curves.easeIn),
  ],
  eyeState: EyeState.happy,
  mouthState: MouthState.smile,
);

// 26. CLAP
final clap = RockyAnimationSpec(
  name: 'clap',
  duration: const Duration(milliseconds: 900),
  loop: true,
  leftArm: const [
    BoneKeyframe(0.0, -70), BoneKeyframe(0.5, -20), BoneKeyframe(1.0, -70),
  ],
  rightArm: const [
    BoneKeyframe(0.0, 70), BoneKeyframe(0.5, 20), BoneKeyframe(1.0, 70),
  ],
  eyeState: EyeState.happy,
  particleType: ParticleType.sparks,
  particleTriggerT: 0.5,
);

// 27. DANCE
final dance = RockyAnimationSpec(
  name: 'dance',
  duration: const Duration(milliseconds: 700),
  loop: true,
  bodyOffsetX: const [
    BoneKeyframe(0.0, -12), BoneKeyframe(0.5, 12, Curves.easeInOut), BoneKeyframe(1.0, -12, Curves.easeInOut),
  ],
  bodyOffsetY: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.25, -18, Curves.easeOut),
    BoneKeyframe(0.5, 0, Curves.easeIn), BoneKeyframe(0.75, -18, Curves.easeOut),
    BoneKeyframe(1.0, 0, Curves.easeIn),
  ],
  bodyRotation: const [
    BoneKeyframe(0.0, -0.04), BoneKeyframe(0.5, 0.04, Curves.easeInOut), BoneKeyframe(1.0, -0.04, Curves.easeInOut),
  ],
  leftArm: const [
    BoneKeyframe(0.0, -85), BoneKeyframe(0.5, 85, Curves.easeInOut), BoneKeyframe(1.0, -85, Curves.easeInOut),
  ],
  rightArm: const [
    BoneKeyframe(0.0, 85), BoneKeyframe(0.5, -85, Curves.easeInOut), BoneKeyframe(1.0, 85, Curves.easeInOut),
  ],
  leftLeg: const [
    BoneKeyframe(0.0, -10), BoneKeyframe(0.5, 10, Curves.easeInOut), BoneKeyframe(1.0, -10, Curves.easeInOut),
  ],
  rightLeg: const [
    BoneKeyframe(0.0, 10), BoneKeyframe(0.5, -10, Curves.easeInOut), BoneKeyframe(1.0, 10, Curves.easeInOut),
  ],
  eyeState: EyeState.happy,
  mouthState: MouthState.smile,
  particleType: ParticleType.musicNotes,
  particleContinuous: true,
);

// 28. ANGRY
final angry = RockyAnimationSpec(
  name: 'angry',
  duration: const Duration(milliseconds: 400),
  loop: true,
  bodyOffsetX: const [
    BoneKeyframe(0.0, 0, Curves.linear), BoneKeyframe(0.25, -5, Curves.linear),
    BoneKeyframe(0.5, 5, Curves.linear), BoneKeyframe(0.75, -3, Curves.linear),
    BoneKeyframe(1.0, 0, Curves.linear),
  ],
  eyeState: EyeState.angry,
  mouthState: MouthState.tight,
  glowColor: const Color(0xFFFF3B30),
  particleType: ParticleType.angerCloud,
  particleContinuous: true,
);

// 29. LOVE
final love = RockyAnimationSpec(
  name: 'love',
  duration: const Duration(milliseconds: 900),
  loop: true,
  bodyOffsetY: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.3, -20, Curves.easeOut),
    BoneKeyframe(0.6, 0, Curves.easeIn), BoneKeyframe(1.0, 0),
  ],
  leftArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.3, 110, Curves.easeOut), BoneKeyframe(1.0, 0, Curves.easeIn),
  ],
  rightArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.3, -110, Curves.easeOut), BoneKeyframe(1.0, 0, Curves.easeIn),
  ],
  eyeState: EyeState.heart,
  mouthState: MouthState.smile,
  glowColor: const Color(0xFFFF9FB2),
  particleType: ParticleType.hearts,
  particleContinuous: true,
);

// 30. FACEPALM
final facepalm = RockyAnimationSpec(
  name: 'facepalm',
  duration: const Duration(milliseconds: 1500),
  rightArmOffsetX: const [
    BoneKeyframe(0.0, 0, Curves.easeInOut),
    BoneKeyframe(0.25, 15, Curves.easeInOut),
    BoneKeyframe(0.45, 15, Curves.linear),
    BoneKeyframe(0.7, 0, Curves.easeInOut),
    BoneKeyframe(1.0, 0),
  ],
  rightArm: const [
    BoneKeyframe(0.0, 0, Curves.easeInOut),
    BoneKeyframe(0.25, -20, Curves.easeInOut), // Pequeño ángulo para acompañar el alejamiento
    BoneKeyframe(0.45, -20, Curves.linear),
    BoneKeyframe(0.7, -155, Curves.easeInOut), // Completa el facepalm
    BoneKeyframe(1.0, -155),
  ],
  eyeSequence: const [
    MapEntry(0.0, EyeState.normal), MapEntry(0.7, EyeState.sad),
  ],
);

// 31. THUMBS UP
final thumbsUp = RockyAnimationSpec(
  name: 'thumbsUp',
  duration: const Duration(milliseconds: 1500),
  bodyOffsetX: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.4, -14, Curves.easeOut),
    BoneKeyframe(0.8, -14), BoneKeyframe(1.0, 0, Curves.easeIn),
  ],
  rightArmOffsetX: const [
    BoneKeyframe(0.0, 0, Curves.easeInOut),
    BoneKeyframe(0.25, 15, Curves.easeInOut),
    BoneKeyframe(0.45, 15, Curves.linear),
    BoneKeyframe(0.7, 0, Curves.easeInOut),
    BoneKeyframe(1.0, 0),
  ],
  rightArm: const [
    BoneKeyframe(0.0, 0, Curves.easeInOut),
    BoneKeyframe(0.25, -20, Curves.easeInOut), // Pequeño ángulo de apoyo
    BoneKeyframe(0.45, -20, Curves.linear),    // Se detiene un instante
    BoneKeyframe(0.7, -150, Curves.elasticOut),// Sube pulgar
    BoneKeyframe(1.0, -150),
  ],
  bodyScaleY: const [
    BoneKeyframe(0.0, 1.0), BoneKeyframe(0.3, 0.92, Curves.easeOut),
    BoneKeyframe(0.6, 1.1, Curves.easeOut), BoneKeyframe(0.8, 1.0, Curves.easeIn),
  ],
  eyeSequence: const [
    MapEntry(0.0, EyeState.normal), MapEntry(0.4, EyeState.happy), MapEntry(0.9, EyeState.normal),
  ],
  mouthSequence: const [
    MapEntry(0.0, MouthState.none), MapEntry(0.4, MouthState.smile), MapEntry(0.9, MouthState.none),
  ],
  particleType: ParticleType.yellowSparkles,
  particleTriggerT: 0.6,
);

// 32. RUNNING
final running = RockyAnimationSpec(
  name: 'running',
  duration: const Duration(milliseconds: 350),
  loop: true,
  bodyOffsetY: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.25, -16, Curves.easeOut),
    BoneKeyframe(0.5, 0, Curves.easeIn), BoneKeyframe(0.75, -16, Curves.easeOut),
    BoneKeyframe(1.0, 0, Curves.easeIn),
  ],
  bodyRotation: const [
    BoneKeyframe(0.0, -0.06), BoneKeyframe(1.0, -0.06),
  ],
  leftArm: const [
    BoneKeyframe(0.0, 55), BoneKeyframe(0.5, -55), BoneKeyframe(1.0, 55),
  ],
  rightArm: const [
    BoneKeyframe(0.0, -55), BoneKeyframe(0.5, 55), BoneKeyframe(1.0, -55),
  ],
  leftLeg: const [
    BoneKeyframe(0.0, -8), BoneKeyframe(0.5, 8), BoneKeyframe(1.0, -8),
  ],
  rightLeg: const [
    BoneKeyframe(0.0, 8), BoneKeyframe(0.5, -8), BoneKeyframe(1.0, 8),
  ],
  particleType: ParticleType.dustTrail,
  particleContinuous: true,
);

// 33. TYPING
final typing = RockyAnimationSpec(
  name: 'typing',
  duration: const Duration(milliseconds: 300),
  loop: true,
  leftArm: const [
    BoneKeyframe(0.0, -60), BoneKeyframe(0.5, -70), BoneKeyframe(1.0, -60),
  ],
  rightArm: const [
    BoneKeyframe(0.0, 60), BoneKeyframe(0.5, 70), BoneKeyframe(1.0, 60),
  ],
  eyeState: EyeState.lookRight,
  particleType: ParticleType.numbersCyanGreen,
  particleContinuous: true,
);

// 34. SHIELDING
final shielding = RockyAnimationSpec(
  name: 'shielding',
  duration: const Duration(milliseconds: 600),
  bodyOffsetY: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.3, -15, Curves.easeOut), BoneKeyframe(1.0, -15),
  ],
  bodyScaleX: const [
    BoneKeyframe(0.0, 1.0), BoneKeyframe(0.3, 1.08, Curves.easeOut), BoneKeyframe(1.0, 1.08),
  ],
  leftArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.3, 100, Curves.easeOut), BoneKeyframe(1.0, 100),
  ],
  rightArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.3, -100, Curves.easeOut), BoneKeyframe(1.0, -100),
  ],
  eyeState: EyeState.angry,
  mouthState: MouthState.neutral,
  particleType: ParticleType.shieldBlue,
  particleTriggerT: 0.3,
);

// 35. ROCKET
final rocket = RockyAnimationSpec(
  name: 'rocket',
  duration: const Duration(milliseconds: 1000),
  bodyOffsetY: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.3, -20, Curves.easeIn),
    BoneKeyframe(1.0, -220, Curves.easeIn),
  ],
  bodyScaleY: const [
    BoneKeyframe(0.0, 1.0), BoneKeyframe(0.3, 0.85, Curves.easeOut),
    BoneKeyframe(1.0, 1.35, Curves.easeIn),
  ],
  bodyScaleX: const [
    BoneKeyframe(0.0, 1.0), BoneKeyframe(0.3, 1.15, Curves.easeOut), BoneKeyframe(1.0, 0.8, Curves.easeIn),
  ],
  leftArm: const [
    BoneKeyframe(0.0, 100), BoneKeyframe(1.0, 100),
  ],
  rightArm: const [
    BoneKeyframe(0.0, -100), BoneKeyframe(1.0, -100),
  ],
  eyeState: EyeState.star,
  mouthState: MouthState.open,
  glowColor: const Color(0xFFFF6D00),
  particleType: ParticleType.flame,
  particleContinuous: true,
);

// 36. CROWN
final crown = RockyAnimationSpec(
  name: 'crown',
  duration: const Duration(milliseconds: 900),
  bodyOffsetY: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.35, -30, Curves.easeOut),
    BoneKeyframe(0.65, -30), BoneKeyframe(1.0, 0, Curves.bounceOut),
  ],
  leftArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.3, 110, Curves.easeOut), BoneKeyframe(1.0, 110),
  ],
  rightArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.3, -110, Curves.easeOut), BoneKeyframe(1.0, -110),
  ],
  eyeState: EyeState.star,
  mouthState: MouthState.smile,
  glowColor: const Color(0xFFFFBF00),
  particleType: ParticleType.crownDescend,
  particleTriggerT: 0.35,
);

// 37. RAINY
final rainy = RockyAnimationSpec(
  name: 'rainy',
  duration: const Duration(milliseconds: 1000),
  loop: true,
  bodyScaleY: const [
    BoneKeyframe(0.0, 1.0), BoneKeyframe(0.5, 0.9, Curves.easeInOut), BoneKeyframe(1.0, 1.0, Curves.easeInOut),
  ],
  bodyOffsetY: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.5, 8, Curves.easeInOut), BoneKeyframe(1.0, 0, Curves.easeInOut),
  ],
  leftArm: const [
    BoneKeyframe(0.0, 15), BoneKeyframe(1.0, 15),
  ],
  rightArm: const [
    BoneKeyframe(0.0, -15), BoneKeyframe(1.0, -15),
  ],
  eyeState: EyeState.sad,
  glowColor: const Color(0xFF708090),
  particleType: ParticleType.rainCloud,
  particleContinuous: true,
);

// 38. FLEXING
final flexing = RockyAnimationSpec(
  name: 'flexing',
  duration: const Duration(milliseconds: 700),
  bodyScaleX: const [
    BoneKeyframe(0.0, 1.0), BoneKeyframe(0.4, 1.2, Curves.easeOut), BoneKeyframe(1.0, 1.2),
  ],
  bodyOffsetY: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.4, -10, Curves.easeOut), BoneKeyframe(1.0, -10),
  ],
  leftArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.4, 100, Curves.easeOut), BoneKeyframe(1.0, 100),
  ],
  rightArm: const [
    BoneKeyframe(0.0, 0), BoneKeyframe(0.4, -100, Curves.easeOut), BoneKeyframe(1.0, -100),
  ],
  eyeState: EyeState.happy,
  mouthState: MouthState.smile,
  particleType: ParticleType.sparksAtFists,
  particleTriggerT: 0.4,
);

// 39. LOOK AROUND
final lookAround = RockyAnimationSpec(
  name: 'lookAround',
  duration: const Duration(milliseconds: 2400),
  eyeSequence: const [
    MapEntry(0.0, EyeState.normal), MapEntry(0.2, EyeState.lookLeft),
    MapEntry(0.45, EyeState.lookLeft), MapEntry(0.55, EyeState.normal),
    MapEntry(0.7, EyeState.lookRight), MapEntry(0.95, EyeState.lookRight),
    MapEntry(1.0, EyeState.normal),
  ],
);

// MAPA FINAL DE SPECS
final Map<String, RockyAnimationSpec> rockyAnimations = {
  'jump': jump, 'shake': shake, 'stretch': stretch, 'shrink': shrink,
  'nod': nod, 'glitch': glitch, 'glowGreen': glowGreen, 'glowRed': glowRed,
  'spin': spin, 'alert': alert, 'happy': happy, 'thinking': thinking,
  'confused': confused, 'celebration': celebration, 'warningSevere': warningSevere,
  'sad': sad, 'wealthy': wealthy, 'hide': hide, 'workout': workout,
  'flyingStars': flyingStars, 'sleep': sleep, 'flip': flip, 'walking': walking,
  'billWaver': billWaver, 'wave': wave, 'clap': clap, 'dance': dance,
  'angry': angry, 'love': love, 'facepalm': facepalm, 'thumbsUp': thumbsUp,
  'running': running, 'typing': typing, 'shielding': shielding, 'rocket': rocket,
  'crown': crown, 'rainy': rainy, 'flexing': flexing, 'lookAround': lookAround,
};
