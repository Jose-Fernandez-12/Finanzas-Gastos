import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:gastos_e_ingresos/providers/virtual_assistant_provider.dart' show AssistantAnimation;
import 'package:gastos_e_ingresos/widgets/rocky_animations.dart' show RockyPose, EyeState, MouthState, PixelObject;

RockyPose? getRockyEffects(
  AssistantAnimation anim,
  double action,
  List<PixelObject> pixelObjects,
  RockyPose pose,
) {
  final sinPi = math.sin(action * math.pi);
  final _random = math.Random();
  Color? glowColor = pose.glowColor;
  EyeState eyeState = pose.eyeState;
  MouthState mouthState = pose.mouthState;

  // Additional variables from original switch
  double pushupCycle = math.sin(action * math.pi * 4);

  switch (anim) {
    case AssistantAnimation.jump:
      eyeState = EyeState.happy;
      mouthState = MouthState.open;
      break;
    case AssistantAnimation.shake:
      eyeState = EyeState.angry;
      mouthState = MouthState.teeth;
      break;
    case AssistantAnimation.stretch:
      eyeState = EyeState.happy;
      mouthState = MouthState.open;
      break;
    case AssistantAnimation.shrink:
      eyeState = EyeState.sad;
      mouthState = MouthState.frown;
      break;
    case AssistantAnimation.nod:
      eyeState = EyeState.happy;
      mouthState = MouthState.smile;
      break;
    case AssistantAnimation.glitch:
      eyeState = EyeState.dizzy;
      mouthState = MouthState.open;
      for (int i = 0; i < 4; i++) {
        pixelObjects.add(
          PixelObject(
            type: 'spark',
            x: 10 + _random.nextDouble() * 52,
            y: -5 - _random.nextDouble() * 20 * sinPi,
            progress: action,
            color: Colors.cyanAccent,
          ),
        );
      }
      break;
    case AssistantAnimation.glowGreen:
      glowColor = Colors.greenAccent.withAlpha((sinPi * 200).toInt());
      eyeState = EyeState.star;
      mouthState = MouthState.smile;
      pixelObjects.add(
        PixelObject(
          type: 'sparkle',
          x: 5,
          y: -10 - action * 15,
          progress: action,
          color: Colors.greenAccent,
        ),
      );
      pixelObjects.add(
        PixelObject(
          type: 'sparkle',
          x: 60,
          y: -5 - action * 12,
          progress: action,
          color: Colors.lightGreenAccent,
        ),
      );
      break;
    case AssistantAnimation.glowRed:
      glowColor = Colors.redAccent.withAlpha((sinPi * 200).toInt());
      eyeState = EyeState.angry;
      mouthState = MouthState.frown;
      pixelObjects.add(
        PixelObject(
          type: 'lightning',
          x: 55,
          y: -15 - sinPi * 10,
          progress: action,
          color: Colors.redAccent,
        ),
      );
      break;
    case AssistantAnimation.spin:
      eyeState = EyeState.dizzy;
      break;
    case AssistantAnimation.alert:
      glowColor = Colors.redAccent.withAlpha((sinPi * 200).toInt());
      eyeState = EyeState.angry;
      mouthState = MouthState.teeth;
      pixelObjects.add(
        PixelObject(
          type: 'exclamation',
          x: 30,
          y: -25 - sinPi * 10,
          progress: action,
          color: Colors.redAccent,
        ),
      );
      break;
    case AssistantAnimation.happy:
      glowColor = Colors.yellowAccent.withAlpha((sinPi * 200).toInt());
      eyeState = EyeState.happy;
      mouthState = MouthState.smile;
      pixelObjects.add(
        PixelObject(
          type: 'note',
          x: -5,
          y: -10 - action * 20,
          progress: action,
          color: Colors.yellowAccent,
        ),
      );
      pixelObjects.add(
        PixelObject(
          type: 'note',
          x: 65,
          y: -15 - action * 18,
          progress: action,
          color: Colors.amberAccent,
        ),
      );
      break;
    case AssistantAnimation.thinking:
      eyeState = EyeState.normal;
      mouthState = MouthState.frown;
      pixelObjects.add(
        PixelObject(
          type: 'thought',
          x: 55,
          y: -20 - sinPi * 8,
          progress: action,
          color: Colors.white70,
        ),
      );
      break;
    case AssistantAnimation.confused:
      eyeState = EyeState.dizzy;
      mouthState = MouthState.open;
      pixelObjects.add(
        PixelObject(
          type: 'question',
          x: 28,
          y: -28 - sinPi * 10,
          progress: action,
          color: Colors.white,
        ),
      );
      pixelObjects.add(
        PixelObject(
          type: 'question',
          x: 8,
          y: -12 - sinPi * 5,
          progress: action,
          color: Colors.white70,
        ),
      );
      pixelObjects.add(
        PixelObject(
          type: 'question',
          x: 55,
          y: -18 - sinPi * 12,
          progress: action,
          color: Colors.white70,
        ),
      );
      break;
    case AssistantAnimation.celebration:
      glowColor = Colors.purpleAccent.withAlpha((sinPi * 200).toInt());
      eyeState = EyeState.star;
      mouthState = MouthState.smile;
      final confColors = [
        Colors.yellowAccent,
        Colors.cyanAccent,
        Colors.pinkAccent,
        Colors.greenAccent,
        Colors.orangeAccent,
      ];
      for (int i = 0; i < 8; i++) {
        pixelObjects.add(
          PixelObject(
            type: 'confetti',
            x: 5 + (math.cos(action * math.pi * 4 + i * 0.8) * 30) + i * 5,
            y: -10 - action * 25 - math.sin(action * math.pi * 3 + i) * 15,
            progress: action,
            color: confColors[i % confColors.length],
          ),
        );
      }
      break;
    case AssistantAnimation.warningSevere:
      glowColor = Colors.red.withAlpha((sinPi * 255).toInt());
      eyeState = EyeState.angry;
      mouthState = MouthState.teeth;
      pixelObjects.add(
        PixelObject(
          type: 'lightning',
          x: 10,
          y: -15 - sinPi * 10,
          progress: action,
          color: Colors.redAccent,
        ),
      );
      pixelObjects.add(
        PixelObject(
          type: 'lightning',
          x: 55,
          y: -20 - sinPi * 8,
          progress: action,
          color: Colors.orangeAccent,
        ),
      );
      pixelObjects.add(
        PixelObject(
          type: 'exclamation',
          x: 32,
          y: -30 - sinPi * 12,
          progress: action,
          color: Colors.red,
        ),
      );
      break;
    case AssistantAnimation.sad:
      glowColor = Colors.blueGrey.withAlpha((sinPi * 150).toInt());
      eyeState = EyeState.sad;
      mouthState = MouthState.frown;
      pixelObjects.add(
        PixelObject(
          type: 'drop',
          x: 22,
          y: 18 + sinPi * 8,
          progress: action,
          color: Colors.lightBlueAccent,
        ),
      );
      break;
    case AssistantAnimation.wealthy:
      glowColor = Colors.amberAccent.withAlpha((sinPi * 200).toInt());
      eyeState = EyeState.dollar;
      mouthState = MouthState.smile;
      pixelObjects.add(
        PixelObject(
          type: 'coin',
          x: -8,
          y: -5 - action * 25,
          progress: action,
          color: Colors.amberAccent,
        ),
      );
      pixelObjects.add(
        PixelObject(
          type: 'coin',
          x: 30,
          y: -30 - action * 30,
          progress: action,
          color: Colors.amber,
        ),
      );
      pixelObjects.add(
        PixelObject(
          type: 'coin',
          x: 65,
          y: -10 - action * 20,
          progress: action,
          color: Colors.amberAccent,
        ),
      );
      pixelObjects.add(
        PixelObject(
          type: 'bill',
          x: 15,
          y: -15 - action * 18,
          progress: action,
          color: Colors.greenAccent,
        ),
      );
      pixelObjects.add(
        PixelObject(
          type: 'bill',
          x: 50,
          y: -5 - action * 35,
          progress: action,
          color: Colors.lightGreenAccent,
        ),
      );
      break;
    case AssistantAnimation.hide:
      eyeState = sinPi > 0.5 ? EyeState.sad : EyeState.normal;
      mouthState = MouthState.frown;
      break;
    case AssistantAnimation.workout:
      glowColor = Colors.orangeAccent.withAlpha((sinPi * 150).toInt());
      final pushupCycle = math.sin(action * math.pi * 6).abs();
      eyeState = EyeState.angry;
      mouthState = MouthState.teeth;
      pixelObjects.add(
        PixelObject(
          type: 'drop',
          x: -3,
          y: 5 + pushupCycle * 5,
          progress: action,
          color: Colors.lightBlueAccent,
        ),
      );
      pixelObjects.add(
        PixelObject(
          type: 'drop',
          x: 68,
          y: 8 + pushupCycle * 4,
          progress: action,
          color: Colors.lightBlueAccent,
        ),
      );
      break;
    case AssistantAnimation.flyingStars:
      glowColor = Colors.white.withAlpha((sinPi * 200).toInt());
      final smoothAction = Curves.easeInOutSine.transform(action);
      eyeState = EyeState.star;
      mouthState = MouthState.open;
      for (int i = 0; i < 6; i++) {
        pixelObjects.add(
          PixelObject(
            type: 'star4',
            x: 36 + (math.cos(action * math.pi * 6 + i) * 35),
            y: 10 + (math.sin(action * math.pi * 6 + i) * 25),
            progress: action,
            color: Colors.white,
          ),
        );
      }
      break;
    case AssistantAnimation.sleep:
      eyeState = EyeState.sleep;
      mouthState = MouthState.none;
      pixelObjects.add(
        PixelObject(
          type: 'zzz',
          x: 55,
          y: -5 - action * 15,
          progress: action,
          color: Colors.white70,
        ),
      );
      break;
    case AssistantAnimation.flip:
      eyeState = EyeState.dizzy;
      mouthState = MouthState.open;
      break;
    // =====================
    // NUEVAS ANIMACIONES
    // =====================
    case AssistantAnimation.wave:
      eyeState = EyeState.happy;
      mouthState = MouthState.smile;
      break;
    case AssistantAnimation.clap:
      eyeState = EyeState.happy;
      mouthState = MouthState.smile;
      if (math.sin(action * math.pi * 6) > 0.8) {
        pixelObjects.add(
          PixelObject(
            type: 'sparkle',
            x: 33,
            y: -5,
            progress: action,
            color: Colors.yellowAccent,
          ),
        );
      }
      break;
    case AssistantAnimation.dance:
      eyeState = EyeState.happy;
      mouthState = MouthState.smile;
      pixelObjects.add(
        PixelObject(
          type: 'note',
          x: -5 + math.sin(action * math.pi * 3) * 10,
          y: -15 - action * 15,
          progress: action,
          color: Colors.pinkAccent,
        ),
      );
      pixelObjects.add(
        PixelObject(
          type: 'note',
          x: 65 + math.cos(action * math.pi * 3) * 8,
          y: -10 - action * 12,
          progress: action,
          color: Colors.cyanAccent,
        ),
      );
      break;
    case AssistantAnimation.angry:
      eyeState = EyeState.angry;
      mouthState = MouthState.teeth;
      glowColor = Colors.red.withAlpha((sinPi * 120).toInt());
      pixelObjects.add(
        PixelObject(
          type: 'angerCloud',
          x: 25,
          y: -25 - sinPi * 8,
          progress: action,
          color: Colors.redAccent,
        ),
      );
      pixelObjects.add(
        PixelObject(
          type: 'lightning',
          x: 45,
          y: -15 - sinPi * 5,
          progress: action,
          color: Colors.orangeAccent,
        ),
      );
      break;
    case AssistantAnimation.love:
      eyeState = EyeState.heart;
      mouthState = MouthState.smile;
      glowColor = Colors.pinkAccent.withAlpha((sinPi * 120).toInt());
      pixelObjects.add(
        PixelObject(
          type: 'heart',
          x: -5,
          y: -10 - action * 25,
          progress: action,
          color: Colors.pinkAccent,
        ),
      );
      pixelObjects.add(
        PixelObject(
          type: 'heart',
          x: 30,
          y: -25 - action * 20,
          progress: action,
          color: Colors.redAccent,
        ),
      );
      pixelObjects.add(
        PixelObject(
          type: 'heart',
          x: 60,
          y: -8 - action * 22,
          progress: action,
          color: Colors.pink,
        ),
      );
      break;
    case AssistantAnimation.facepalm:
      eyeState = sinPi > 0.5 ? EyeState.sad : EyeState.normal;
      mouthState = MouthState.frown;
      break;
    case AssistantAnimation.thumbsUp:
      eyeState = EyeState.happy;
      mouthState = MouthState.smile;
      pixelObjects.add(
        PixelObject(
          type: 'sparkle',
          x: 62,
          y: -15 - sinPi * 8,
          progress: action,
          color: Colors.yellowAccent,
        ),
      );
      break;
    case AssistantAnimation.running:
      eyeState = EyeState.normal;
      mouthState = MouthState.open;
      pixelObjects.add(
        PixelObject(
          type: 'dust',
          x: 5 - action * 20,
          y: 40,
          progress: action,
          color: Colors.grey,
        ),
      );
      pixelObjects.add(
        PixelObject(
          type: 'dust',
          x: 15 - action * 30,
          y: 42,
          progress: action,
          color: const Color(0xFFBDBDBD),
        ),
      );
      break;
    case AssistantAnimation.typing:
      eyeState = EyeState.normal;
      mouthState = MouthState.none;
      pixelObjects.add(
        PixelObject(
          type: 'number',
          x: 20 + action * 10,
          y: -10 - action * 15,
          progress: action,
          color: Colors.cyanAccent,
        ),
      );
      pixelObjects.add(
        PixelObject(
          type: 'number',
          x: 45 - action * 5,
          y: -15 - action * 12,
          progress: action,
          color: Colors.lightGreenAccent,
        ),
      );
      break;
    case AssistantAnimation.shielding:
      eyeState = EyeState.angry;
      mouthState = MouthState.teeth;
      pixelObjects.add(
        PixelObject(
          type: 'shield',
          x: 22,
          y: -5 + sinPi * -10,
          progress: action,
          color: Colors.blueAccent,
        ),
      );
      break;
    case AssistantAnimation.rocket:
      eyeState = EyeState.star;
      mouthState = MouthState.open;
      glowColor = Colors.orangeAccent.withAlpha((sinPi * 200).toInt());
      pixelObjects.add(
        PixelObject(
          type: 'flame',
          x: 30,
          y: 48 + 5,
          progress: action,
          color: Colors.orangeAccent,
        ),
      );
      pixelObjects.add(
        PixelObject(
          type: 'flame',
          x: 25,
          y: 48 + 10,
          progress: action,
          color: Colors.redAccent,
        ),
      );
      pixelObjects.add(
        PixelObject(
          type: 'flame',
          x: 38,
          y: 48 + 8,
          progress: action,
          color: Colors.yellow,
        ),
      );
      for (int i = 0; i < 4; i++) {
        pixelObjects.add(
          PixelObject(
            type: 'star4',
            x: 10 + i * 18.0,
            y: 5 + action * 40 + i * 5.0,
            progress: action,
            color: Colors.white70,
          ),
        );
      }
      break;
    case AssistantAnimation.crown:
      eyeState = EyeState.star;
      mouthState = MouthState.smile;
      glowColor = Colors.amberAccent.withAlpha((sinPi * 150).toInt());
      pixelObjects.add(
        PixelObject(
          type: 'crown',
          x: 20,
          y: -20 - sinPi * 15,
          progress: action,
          color: Colors.amberAccent,
        ),
      );
      pixelObjects.add(
        PixelObject(
          type: 'sparkle',
          x: 10,
          y: -25 - sinPi * 10,
          progress: action,
          color: Colors.yellowAccent,
        ),
      );
      pixelObjects.add(
        PixelObject(
          type: 'sparkle',
          x: 55,
          y: -22 - sinPi * 12,
          progress: action,
          color: Colors.amberAccent,
        ),
      );
      break;
    case AssistantAnimation.rainy:
      eyeState = EyeState.sad;
      mouthState = MouthState.frown;
      pixelObjects.add(
        PixelObject(
          type: 'cloud',
          x: 15,
          y: -22,
          progress: action,
          color: Colors.blueGrey,
        ),
      );
      for (int i = 0; i < 4; i++) {
        pixelObjects.add(
          PixelObject(
            type: 'drop',
            x: 20 + i * 10.0,
            y: -10 + (action * 25 + i * 5) % 30,
            progress: action,
            color: Colors.lightBlueAccent,
          ),
        );
      }
      break;
    case AssistantAnimation.flexing:
      eyeState = EyeState.happy;
      mouthState = MouthState.smile;
      pixelObjects.add(
        PixelObject(
          type: 'sparkle',
          x: 62,
          y: 10 - sinPi * 10,
          progress: action,
          color: Colors.yellowAccent,
        ),
      );
      break;
    case AssistantAnimation.lookAround:
      final lookPhase = math.sin(action * math.pi * 2);
      if (lookPhase > 0.3) {
        eyeState = EyeState.lookRight;
      } else if (lookPhase < -0.3) {
        eyeState = EyeState.lookLeft;
      } else {
        eyeState = EyeState.normal;
      }
      mouthState = MouthState.none;
      break;
    default:
      break;
  }

  return pose.copyWith(
    glowColor: glowColor,
    eyeState: eyeState,
    mouthState: mouthState,
  );
}
