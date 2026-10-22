import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Articulated 2D Anatomical Athlete & Equipment Illustrator for Lifting Life.
/// Provides realistic athletic silhouettes, muscle definition, depth layering,
/// mechanically accurate gym equipment, and biomechanical motion guides.
class AnatomicalAthleteRenderer {
  AnatomicalAthleteRenderer._();

  // Theme colors
  static const Color kDarkBackground = Color(0xFF0B0F14);
  static const Color kCardBackground = Color(0xFF171C24);
  static const Color kAccentNeon = Color(0xFFB8FF3B);
  static const Color kAccentAmber = Color(0xFFFFB83B);
  static const Color kAccentCyan = Color(0xFF3BD8FF);
  static const Color kSteelDark = Color(0xFF263238);
  static const Color kSteelFrame = Color(0xFF37474F);
  static const Color kSteelMedium = Color(0xFF546E7A);
  static const Color kSteelBright = Color(0xFF78909C);
  static const Color kSteelChrome = Color(0xFFCFD8DC);

  // Anatomical skin & muscle tones
  static const Color kSkinNear = Color(0xFFD6C4B2);
  static const Color kSkinNearShade = Color(0xFFBAA38D);
  static const Color kSkinFar = Color(0xFF8D7B68);
  static const Color kSkinFarShade = Color(0xFF6A5A4A);

  // Athletic apparel & footwear
  static const Color kShortsNear = Color(0xFF1E293B);
  static const Color kShortsFar = Color(0xFF0F172A);
  static const Color kShoeUpperNear = Color(0xFF334155);
  static const Color kShoeUpperFar = Color(0xFF1E293B);
  static const Color kShoeSole = Color(0xFFE2E8F0);

  // ===========================================================================
  // 1. HEAD & NECK
  // ===========================================================================
  static void drawHead(
    Canvas canvas, {
    required Offset center,
    required double angle,
    bool facingRight = true,
    bool highlightNeck = false,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    if (!facingRight) {
      canvas.scale(-1, 1);
    }

    // Neck connection
    final neckPath = Path()
      ..moveTo(-9, 10)
      ..lineTo(-7, 24)
      ..lineTo(7, 24)
      ..lineTo(9, 10)
      ..close();
    canvas.drawPath(
      neckPath,
      Paint()
        ..color = highlightNeck
            ? kAccentNeon.withValues(alpha: 0.9)
            : kSkinNearShade,
    );

    // Cranium & facial profile
    final headPath = Path()
      ..moveTo(2, -18) // Crown
      ..cubicTo(14, -18, 16, -6, 16, 2) // Forehead & brow
      ..lineTo(19, 4) // Nose tip
      ..lineTo(15, 7) // Subnasale
      ..lineTo(16, 11) // Lips
      ..lineTo(14, 15) // Chin
      ..lineTo(5, 17) // Jawline
      ..lineTo(-6, 12) // Mandibular angle
      ..cubicTo(-18, 10, -18, -14, 2, -18) // Occiput back of head
      ..close();

    canvas.drawPath(headPath, Paint()..color = kSkinNear);

    // Athletic cropped hair / cap contour
    final hairPath = Path()
      ..moveTo(-12, -8)
      ..cubicTo(-16, -16, 4, -20, 12, -14)
      ..cubicTo(8, -11, 2, -10, -3, -11)
      ..close();
    canvas.drawPath(hairPath, Paint()..color = const Color(0xFF1E293B));

    // Ear
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-2, 3), width: 5, height: 8),
      Paint()..color = kSkinNearShade,
    );

    // Eye profile cue
    canvas.drawCircle(
      const Offset(9, 0),
      1.8,
      Paint()..color = const Color(0xFF1E293B),
    );

    canvas.restore();
  }

  /// Draws athlete fingers and thumb securely wrapping around a bar or handle
  static void drawHandWrap(
    Canvas canvas, {
    required Offset handCenter,
    double radius = 7.0,
    Color skinColor = kSkinNear,
    bool isVertical = false,
  }) {
    final wrapPaint = Paint()..color = skinColor;
    if (isVertical) {
      // Fingers wrapping around vertical bar / handle
      for (int i = -1; i <= 2; i++) {
        canvas.drawCircle(
          handCenter + Offset(0, i * 3.4),
          3.0,
          wrapPaint,
        );
      }
      // Opposing thumb
      canvas.drawOval(
        Rect.fromCenter(
          center: handCenter + const Offset(-4.5, 0),
          width: 5,
          height: 8,
        ),
        wrapPaint,
      );
    } else {
      // Fingers wrapping around horizontal bar / handle
      for (int i = -1; i <= 2; i++) {
        canvas.drawCircle(
          handCenter + Offset(i * 3.4, 0),
          3.0,
          wrapPaint,
        );
      }
      // Opposing thumb
      canvas.drawOval(
        Rect.fromCenter(
          center: handCenter + const Offset(0, 4.5),
          width: 8,
          height: 5,
        ),
        wrapPaint,
      );
    }
  }

  // ===========================================================================
  // 2. SCULPTED TORSO & PELVIS
  // ===========================================================================
  static void drawTorso(
    Canvas canvas, {
    required Offset hip,
    required Offset shoulder,
    double spineAngle = 0,
    bool highlightChest = false,
    bool highlightBack = false,
    bool highlightAbs = false,
    bool highlightGlutes = false,
  }) {
    final diff = shoulder - hip;
    final len = diff.distance;
    final dir = diff / (len > 0 ? len : 1);
    final normal = Offset(-dir.dy, dir.dx);

    // Pelvis base point
    final pBack = hip - normal * 14;
    final pFront = hip + normal * 12;
    final sBack = shoulder - normal * 18;
    final sFront = shoulder + normal * 18;

    // Muscular Torso Path
    final torsoPath = Path()
      ..moveTo(pBack.dx, pBack.dy)
      ..cubicTo(
        // Latissimus dorsi arch
        (hip + diff * 0.45 - normal * 22).dx,
        (hip + diff * 0.45 - normal * 22).dy,
        (hip + diff * 0.75 - normal * 24).dx,
        (hip + diff * 0.75 - normal * 24).dy,
        sBack.dx,
        sBack.dy,
      )
      ..lineTo(sFront.dx, sFront.dy) // Clavicle / shoulder top
      ..cubicTo(
        // Pectoralis major bulge into upper chest
        (hip + diff * 0.85 + normal * 22).dx,
        (hip + diff * 0.85 + normal * 22).dy,
        // Ribcage / serratus
        (hip + diff * 0.60 + normal * 18).dx,
        (hip + diff * 0.60 + normal * 18).dy,
        // Abdominal wall
        (hip + diff * 0.35 + normal * 15).dx,
        (hip + diff * 0.35 + normal * 15).dy,
      )
      ..lineTo(pFront.dx, pFront.dy) // Lower abdomen into waist
      ..close();

    // Base torso fill
    canvas.drawPath(torsoPath, Paint()..color = kSkinNear);

    // Muscular segmentation overlays
    // Gluteus Maximus at pelvis
    final glutePath = Path()
      ..addOval(
        Rect.fromCenter(
          center: hip - normal * 8,
          width: 28,
          height: 26,
        ),
      );
    if (highlightGlutes) {
      canvas.drawPath(
        glutePath,
        Paint()
          ..color = kAccentNeon.withValues(alpha: 0.85)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3),
      );
    } else {
      canvas.drawPath(
        glutePath,
        Paint()..color = kShortsNear,
      );
    }

    // Pectoralis Major highlight
    if (highlightChest) {
      final chestPath = Path()
        ..moveTo(sFront.dx, sFront.dy)
        ..lineTo((shoulder + diff * -0.25 + normal * 20).dx, (shoulder + diff * -0.25 + normal * 20).dy)
        ..lineTo((shoulder + diff * -0.28 + normal * 2).dx, (shoulder + diff * -0.28 + normal * 2).dy)
        ..lineTo((shoulder - normal * 4).dx, (shoulder - normal * 4).dy)
        ..close();
      canvas.drawPath(
        chestPath,
        Paint()
          ..color = kAccentNeon.withValues(alpha: 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3),
      );
    }

    // Latissimus Dorsi / Erector Spinae highlight
    if (highlightBack) {
      final backPath = Path()
        ..moveTo(pBack.dx, pBack.dy)
        ..lineTo(sBack.dx, sBack.dy)
        ..lineTo((shoulder - normal * 8 + diff * -0.3).dx, (shoulder - normal * 8 + diff * -0.3).dy)
        ..lineTo((hip - normal * 4 + diff * 0.2).dx, (hip - normal * 4 + diff * 0.2).dy)
        ..close();
      canvas.drawPath(
        backPath,
        Paint()
          ..color = kAccentNeon.withValues(alpha: 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4),
      );
    }

    // Abdominal Wall (six-pack segmentation lines)
    if (highlightAbs) {
      final absPath = Path()
        ..moveTo((hip + diff * 0.25 + normal * 14).dx, (hip + diff * 0.25 + normal * 14).dy)
        ..lineTo((hip + diff * 0.65 + normal * 16).dx, (hip + diff * 0.65 + normal * 16).dy)
        ..lineTo((hip + diff * 0.65 + normal * 4).dx, (hip + diff * 0.65 + normal * 4).dy)
        ..lineTo((hip + diff * 0.25 + normal * 4).dx, (hip + diff * 0.25 + normal * 4).dy)
        ..close();
      canvas.drawPath(
        absPath,
        Paint()
          ..color = kAccentNeon.withValues(alpha: 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3),
      );
    } else {
      // Subtle anatomical ab contours
      final abLinePaint = Paint()
        ..color = kSkinNearShade.withValues(alpha: 0.6)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        hip + diff * 0.38 + normal * 8,
        hip + diff * 0.38 + normal * 13,
        abLinePaint,
      );
      canvas.drawLine(
        hip + diff * 0.52 + normal * 9,
        hip + diff * 0.52 + normal * 15,
        abLinePaint,
      );
    }

    // Athletic training shorts over hips
    final shortsPath = Path()
      ..moveTo((hip - normal * 14).dx, (hip - normal * 14).dy)
      ..lineTo((hip - normal * 10 - diff * 0.15).dx, (hip - normal * 10 - diff * 0.15).dy)
      ..lineTo((hip + normal * 8 - diff * 0.15).dx, (hip + normal * 8 - diff * 0.15).dy)
      ..lineTo((hip + normal * 12).dx, (hip + normal * 12).dy)
      ..close();
    canvas.drawPath(shortsPath, Paint()..color = kShortsNear);
  }

  // ===========================================================================
  // 3. ARTICULATED ARM (SHOULDER -> ELBOW -> WRIST -> HAND)
  // ===========================================================================
  static void drawArm(
    Canvas canvas, {
    required Offset shoulder,
    required Offset elbow,
    required Offset wrist,
    bool isFar = false,
    bool highlightBiceps = false,
    bool highlightTriceps = false,
    bool highlightDeltoid = false,
    bool highlightForearm = false,
    Offset? gripTarget,
  }) {
    final baseSkin = isFar ? kSkinFar : kSkinNear;
    final shadeSkin = isFar ? kSkinFarShade : kSkinNearShade;

    // Upper arm vector
    final upperDiff = elbow - shoulder;
    final upperLen = upperDiff.distance;
    final upperDir = upperDiff / (upperLen > 0 ? upperLen : 1);
    final upperNorm = Offset(-upperDir.dy, upperDir.dx);

    // Forearm vector
    final foreDiff = wrist - elbow;
    final foreLen = foreDiff.distance;
    final foreDir = foreDiff / (foreLen > 0 ? foreLen : 1);
    final foreNorm = Offset(-foreDir.dy, foreDir.dx);

    // 1. Deltoid Shoulder Cap
    final deltoidPath = Path()
      ..addOval(
        Rect.fromCenter(
          center: shoulder,
          width: 22,
          height: 22,
        ),
      );
    canvas.drawPath(
      deltoidPath,
      Paint()
        ..color = highlightDeltoid
            ? kAccentNeon.withValues(alpha: 0.95)
            : (isFar ? kSkinFarShade : kSkinNear),
    );

    // 2. Sculpted Upper Arm (Biceps anterior curve + Triceps posterior curve)
    final upperArmPath = Path()
      ..moveTo((shoulder - upperNorm * 9).dx, (shoulder - upperNorm * 9).dy)
      ..cubicTo(
        // Triceps curve (posterior)
        (shoulder + upperDiff * 0.45 - upperNorm * 13).dx,
        (shoulder + upperDiff * 0.45 - upperNorm * 13).dy,
        (shoulder + upperDiff * 0.70 - upperNorm * 11).dx,
        (shoulder + upperDiff * 0.70 - upperNorm * 11).dy,
        (elbow - upperNorm * 7).dx,
        (elbow - upperNorm * 7).dy,
      )
      ..lineTo((elbow + upperNorm * 7).dx, (elbow + upperNorm * 7).dy)
      ..cubicTo(
        // Biceps curve (anterior)
        (shoulder + upperDiff * 0.65 + upperNorm * 12).dx,
        (shoulder + upperDiff * 0.65 + upperNorm * 12).dy,
        (shoulder + upperDiff * 0.35 + upperNorm * 11).dx,
        (shoulder + upperDiff * 0.35 + upperNorm * 11).dy,
        (shoulder + upperNorm * 9).dx,
        (shoulder + upperNorm * 9).dy,
      )
      ..close();

    canvas.drawPath(upperArmPath, Paint()..color = baseSkin);

    // Triceps highlight overlay
    if (highlightTriceps) {
      final tricepsHighlight = Path()
        ..moveTo((shoulder - upperNorm * 8).dx, (shoulder - upperNorm * 8).dy)
        ..cubicTo(
          (shoulder + upperDiff * 0.45 - upperNorm * 13).dx,
          (shoulder + upperDiff * 0.45 - upperNorm * 13).dy,
          (shoulder + upperDiff * 0.70 - upperNorm * 11).dx,
          (shoulder + upperDiff * 0.70 - upperNorm * 11).dy,
          (elbow - upperNorm * 6).dx,
          (elbow - upperNorm * 6).dy,
        )
        ..lineTo(elbow.dx, elbow.dy)
        ..lineTo(shoulder.dx, shoulder.dy)
        ..close();
      canvas.drawPath(
        tricepsHighlight,
        Paint()
          ..color = kAccentNeon.withValues(alpha: 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3),
      );
    }

    // Biceps highlight overlay
    if (highlightBiceps) {
      final bicepsHighlight = Path()
        ..moveTo(shoulder.dx, shoulder.dy)
        ..lineTo(elbow.dx, elbow.dy)
        ..cubicTo(
          (shoulder + upperDiff * 0.65 + upperNorm * 12).dx,
          (shoulder + upperDiff * 0.65 + upperNorm * 12).dy,
          (shoulder + upperDiff * 0.35 + upperNorm * 11).dx,
          (shoulder + upperDiff * 0.35 + upperNorm * 11).dy,
          (shoulder + upperNorm * 8).dx,
          (shoulder + upperNorm * 8).dy,
        )
        ..close();
      canvas.drawPath(
        bicepsHighlight,
        Paint()
          ..color = kAccentNeon.withValues(alpha: 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3),
      );
    }

    // Smooth overlapping elbow joint cap
    canvas.drawCircle(elbow, 7.5, Paint()..color = shadeSkin);

    // 3. Sculpted Forearm (Brachioradialis taper into wrist)
    final forearmPath = Path()
      ..moveTo((elbow - foreNorm * 7).dx, (elbow - foreNorm * 7).dy)
      ..cubicTo(
        // Flexor mass
        (elbow + foreDiff * 0.40 - foreNorm * 9).dx,
        (elbow + foreDiff * 0.40 - foreNorm * 9).dy,
        (elbow + foreDiff * 0.75 - foreNorm * 6).dx,
        (elbow + foreDiff * 0.75 - foreNorm * 6).dy,
        (wrist - foreNorm * 4.5).dx,
        (wrist - foreNorm * 4.5).dy,
      )
      ..lineTo((wrist + foreNorm * 4.5).dx, (wrist + foreNorm * 4.5).dy)
      ..cubicTo(
        // Brachioradialis curve
        (elbow + foreDiff * 0.70 + foreNorm * 8).dx,
        (elbow + foreDiff * 0.70 + foreNorm * 8).dy,
        (elbow + foreDiff * 0.30 + foreNorm * 9.5).dx,
        (elbow + foreDiff * 0.30 + foreNorm * 9.5).dy,
        (elbow + foreNorm * 7).dx,
        (elbow + foreNorm * 7).dy,
      )
      ..close();

    canvas.drawPath(
      forearmPath,
      Paint()
        ..color = highlightForearm
            ? kAccentNeon.withValues(alpha: 0.9)
            : baseSkin,
    );

    // Smooth wrist joint cap
    canvas.drawCircle(wrist, 5, Paint()..color = shadeSkin);

    // 4. Clenched Athlete Fist / Hand
    final handCenter = gripTarget ?? (wrist + foreDir * 8);
    canvas.drawCircle(
      handCenter,
      6.5,
      Paint()..color = isFar ? kSkinFarShade : kSkinNear,
    );
    // Finger curl detail
    canvas.drawArc(
      Rect.fromCircle(center: handCenter, radius: 5.5),
      0,
      math.pi * 1.5,
      false,
      Paint()
        ..color = isFar ? kSkinFar : kSkinNearShade
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  // ===========================================================================
  // 4. ARTICULATED LEG (HIP -> KNEE -> ANKLE -> FOOT)
  // ===========================================================================
  static void drawLeg(
    Canvas canvas, {
    required Offset hip,
    required Offset knee,
    required Offset ankle,
    required Offset toe,
    bool isFar = false,
    bool highlightQuads = false,
    bool highlightHamstrings = false,
    bool highlightCalf = false,
    bool highlightTibialis = false,
  }) {
    final baseSkin = isFar ? kSkinFar : kSkinNear;
    final shadeSkin = isFar ? kSkinFarShade : kSkinNearShade;
    final shortsColor = isFar ? kShortsFar : kShortsNear;
    final shoeUpper = isFar ? kShoeUpperFar : kShoeUpperNear;

    // Thigh vector
    final thighDiff = knee - hip;
    final thighLen = thighDiff.distance;
    final thighDir = thighDiff / (thighLen > 0 ? thighLen : 1);
    final thighNorm = Offset(-thighDir.dy, thighDir.dx);

    // Lower leg vector
    final shinDiff = ankle - knee;
    final shinLen = shinDiff.distance;
    final shinDir = shinDiff / (shinLen > 0 ? shinLen : 1);
    final shinNorm = Offset(-shinDir.dy, shinDir.dx);

    // 1. Sculpted Thigh (Anterior Quadriceps curve + Posterior Hamstrings curve)
    final thighPath = Path()
      ..moveTo((hip - thighNorm * 13).dx, (hip - thighNorm * 13).dy)
      ..cubicTo(
        // Hamstring curve (posterior)
        (hip + thighDiff * 0.40 - thighNorm * 16).dx,
        (hip + thighDiff * 0.40 - thighNorm * 16).dy,
        (hip + thighDiff * 0.75 - thighNorm * 13).dx,
        (hip + thighDiff * 0.75 - thighNorm * 13).dy,
        (knee - thighNorm * 9).dx,
        (knee - thighNorm * 9).dy,
      )
      ..lineTo((knee + thighNorm * 9).dx, (knee + thighNorm * 9).dy)
      ..cubicTo(
        // Quadriceps sweep (anterior Vastus Lateralis / Rectus Femoris)
        (hip + thighDiff * 0.65 + thighNorm * 16).dx,
        (hip + thighDiff * 0.65 + thighNorm * 16).dy,
        (hip + thighDiff * 0.30 + thighNorm * 15).dx,
        (hip + thighDiff * 0.30 + thighNorm * 15).dy,
        (hip + thighNorm * 13).dx,
        (hip + thighNorm * 13).dy,
      )
      ..close();

    canvas.drawPath(thighPath, Paint()..color = baseSkin);

    // Quadriceps activation overlay
    if (highlightQuads) {
      final quadPath = Path()
        ..moveTo(hip.dx, hip.dy)
        ..lineTo(knee.dx, knee.dy)
        ..cubicTo(
          (hip + thighDiff * 0.65 + thighNorm * 16).dx,
          (hip + thighDiff * 0.65 + thighNorm * 16).dy,
          (hip + thighDiff * 0.30 + thighNorm * 15).dx,
          (hip + thighDiff * 0.30 + thighNorm * 15).dy,
          (hip + thighNorm * 12).dx,
          (hip + thighNorm * 12).dy,
        )
        ..close();
      canvas.drawPath(
        quadPath,
        Paint()
          ..color = kAccentNeon.withValues(alpha: 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3.5),
      );
    }

    // Hamstrings activation overlay
    if (highlightHamstrings) {
      final hamPath = Path()
        ..moveTo((hip - thighNorm * 12).dx, (hip - thighNorm * 12).dy)
        ..cubicTo(
          (hip + thighDiff * 0.40 - thighNorm * 16).dx,
          (hip + thighDiff * 0.40 - thighNorm * 16).dy,
          (hip + thighDiff * 0.75 - thighNorm * 13).dx,
          (hip + thighDiff * 0.75 - thighNorm * 13).dy,
          (knee - thighNorm * 8).dx,
          (knee - thighNorm * 8).dy,
        )
        ..lineTo(knee.dx, knee.dy)
        ..lineTo(hip.dx, hip.dy)
        ..close();
      canvas.drawPath(
        hamPath,
        Paint()
          ..color = kAccentAmber.withValues(alpha: 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3.5),
      );
    }

    // Athletic shorts hem on upper thigh
    final shortsHem = Path()
      ..moveTo((hip - thighNorm * 13).dx, (hip - thighNorm * 13).dy)
      ..lineTo((hip + thighDiff * 0.35 - thighNorm * 14).dx, (hip + thighDiff * 0.35 - thighNorm * 14).dy)
      ..lineTo((hip + thighDiff * 0.35 + thighNorm * 14).dx, (hip + thighDiff * 0.35 + thighNorm * 14).dy)
      ..lineTo((hip + thighNorm * 13).dx, (hip + thighNorm * 13).dy)
      ..close();
    canvas.drawPath(shortsHem, Paint()..color = shortsColor);

    // Overlapping Knee Joint Cap (Patella)
    canvas.drawCircle(knee, 9.5, Paint()..color = shadeSkin);

    // 2. Sculpted Lower Leg (Gastrocnemius calf belly + Achilles tendon)
    final shinPath = Path()
      ..moveTo((knee - shinNorm * 8.5).dx, (knee - shinNorm * 8.5).dy)
      ..cubicTo(
        // Posterior Gastrocnemius / Soleus curve
        (knee + shinDiff * 0.35 - shinNorm * 14).dx,
        (knee + shinDiff * 0.35 - shinNorm * 14).dy,
        (knee + shinDiff * 0.70 - shinNorm * 10).dx,
        (knee + shinDiff * 0.70 - shinNorm * 10).dy,
        (ankle - shinNorm * 5).dx,
        (ankle - shinNorm * 5).dy,
      )
      ..lineTo((ankle + shinNorm * 5).dx, (ankle + shinNorm * 5).dy)
      ..cubicTo(
        // Anterior Tibia / Tibialis Anterior line
        (knee + shinDiff * 0.70 + shinNorm * 6).dx,
        (knee + shinDiff * 0.70 + shinNorm * 6).dy,
        (knee + shinDiff * 0.35 + shinNorm * 8).dx,
        (knee + shinDiff * 0.35 + shinNorm * 8).dy,
        (knee + shinNorm * 8.5).dx,
        (knee + shinNorm * 8.5).dy,
      )
      ..close();

    canvas.drawPath(shinPath, Paint()..color = baseSkin);

    // Calf (Gastrocnemius / Soleus) highlight
    if (highlightCalf) {
      final calfHighlight = Path()
        ..moveTo((knee - shinNorm * 8).dx, (knee - shinNorm * 8).dy)
        ..cubicTo(
          (knee + shinDiff * 0.35 - shinNorm * 14).dx,
          (knee + shinDiff * 0.35 - shinNorm * 14).dy,
          (knee + shinDiff * 0.70 - shinNorm * 10).dx,
          (knee + shinDiff * 0.70 - shinNorm * 10).dy,
          (ankle - shinNorm * 4.5).dx,
          (ankle - shinNorm * 4.5).dy,
        )
        ..lineTo(ankle.dx, ankle.dy)
        ..lineTo(knee.dx, knee.dy)
        ..close();
      canvas.drawPath(
        calfHighlight,
        Paint()
          ..color = kAccentNeon.withValues(alpha: 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3.5),
      );
    }

    // Tibialis Anterior highlight
    if (highlightTibialis) {
      final tibialisHighlight = Path()
        ..moveTo(knee.dx, knee.dy)
        ..lineTo(ankle.dx, ankle.dy)
        ..cubicTo(
          (knee + shinDiff * 0.70 + shinNorm * 6).dx,
          (knee + shinDiff * 0.70 + shinNorm * 6).dy,
          (knee + shinDiff * 0.35 + shinNorm * 8).dx,
          (knee + shinDiff * 0.35 + shinNorm * 8).dy,
          (knee + shinNorm * 8).dx,
          (knee + shinNorm * 8).dy,
        )
        ..close();
      canvas.drawPath(
        tibialisHighlight,
        Paint()
          ..color = kAccentCyan.withValues(alpha: 0.95)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3.5),
      );
    }

    // Malleolus Ankle Bone
    canvas.drawCircle(ankle, 5.5, Paint()..color = shadeSkin);

    // 3. Athletic Lifting Shoe
    final footDiff = toe - ankle;
    final footDir = footDiff / (footDiff.distance > 0 ? footDiff.distance : 1);
    final footNorm = Offset(-footDir.dy, footDir.dx);

    final heel = ankle - footDir * 6 + footNorm * 2;
    final shoeSoleBottom = heel + footNorm * 8;
    final toeBottom = toe + footNorm * 8;

    // Shoe upper
    final shoePath = Path()
      ..moveTo((ankle - footNorm * 4).dx, (ankle - footNorm * 4).dy)
      ..lineTo(heel.dx, heel.dy)
      ..lineTo(shoeSoleBottom.dx, shoeSoleBottom.dy)
      ..lineTo(toeBottom.dx, toeBottom.dy)
      ..lineTo(toe.dx, toe.dy)
      ..lineTo((ankle + footDir * 4 + footNorm * 2).dx, (ankle + footDir * 4 + footNorm * 2).dy)
      ..close();
    canvas.drawPath(shoePath, Paint()..color = shoeUpper);

    // Firm flat lifting shoe sole
    canvas.drawLine(
      shoeSoleBottom,
      toeBottom,
      Paint()
        ..color = kShoeSole
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    // Neon accent branding stripe
    canvas.drawLine(
      heel + footDir * 6 + footNorm * 2,
      ankle + footDir * 7 + footNorm * 4,
      Paint()
        ..color = kAccentNeon
        ..strokeWidth = 2,
    );
  }

  // ===========================================================================
  // 5. EQUIPMENT: BARBELLS, DUMBBELLS, BENCHES, RACKS, CABLES & MACHINES
  // ===========================================================================

  /// Detailed Olympic barbell with knurled steel bar, collars, and weight plates
  static void drawBarbell(
    Canvas canvas, {
    required Offset center,
    double plateRadius = 36,
    double barLength = 260,
    bool isVertical = false,
    int layer = 0,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (isVertical) canvas.rotate(math.pi / 2);

    if (layer == 0 || layer == 1) {
      // Far Olympic bumper plates & collar (Layer 1: behind athlete)
      _drawPlates(canvas, Offset(-barLength / 2 + 25, 0), plateRadius, isFar: true);
    }

    if (layer == 0 || layer == 2) {
      // Steel barbell shaft with chrome shine & knurling (Layer 2)
      canvas.drawLine(
        Offset(-barLength / 2, 0),
        Offset(barLength / 2, 0),
        Paint()
          ..color = kSteelChrome
          ..strokeWidth = 5.5
          ..strokeCap = StrokeCap.round,
      );

      final knurlPaint = Paint()
        ..color = const Color(0xFF64748B)
        ..strokeWidth = 4;
      canvas.drawLine(const Offset(-40, 0), const Offset(-15, 0), knurlPaint);
      canvas.drawLine(const Offset(15, 0), const Offset(40, 0), knurlPaint);

      // Sleeves
      final sleevePaint = Paint()
        ..color = kSteelBright
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.square;
      canvas.drawLine(Offset(-barLength / 2, 0), Offset(-barLength / 2 + 35, 0), sleevePaint);
      canvas.drawLine(Offset(barLength / 2 - 35, 0), Offset(barLength / 2, 0), sleevePaint);
    }

    if (layer == 0 || layer == 4) {
      // Near Olympic bumper plates & collar (Layer 4: overlapping in front)
      _drawPlates(canvas, Offset(barLength / 2 - 25, 0), plateRadius, isFar: false);
    }

    canvas.restore();
  }

  static void _drawPlates(Canvas canvas, Offset at, double radius, {bool isFar = false}) {
    final plateColor = isFar ? const Color(0xFF0F172A) : const Color(0xFF1E293B);
    final rimColor = isFar ? kAccentNeon.withValues(alpha: 0.3) : kAccentNeon.withValues(alpha: 0.7);

    // Large 45lb/20kg Olympic bumper plate
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: at, width: 12, height: radius * 2),
        const Radius.circular(3),
      ),
      Paint()..color = plateColor,
    );
    // Outer colored rim ring (Olympic standard competition green / red)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: at, width: 12, height: radius * 2),
        const Radius.circular(3),
      ),
      Paint()
        ..color = rimColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // Smaller inner plate
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: at + Offset(isFar ? -6 : 7, 0), width: 6, height: radius * 1.6),
        const Radius.circular(2),
      ),
      Paint()..color = isFar ? const Color(0xFF1E293B) : const Color(0xFF334155),
    );

    // Spring collar clip
    canvas.drawCircle(
      at + Offset(isFar ? 6 : -7, 0),
      5,
      Paint()..color = isFar ? kSteelMedium : kSteelChrome,
    );
  }

  /// Ergonomic dumbbell with contoured chrome handle and hex heads
  static void drawDumbbell(
    Canvas canvas, {
    required Offset center,
    double angle = 0,
    double headRadius = 14,
    double length = 36,
    int layer = 0,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    if (layer == 0 || layer == 1) {
      // Far Hex Head
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(-length / 2 + 5, 0),
            width: 9,
            height: headRadius * 2,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFF0F172A),
      );
    }

    if (layer == 0 || layer == 2) {
      // Chrome handle
      canvas.drawLine(
        Offset(-length / 2, 0),
        Offset(length / 2, 0),
        Paint()
          ..color = kSteelChrome
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round,
      );
    }

    if (layer == 0 || layer == 4) {
      // Near Hex Head
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(length / 2 - 5, 0),
            width: 9,
            height: headRadius * 2,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFF1E293B),
      );
    }

    canvas.restore();
  }

  /// Flat / Incline / Decline Gym Workout Bench
  static void drawBench(
    Canvas canvas, {
    required Offset headPos,
    required Offset hipPos,
    bool isFlat = true,
    int layer = 0,
  }) {
    if (layer == 0 || layer == 1) {
      // Far legs (dark steel)
      canvas.drawLine(
        headPos + const Offset(12, 10),
        Offset(headPos.dx + 12, 345),
        Paint()..color = kSteelDark..strokeWidth = 9,
      );
      canvas.drawLine(
        hipPos - const Offset(18, -10),
        Offset(hipPos.dx - 18, 345),
        Paint()..color = kSteelDark..strokeWidth = 9,
      );
    }

    if (layer == 0 || layer == 2) {
      // Floor base runner beam
      canvas.drawLine(
        const Offset(70, 345),
        const Offset(470, 345),
        Paint()..color = kSteelDark..strokeWidth = 10..strokeCap = StrokeCap.square,
      );

      // Near frame uprights
      canvas.drawLine(
        headPos + const Offset(18, 6),
        Offset(headPos.dx + 18, 345),
        Paint()..color = kSteelFrame..strokeWidth = 10,
      );
      canvas.drawLine(
        hipPos - const Offset(12, -6),
        Offset(hipPos.dx - 12, 345),
        Paint()..color = kSteelFrame..strokeWidth = 10,
      );

      // High-density foam bench pad (60mm thick, stitched vinyl, accent piping)
      final benchDir = hipPos - headPos;
      final benchLen = benchDir.distance;
      final dir = benchDir / (benchLen > 0 ? benchLen : 1);
      final norm = Offset(-dir.dy, dir.dx);

      final padPath = Path()
        ..moveTo((headPos - dir * 20 - norm * 8).dx, (headPos - dir * 20 - norm * 8).dy)
        ..lineTo((hipPos + dir * 30 - norm * 8).dx, (hipPos + dir * 30 - norm * 8).dy)
        ..lineTo((hipPos + dir * 30 + norm * 8).dx, (hipPos + dir * 30 + norm * 8).dy)
        ..lineTo((headPos - dir * 20 + norm * 8).dx, (headPos - dir * 20 + norm * 8).dy)
        ..close();

      canvas.drawPath(padPath, Paint()..color = const Color(0xFF1E293B));
      canvas.drawPath(
        padPath,
        Paint()
          ..color = kAccentNeon.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  /// Heavy Duty Power Rack / Squat Cage
  static void drawSquatRack(
    Canvas canvas, {
    double rackX = 280,
    double floorY = 345,
    double height = 285,
    double jHookY = 85,
    double safetyArmY = 250,
    int layer = 0,
  }) {
    if (layer == 0 || layer == 1) {
      // Rear upright
      canvas.drawLine(
        Offset(rackX - 50, floorY - height),
        Offset(rackX - 50, floorY),
        Paint()..color = kSteelDark..strokeWidth = 12..strokeCap = StrokeCap.square,
      );
      // Far J-hook
      canvas.drawLine(
        Offset(rackX - 54, jHookY),
        Offset(rackX - 44, jHookY),
        Paint()..color = kSteelBright..strokeWidth = 5,
      );
      // Far safety spotter arm
      canvas.drawLine(
        Offset(rackX - 55, safetyArmY),
        Offset(rackX + 45, safetyArmY),
        Paint()..color = kAccentAmber.withValues(alpha: 0.6)..strokeWidth = 7,
      );
    }

    if (layer == 0 || layer == 2) {
      // Base beam and top crossmember
      canvas.drawLine(
        Offset(rackX - 65, floorY - height),
        Offset(rackX + 65, floorY - height),
        Paint()..color = kSteelDark..strokeWidth = 10,
      );
      canvas.drawLine(
        Offset(rackX - 75, floorY),
        Offset(rackX + 75, floorY),
        Paint()..color = kSteelDark..strokeWidth = 12,
      );
    }

    if (layer == 0 || layer == 4) {
      // Front upright
      canvas.drawLine(
        Offset(rackX + 50, floorY - height),
        Offset(rackX + 50, floorY),
        Paint()..color = kSteelFrame..strokeWidth = 12..strokeCap = StrokeCap.square,
      );

      // Numbered peg holes
      final pegPaint = Paint()..color = kSteelBright;
      for (double y = floorY - height + 30; y < floorY - 20; y += 18) {
        canvas.drawCircle(Offset(rackX + 50, y), 2.2, pegPaint);
      }

      // Near J-hook holding bar
      final hookPath = Path()
        ..moveTo(rackX + 46, jHookY - 8)
        ..lineTo(rackX + 54, jHookY)
        ..lineTo(rackX + 58, jHookY + 8)
        ..lineTo(rackX + 46, jHookY + 8)
        ..close();
      canvas.drawPath(hookPath, Paint()..color = kSteelBright);

      // Near safety spotter arm with high-visibility amber accent
      canvas.drawLine(
        Offset(rackX - 45, safetyArmY),
        Offset(rackX + 60, safetyArmY),
        Paint()..color = kAccentAmber..strokeWidth = 8..strokeCap = StrokeCap.square,
      );
    }
  }

  /// Cable Machine Tower with Pulleys, Moving Weight Stack, and Taut Cable
  static void drawCableTower(
    Canvas canvas, {
    required Offset towerBase,
    required Offset pulleyPos,
    required Offset handlePos,
    double stackTravel = 0,
    bool isRope = false,
    int layer = 0,
  }) {
    final towerX = towerBase.dx;
    const towerTopY = 35.0;
    final floorY = towerBase.dy;

    if (layer == 0 || layer == 1) {
      // Tower vertical steel housing frame
      canvas.drawLine(
        Offset(towerX, towerTopY),
        Offset(towerX, floorY),
        Paint()..color = kSteelDark..strokeWidth = 16,
      );
      // Twin chrome guide rods
      final rodPaint = Paint()..color = kSteelChrome..strokeWidth = 3.5;
      canvas.drawLine(Offset(towerX - 11, towerTopY + 15), Offset(towerX - 11, floorY - 15), rodPaint);
      canvas.drawLine(Offset(towerX + 11, towerTopY + 15), Offset(towerX + 11, floorY - 15), rodPaint);

      // Resting bottom plates
      const stackBottom = 280.0;
      for (int i = 4; i < 9; i++) {
        final plateY = stackBottom + i * 8.0;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(towerX, plateY), width: 36, height: 7),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xFF1E293B),
        );
      }
    }

    if (layer == 0 || layer == 2) {
      // Active lifted plates (move up by stackTravel * 45)
      const stackBottom = 280.0;
      final currentStackY = stackBottom - stackTravel * 45;
      for (int i = 0; i < 4; i++) {
        final plateY = currentStackY + i * 8.0;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(towerX, plateY), width: 38, height: 7),
            const Radius.circular(2),
          ),
          Paint()..color = const Color(0xFF334155),
        );
      }

      // Rotating Pulley Wheel at pulleyPos
      canvas.drawCircle(pulleyPos, 13, Paint()..color = kSteelBright);
      canvas.drawCircle(pulleyPos, 9, Paint()..color = kSteelDark);
      canvas.drawCircle(pulleyPos, 4, Paint()..color = kSteelChrome);

      // Taut steel cable line from pulley to handle
      final cablePaint = Paint()
        ..color = kSteelChrome
        ..strokeWidth = 2.4;
      canvas.drawLine(pulleyPos, handlePos, cablePaint);
      // Internal cable line into tower to top of stack
      canvas.drawLine(pulleyPos, Offset(towerX, currentStackY), cablePaint);

      // Attachment Handle
      if (isRope) {
        final ropeDiff = handlePos - pulleyPos;
        final ropeDir = ropeDiff / (ropeDiff.distance > 0 ? ropeDiff.distance : 1);
        final ropeNorm = Offset(-ropeDir.dy, ropeDir.dx);
        canvas.drawLine(
          handlePos - ropeNorm * 11,
          handlePos + ropeNorm * 11,
          Paint()
            ..color = const Color(0xFFD4D4D8)
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(handlePos - ropeNorm * 11, 5, Paint()..color = const Color(0xFF18181B));
        canvas.drawCircle(handlePos + ropeNorm * 11, 5, Paint()..color = const Color(0xFF18181B));
      } else {
        canvas.drawArc(
          Rect.fromCenter(center: handlePos, width: 14, height: 18),
          -math.pi / 2,
          math.pi,
          false,
          Paint()
            ..color = kSteelBright
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
    }

    if (layer == 0 || layer == 4) {
      // Selector pin in active plate
      const stackBottom = 280.0;
      final currentStackY = stackBottom - stackTravel * 45;
      canvas.drawCircle(
        Offset(towerX + 16, currentStackY + 16),
        3.5,
        Paint()..color = kAccentAmber,
      );
    }
  }

  /// 45-Degree Sled Leg Press Machine
  static void drawLegPressMachine(
    Canvas canvas, {
    required Offset sledCenter,
    Offset? footPos,
    double railAngle = -math.pi / 4,
    int layer = 0,
  }) {
    final railDir = Offset(math.cos(railAngle), math.sin(railAngle));
    final railNorm = Offset(-railDir.dy, railDir.dx);

    final railStart = const Offset(135, 335);
    final railEnd = railStart + railDir * 330;

    if (layer == 0 || layer == 1) {
      // Far 45° guide rail
      canvas.drawLine(
        railStart - railNorm * 12,
        railEnd - railNorm * 12,
        Paint()..color = kSteelDark..strokeWidth = 12..strokeCap = StrokeCap.round,
      );
      // Far weight horn loaded with bumper plates
      final hornCenter = sledCenter - railNorm * 28;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: hornCenter, width: 14, height: 75),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFF0F172A),
      );
    }

    if (layer == 0 || layer == 2) {
      // Reclined seat backrest (45° angle, supporting spine from sacrum to shoulders)
      final backPath = Path()
        ..moveTo(90, 245)
        ..lineTo(142, 305)
        ..lineTo(152, 296)
        ..lineTo(100, 236)
        ..close();
      canvas.drawPath(backPath, Paint()..color = const Color(0xFF1E293B));
      canvas.drawPath(
        backPath,
        Paint()
          ..color = kAccentNeon.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Angled seat cushion (supporting glutes)
      final seatPad = Path()
        ..moveTo(142, 305)
        ..lineTo(185, 316)
        ..lineTo(182, 328)
        ..lineTo(138, 317)
        ..close();
      canvas.drawPath(seatPad, Paint()..color = const Color(0xFF1E293B));

      // Seat support frame to floor
      canvas.drawLine(const Offset(115, 275), const Offset(115, 345), Paint()..color = kSteelDark..strokeWidth = 10);
      canvas.drawLine(const Offset(160, 315), const Offset(160, 345), Paint()..color = kSteelDark..strokeWidth = 10);

      // Sled carriage frame
      canvas.save();
      canvas.translate(sledCenter.dx, sledCenter.dy);
      canvas.rotate(railAngle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-35, -20, 70, 40),
          const Radius.circular(6),
        ),
        Paint()..color = const Color(0xFF1E293B),
      );

      // High-grip angled Footplate (perpendicular to rails, exact contact with shoe soles)
      canvas.drawLine(
        const Offset(35, -40),
        const Offset(35, 40),
        Paint()..color = kSteelBright..strokeWidth = 8..strokeCap = StrokeCap.square,
      );
      // Diamond plate tread pattern
      for (double py = -32; py <= 32; py += 10) {
        canvas.drawLine(Offset(32, py), Offset(37, py + 4), Paint()..color = kSteelChrome..strokeWidth = 1.5);
      }
      canvas.restore();
    }

    if (layer == 0 || layer == 4) {
      // Near 45° chrome guide rail
      canvas.drawLine(
        railStart + railNorm * 14,
        railEnd + railNorm * 14,
        Paint()..color = kSteelChrome..strokeWidth = 6..strokeCap = StrokeCap.round,
      );
      // Sled linear bearing housing
      canvas.drawCircle(sledCenter + railNorm * 14, 10, Paint()..color = kSteelFrame);
      canvas.drawCircle(sledCenter + railNorm * 14, 5, Paint()..color = kSteelBright);

      // Near weight horn loaded with Olympic bumper plates
      final hornCenter = sledCenter + railNorm * 28;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: hornCenter, width: 14, height: 85),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFF1E293B),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: hornCenter, width: 14, height: 85),
          const Radius.circular(3),
        ),
        Paint()
          ..color = kAccentNeon.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
      // Chrome horn pin
      canvas.drawCircle(hornCenter, 5, Paint()..color = kSteelChrome);

      // Side safety lock release handle beside seat
      canvas.drawLine(const Offset(142, 300), const Offset(130, 275), Paint()..color = kSteelChrome..strokeWidth = 4..strokeCap = StrokeCap.round);
      canvas.drawCircle(const Offset(130, 275), 5.5, Paint()..color = const Color(0xFFE11D48));
    }
  }

  /// 45-Degree Back Extension (Roman Chair) equipment with exact human-contact surfaces
  static void drawRomanChairBench(
    Canvas canvas, {
    required Offset hip,
    required Offset knee,
    required Offset ankle,
    required Offset toe,
    int layer = 0,
  }) {
    final legNorm = Offset(1 / math.sqrt(2), 1 / math.sqrt(2));

    if (layer == 0 || layer == 1) {
      // Far ground base runner
      canvas.drawLine(
        const Offset(90, 345),
        const Offset(390, 345),
        Paint()..color = kSteelDark..strokeWidth = 12..strokeCap = StrokeCap.square,
      );
      // Far diagonal support strut
      canvas.drawLine(
        const Offset(130, 340),
        const Offset(225, 215),
        Paint()..color = kSteelDark..strokeWidth = 9,
      );
      // Far ankle roller cylinder
      final farRoller = ankle - legNorm * 18 + const Offset(-7, -5);
      canvas.drawCircle(farRoller, 12, Paint()..color = const Color(0xFF645138));
      canvas.drawCircle(farRoller, 4, Paint()..color = kSteelMedium);
    }

    if (layer == 0 || layer == 2) {
      // Ground plane
      canvas.drawLine(
        const Offset(50, 345),
        const Offset(510, 345),
        Paint()..color = const Color(0xFF34404F)..strokeWidth = 2.5,
      );

      // Base frame runner
      canvas.drawLine(
        const Offset(102, 338),
        const Offset(365, 338),
        Paint()..color = kSteelFrame..strokeWidth = 10,
      );

      // Triangulated steel mast
      canvas.drawLine(const Offset(142, 303), const Offset(245, 197), Paint()..color = kSteelFrame..strokeWidth = 10);
      canvas.drawLine(const Offset(245, 197), const Offset(268, 156), Paint()..color = kSteelFrame..strokeWidth = 10);
      canvas.drawLine(const Offset(245, 197), const Offset(343, 338), Paint()..color = kSteelFrame..strokeWidth = 9);
      canvas.drawLine(const Offset(245, 197), const Offset(214, 338), Paint()..color = kSteelFrame..strokeWidth = 9);
      canvas.drawLine(const Offset(142, 303), const Offset(120, 338), Paint()..color = kSteelFrame..strokeWidth = 8);

      // Angled diamond-plate foot platform (rests flush beneath shoe soles)
      final plateStart = ankle - legNorm * 10;
      final plateEnd = ankle + legNorm * 32;
      canvas.drawLine(
        plateStart,
        plateEnd,
        Paint()..color = kSteelBright..strokeWidth = 9..strokeCap = StrokeCap.square,
      );
      canvas.drawLine(
        plateStart,
        plateEnd,
        Paint()..color = kSteelChrome..strokeWidth = 3..strokeCap = StrokeCap.square,
      );

      // 45-degree anterior thigh pad: sits flush against anterior upper thighs,
      // ending at hip crease (hip pivot) so torso hinges cleanly over it!
      final padBottom = knee + legNorm * 14;
      final padTop = hip + legNorm * 12;
      final padDir = (padTop - padBottom);
      final pDir = padDir / (padDir.distance > 0 ? padDir.distance : 1);
      final pNorm = Offset(-pDir.dy, pDir.dx);

      final padPath = Path()
        ..moveTo((padBottom - pNorm * 14).dx, (padBottom - pNorm * 14).dy)
        ..lineTo((padTop - pNorm * 14).dx, (padTop - pNorm * 14).dy)
        ..lineTo(padTop.dx, padTop.dy)
        ..lineTo(padBottom.dx, padBottom.dy)
        ..close();

      canvas.drawPath(padPath, Paint()..color = const Color(0xFF1E293B));
      canvas.drawLine(
        padBottom,
        padTop,
        Paint()..color = const Color(0xFFDAAA5C)..strokeWidth = 16..strokeCap = StrokeCap.round,
      );
    }

    if (layer == 0 || layer == 4) {
      // Near ankle roller bracket from footplate frame
      final rollerCenter = ankle - legNorm * 18;
      canvas.drawLine(
        const Offset(142, 303),
        rollerCenter,
        Paint()..color = kSteelFrame..strokeWidth = 6..strokeCap = StrokeCap.round,
      );

      // Near ankle foam roller: tucked snugly behind Achilles tendon with chrome end-cap
      canvas.drawCircle(rollerCenter, 12, Paint()..color = const Color(0xFFDAAA5C));
      canvas.drawCircle(rollerCenter, 12, Paint()..color = const Color(0xFF645138)..style = PaintingStyle.stroke..strokeWidth = 2);
      canvas.drawCircle(rollerCenter, 4, Paint()..color = kSteelChrome);

      // Chrome angle-adjustment pop-pin on thigh pad mast
      canvas.drawCircle(const Offset(250, 198), 4.5, Paint()..color = kSteelChrome);
    }
  }

  /// Seated Leg Extension machine with knee-aligned pivot axle, lever arm, and shin roller
  static void drawLegExtensionEquipment(
    Canvas canvas, {
    required Offset kneePivot,
    required Offset anklePos,
    double stackTravel = 0,
    int layer = 0,
  }) {
    const towerX = 425.0;
    const floorY = 345.0;

    if (layer == 0 || layer == 1) {
      // Weight tower in background
      drawCableTower(
        canvas,
        towerBase: const Offset(towerX, floorY),
        pulleyPos: const Offset(365, 230),
        handlePos: kneePivot,
        stackTravel: stackTravel,
        layer: 1,
      );
      // Far seat leg
      canvas.drawLine(const Offset(215, 260), const Offset(215, floorY), Paint()..color = kSteelDark..strokeWidth = 8);
    }

    if (layer == 0 || layer == 2) {
      // Seat cushion supporting thighs (flush at y = 255)
      final seatPad = Path()
        ..moveTo(195, 255)
        ..lineTo(kneePivot.dx, 255)
        ..lineTo(kneePivot.dx, 268)
        ..lineTo(195, 268)
        ..close();
      canvas.drawPath(seatPad, Paint()..color = const Color(0xFF1E293B));
      canvas.drawPath(
        seatPad,
        Paint()
          ..color = kAccentNeon.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Backrest cushion (flush behind spine)
      final backPad = Path()
        ..moveTo(175, 170)
        ..lineTo(195, 255)
        ..lineTo(185, 258)
        ..lineTo(165, 173)
        ..close();
      canvas.drawPath(backPad, Paint()..color = const Color(0xFF1E293B));

      // Seat support frame to floor
      canvas.drawLine(const Offset(225, 268), const Offset(225, floorY), Paint()..color = kSteelFrame..strokeWidth = 10);
      canvas.drawLine(const Offset(265, 268), const Offset(265, floorY), Paint()..color = kSteelFrame..strokeWidth = 10);

      // Moving weight stack plates in tower
      drawCableTower(
        canvas,
        towerBase: const Offset(towerX, floorY),
        pulleyPos: const Offset(365, 230),
        handlePos: kneePivot,
        stackTravel: stackTravel,
        layer: 2,
      );

      // Cam pulley at knee pivot connecting to weight stack cable
      canvas.drawCircle(kneePivot, 18, Paint()..color = kSteelDark);
      canvas.drawCircle(kneePivot, 18, Paint()..color = kSteelBright..style = PaintingStyle.stroke..strokeWidth = 2.5);
      canvas.drawLine(kneePivot + const Offset(12, 12), const Offset(365, 230), Paint()..color = kSteelChrome..strokeWidth = 2.2);
    }

    if (layer == 0 || layer == 4) {
      // Knee pivot cam axle bolt
      canvas.drawCircle(kneePivot, 6, Paint()..color = kSteelChrome);

      // Rigid mechanical lever arm from knee pivot to shin roller
      canvas.drawLine(
        kneePivot,
        anklePos,
        Paint()..color = kSteelBright..strokeWidth = 7..strokeCap = StrokeCap.round,
      );
      // Counterweight bracket opposite to lever arm
      final armDiff = anklePos - kneePivot;
      final armDir = armDiff / (armDiff.distance > 0 ? armDiff.distance : 1);
      canvas.drawLine(
        kneePivot,
        kneePivot - armDir * 18,
        Paint()..color = kSteelDark..strokeWidth = 8,
      );
      canvas.drawCircle(kneePivot - armDir * 18, 6, Paint()..color = const Color(0xFF334155));

      // High-density foam shin roller pad locked on anterior shin
      final armNorm = Offset(-armDir.dy, armDir.dx);
      final rollerCenter = anklePos + armNorm * 4;
      canvas.drawCircle(rollerCenter, 12, Paint()..color = const Color(0xFFDAAA5C));
      canvas.drawCircle(rollerCenter, 12, Paint()..color = const Color(0xFF645138)..style = PaintingStyle.stroke..strokeWidth = 2);
      canvas.drawCircle(rollerCenter, 4, Paint()..color = kSteelChrome);

      // Side stabilizing seat handle
      canvas.drawLine(const Offset(215, 260), const Offset(230, 240), Paint()..color = kSteelChrome..strokeWidth = 3.5);
      canvas.drawCircle(const Offset(230, 240), 4, Paint()..color = const Color(0xFF18181B));

      // Selector pin in tower
      drawCableTower(
        canvas,
        towerBase: const Offset(towerX, floorY),
        pulleyPos: const Offset(365, 230),
        handlePos: kneePivot,
        stackTravel: stackTravel,
        layer: 4,
      );
    }
  }

  /// Seated & Prone Leg Curl machine with knee-aligned pivot axle, lever arm, and Achilles roller
  static void drawLegCurlEquipment(
    Canvas canvas, {
    required Offset kneePivot,
    required Offset anklePos,
    double stackTravel = 0,
    bool isProne = false,
    int layer = 0,
  }) {
    const towerX = 425.0;
    const floorY = 345.0;

    if (isProne) {
      // Prone Leg Curl Machine
      if (layer == 0 || layer == 1) {
        drawCableTower(
          canvas,
          towerBase: const Offset(towerX, floorY),
          pulleyPos: const Offset(365, 220),
          handlePos: kneePivot,
          stackTravel: stackTravel,
          layer: 1,
        );
        canvas.drawLine(const Offset(160, 250), const Offset(160, floorY), Paint()..color = kSteelDark..strokeWidth = 8);
      }

      if (layer == 0 || layer == 2) {
        // Contoured prone bench with pelvic angle
        final benchPath = Path()
          ..moveTo(135, 248)
          ..lineTo(220, 255)
          ..lineTo(290, 245)
          ..lineTo(290, 260)
          ..lineTo(220, 268)
          ..lineTo(135, 260)
          ..close();
        canvas.drawPath(benchPath, Paint()..color = const Color(0xFF1E293B));
        canvas.drawPath(
          benchPath,
          Paint()
            ..color = kAccentNeon.withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );

        // Frame posts to floor
        canvas.drawLine(const Offset(180, 260), const Offset(180, floorY), Paint()..color = kSteelFrame..strokeWidth = 10);
        canvas.drawLine(const Offset(270, 260), const Offset(270, floorY), Paint()..color = kSteelFrame..strokeWidth = 10);

        drawCableTower(
          canvas,
          towerBase: const Offset(towerX, floorY),
          pulleyPos: const Offset(365, 220),
          handlePos: kneePivot,
          stackTravel: stackTravel,
          layer: 2,
        );
      }

      if (layer == 0 || layer == 4) {
        // Knee pivot axle
        canvas.drawCircle(kneePivot, 6, Paint()..color = kSteelChrome);

        // Rigid lever arm to roller pad
        canvas.drawLine(kneePivot, anklePos, Paint()..color = kSteelBright..strokeWidth = 7..strokeCap = StrokeCap.round);

        // Foam roller locked on posterior calf / Achilles
        final armDiff = anklePos - kneePivot;
        final armDir = armDiff / (armDiff.distance > 0 ? armDiff.distance : 1);
        final armNorm = Offset(-armDir.dy, armDir.dx);
        final rollerCenter = anklePos - armNorm * 4;
        canvas.drawCircle(rollerCenter, 12, Paint()..color = const Color(0xFFDAAA5C));
        canvas.drawCircle(rollerCenter, 12, Paint()..color = const Color(0xFF645138)..style = PaintingStyle.stroke..strokeWidth = 2);
        canvas.drawCircle(rollerCenter, 4, Paint()..color = kSteelChrome);

        // Front stabilizing handles
        canvas.drawLine(const Offset(145, 245), const Offset(125, 230), Paint()..color = kSteelChrome..strokeWidth = 3.5);
        canvas.drawCircle(const Offset(125, 230), 4, Paint()..color = const Color(0xFF18181B));

        drawCableTower(
          canvas,
          towerBase: const Offset(towerX, floorY),
          pulleyPos: const Offset(365, 220),
          handlePos: kneePivot,
          stackTravel: stackTravel,
          layer: 4,
        );
      }
    } else {
      // Seated Leg Curl Machine
      if (layer == 0 || layer == 1) {
        drawCableTower(
          canvas,
          towerBase: const Offset(towerX, floorY),
          pulleyPos: const Offset(365, 240),
          handlePos: kneePivot,
          stackTravel: stackTravel,
          layer: 1,
        );
        canvas.drawLine(const Offset(215, 260), const Offset(215, floorY), Paint()..color = kSteelDark..strokeWidth = 8);
      }

      if (layer == 0 || layer == 2) {
        // Seat cushion
        final seatPad = Path()
          ..moveTo(195, 255)
          ..lineTo(kneePivot.dx, 255)
          ..lineTo(kneePivot.dx, 268)
          ..lineTo(195, 268)
          ..close();
        canvas.drawPath(seatPad, Paint()..color = const Color(0xFF1E293B));
        canvas.drawPath(
          seatPad,
          Paint()
            ..color = kAccentNeon.withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );

        // Backrest cushion
        final backPad = Path()
          ..moveTo(175, 170)
          ..lineTo(195, 255)
          ..lineTo(185, 258)
          ..lineTo(165, 173)
          ..close();
        canvas.drawPath(backPad, Paint()..color = const Color(0xFF1E293B));

        // Frame posts to floor
        canvas.drawLine(const Offset(225, 268), const Offset(225, floorY), Paint()..color = kSteelFrame..strokeWidth = 10);
        canvas.drawLine(const Offset(265, 268), const Offset(265, floorY), Paint()..color = kSteelFrame..strokeWidth = 10);

        drawCableTower(
          canvas,
          towerBase: const Offset(towerX, floorY),
          pulleyPos: const Offset(365, 240),
          handlePos: kneePivot,
          stackTravel: stackTravel,
          layer: 2,
        );
      }

      if (layer == 0 || layer == 4) {
        // Thigh hold-down roller pad (clamped directly over anterior thighs)
        const thighRoller = Offset(245, 238);
        canvas.drawCircle(thighRoller, 12, Paint()..color = const Color(0xFFDAAA5C));
        canvas.drawCircle(thighRoller, 12, Paint()..color = const Color(0xFF645138)..style = PaintingStyle.stroke..strokeWidth = 2);
        canvas.drawCircle(thighRoller, 4, Paint()..color = kSteelChrome);
        // Bracket to frame
        canvas.drawLine(thighRoller, const Offset(245, 268), Paint()..color = kSteelFrame..strokeWidth = 5);

        // Knee cam pivot axle
        canvas.drawCircle(kneePivot, 6, Paint()..color = kSteelChrome);

        // Rigid lever arm to lower leg roller
        canvas.drawLine(kneePivot, anklePos, Paint()..color = kSteelBright..strokeWidth = 7..strokeCap = StrokeCap.round);

        // Padded roller locked behind Achilles tendon
        final armDiff = anklePos - kneePivot;
        final armDir = armDiff / (armDiff.distance > 0 ? armDiff.distance : 1);
        final armNorm = Offset(-armDir.dy, armDir.dx);
        final rollerCenter = anklePos - armNorm * 4;
        canvas.drawCircle(rollerCenter, 12, Paint()..color = const Color(0xFFDAAA5C));
        canvas.drawCircle(rollerCenter, 12, Paint()..color = const Color(0xFF645138)..style = PaintingStyle.stroke..strokeWidth = 2);
        canvas.drawCircle(rollerCenter, 4, Paint()..color = kSteelChrome);

        // Side handles
        canvas.drawLine(const Offset(215, 260), const Offset(230, 240), Paint()..color = kSteelChrome..strokeWidth = 3.5);
        canvas.drawCircle(const Offset(230, 240), 4, Paint()..color = const Color(0xFF18181B));

        drawCableTower(
          canvas,
          towerBase: const Offset(towerX, floorY),
          pulleyPos: const Offset(365, 240),
          handlePos: kneePivot,
          stackTravel: stackTravel,
          layer: 4,
        );
      }
    }
  }

  // ===========================================================================
  // 6. BIOMECHANICAL MOTION GUIDES & PHASE DIRECTION ARROWS
  // ===========================================================================

  /// Dashed trajectory curve showing the bar or limb path
  static void drawMotionArc(
    Canvas canvas, {
    required List<Offset> points,
    Color color = kAccentCyan,
  }) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final paint = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw dashed path
    final dashPath = Path();
    double distance = 0;
    for (final metric in path.computeMetrics()) {
      while (distance < metric.length) {
        final len = math.min(6.0, metric.length - distance);
        dashPath.addPath(
          metric.extractPath(distance, distance + len),
          Offset.zero,
        );
        distance += 11.0;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  /// Directional movement arrow indicating concentric vs eccentric drive
  static void drawPhaseArrow(
    Canvas canvas, {
    required Offset start,
    required Offset end,
    required bool isConcentric,
    double progress = 0.5,
  }) {
    final diff = end - start;
    final len = diff.distance;
    if (len < 5) return;
    final dir = diff / len;
    final norm = Offset(-dir.dy, dir.dx);

    final pos = start + diff * progress;
    final color = isConcentric ? kAccentNeon : kAccentAmber;

    final arrowPaint = Paint()
      ..color = color
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Shaft
    canvas.drawLine(pos - dir * 14, pos + dir * 14, arrowPaint);
    // Chevrons
    final tip = pos + dir * 14;
    canvas.drawLine(tip, tip - dir * 8 + norm * 6, arrowPaint);
    canvas.drawLine(tip, tip - dir * 8 - norm * 6, arrowPaint);
  }

  /// Numbered circular callout badge with connector line
  static void drawCalloutBadge(
    Canvas canvas, {
    required String number,
    required Offset badgePos,
    required Offset targetPos,
  }) {
    // Connector line
    canvas.drawLine(
      badgePos,
      targetPos,
      Paint()
        ..color = const Color(0xFF64748B)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
    // Pin at target
    canvas.drawCircle(
      targetPos,
      3.0,
      Paint()..color = kAccentAmber,
    );

    // Callout circle
    canvas.drawCircle(
      badgePos,
      12.0,
      Paint()..color = kAccentAmber,
    );
    canvas.drawCircle(
      badgePos,
      12.0,
      Paint()
        ..color = const Color(0xFF0B0F14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Digit text
    final painter = TextPainter(
      text: TextSpan(
        text: number,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: Color(0xFF0B0F14),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, badgePos - Offset(painter.width / 2, painter.height / 2));
  }
}

