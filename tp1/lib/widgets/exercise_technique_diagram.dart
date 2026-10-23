import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/exercise.dart';
import 'drawing/anatomical_athlete_renderer.dart';

/// Articulated 2D Anatomical Exercise Technique Diagram.
/// Provides biomechanically accurate animations for all 22 movement patterns
/// and equipment variants across the Lifting Life catalog.
class ExerciseTechniqueDiagram extends StatefulWidget {
  final Exercise exercise;
  final bool compactMode;
  final double? canvasHeight;
  final Widget? equipmentSection;

  const ExerciseTechniqueDiagram({
    super.key,
    required this.exercise,
    this.compactMode = false,
    this.canvasHeight,
    this.equipmentSection,
  });

  @override
  State<ExerciseTechniqueDiagram> createState() =>
      _ExerciseTechniqueDiagramState();
}

class _ExerciseTechniqueDiagramState extends State<ExerciseTechniqueDiagram>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  final _viewportKey = GlobalKey();
  bool _labels = true;
  bool _highlightMuscles = true;
  bool _reducedMotion = false;
  bool _tickerEnabled = true;
  double _speed = 1.0;
  static const int _baseCycleMs = 3600;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _baseCycleMs),
    );
    _controller.addListener(_checkVisibility);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    if (_reducedMotion || !_tickerEnabled) {
      _pause();
    }
  }

  bool _isVisible() {
    final target = _viewportKey.currentContext?.findRenderObject();
    if (target is! RenderBox || !target.attached || !target.hasSize) {
      return false;
    }
    Rect visible = Offset.zero & MediaQuery.sizeOf(context);
    _viewportKey.currentContext!.visitAncestorElements((element) {
      if (element is RenderObjectElement) {
        final render = element.renderObject;
        if (render is RenderAbstractViewport && render is RenderBox) {
          final box = render as RenderBox;
          if (box.attached && box.hasSize) {
            visible = visible.intersect(
              box.localToGlobal(Offset.zero) & box.size,
            );
          }
        }
      }
      return true;
    });
    final bounds = target.localToGlobal(Offset.zero) & target.size;
    return !visible.isEmpty && visible.overlaps(bounds);
  }

  void _checkVisibility() {
    if (_controller.isAnimating && !_isVisible()) {
      _pause();
    }
  }

  void _pause() {
    _controller.stop();
    if (mounted) setState(() {});
  }

  void _play() {
    if (_reducedMotion || !_tickerEnabled || !_isVisible()) return;
    _controller.duration = Duration(
      milliseconds: (_baseCycleMs / _speed).round(),
    );
    _controller.repeat();
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_checkVisibility);
    _controller.dispose();
    super.dispose();
  }

  String _getPhaseCue(double phase) {
    if (phase < 0.05 || phase > 0.95) {
      return 'Set position · Core braced & joints stacked';
    } else if (phase < 0.45) {
      return 'Eccentric phase · Lower with control under tension';
    } else if (phase <= 0.55) {
      return 'Turnaround · Deep loaded stretch without bouncing';
    } else {
      return 'Concentric drive · Drive upward powerfully';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF171C24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF34404F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ANIMATED TECHNIQUE DIAGRAM',
                  style: TextStyle(
                    color: Color(0xFFB8FF3B),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0F14),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF455365)),
                ),
                child: Text(
                  ex.equipment,
                  style: const TextStyle(
                    color: Color(0xFFDFE6EF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ex.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '${ex.category} · ${ex.difficulty} · 2D Biomechanical Rig',
            style: const TextStyle(color: Color(0xFFBFCADA), fontSize: 13),
          ),
          const SizedBox(height: 12),
          RepaintBoundary(
            key: _viewportKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = widget.canvasHeight ??
                    (widget.compactMode
                        ? 160.0
                        : math.min(constraints.maxWidth * 370 / 560, 200.0));
                return SizedBox(
                  height: h,
                  width: double.infinity,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (_, child) => CustomPaint(
                      key: ValueKey('technique-paint-${ex.id}'),
                      painter: TechniqueDiagramPainter(
                        exercise: ex,
                        phase: _controller.value,
                        showLabels: _labels,
                        highlightMuscles: _highlightMuscles,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Column(
              children: [
                Text(
                  _getPhaseCue(_controller.value),
                  style: const TextStyle(
                    color: Color(0xFFB8FF3B),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                Slider(
                  key: ValueKey('technique-timeline-${ex.id}'),
                  label: '${(_controller.value * 100).round()}% of repetition',
                  value: _controller.value,
                  activeColor: const Color(0xFFB8FF3B),
                  inactiveColor: const Color(0xFF34404F),
                  onChanged: (value) {
                    _pause();
                    _controller.value = value;
                  },
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB8FF3B),
                  foregroundColor: const Color(0xFF0B0F14),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(60, 32),
                ),
                onPressed: _reducedMotion
                    ? null
                    : (_controller.isAnimating ? _pause : _play),
                icon: Icon(
                  _controller.isAnimating ? Icons.pause : Icons.play_arrow,
                  size: 16,
                ),
                label: Text(
                  _controller.isAnimating ? 'Pause' : 'Play',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  minimumSize: const Size(50, 32),
                ),
                onPressed: () {
                  _pause();
                  _controller.value = 0;
                },
                child: const Text('Restart', style: TextStyle(fontSize: 12)),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  minimumSize: const Size(50, 32),
                ),
                onPressed: () {
                  final playing = _controller.isAnimating;
                  setState(() => _speed = _speed == 1.0 ? 0.5 : 1.0);
                  if (playing) _play();
                },
                child: Text(
                  _speed == 1.0 ? 'Speed: 1×' : 'Speed: 0.5×',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  minimumSize: const Size(50, 32),
                ),
                onPressed: () => setState(() => _labels = !_labels),
                child: Text(
                  _labels ? 'Hide labels' : 'Show labels',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  minimumSize: const Size(50, 32),
                ),
                onPressed: () =>
                    setState(() => _highlightMuscles = !_highlightMuscles),
                child: Text(
                  _highlightMuscles ? 'Muscles: ON' : 'Muscles: OFF',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          if (widget.equipmentSection != null) ...[
            const SizedBox(height: 12),
            widget.equipmentSection!,
          ],
          if (_reducedMotion)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Reduced motion is enabled. Drag the timeline slider to inspect positions frame by frame.',
                style: TextStyle(color: Color(0xFFBFCADA), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

/// Custom painter resolving 2D kinematics for all 22 movement patterns.
class TechniqueDiagramPainter extends CustomPainter {
  final Exercise exercise;
  final double phase;
  final bool showLabels;
  final bool highlightMuscles;

  TechniqueDiagramPainter({
    required this.exercise,
    required this.phase,
    required this.showLabels,
    required this.highlightMuscles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double cw = 560;
    const double ch = 370;
    final scale = math.min(size.width / cw, size.height / ch);

    canvas.save();
    canvas.translate(
      (size.width - cw * scale) / 2,
      (size.height - ch * scale) / 2,
    );
    canvas.scale(scale);

    // Dark viewport background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, cw, ch),
        const Radius.circular(16),
      ),
      Paint()..color = const Color(0xFF0B0F14),
    );

    // Ground plane
    canvas.drawLine(
      const Offset(40, 345),
      const Offset(520, 345),
      Paint()
        ..color = const Color(0xFF34404F)
        ..strokeWidth = 2.5,
    );

    // Smooth turnaround easing (0 -> 1 -> 0)
    final double t = (1 - math.cos(phase * 2 * math.pi)) / 2;
    final bool isConcentric = phase > 0.5;

    final pattern = exercise.movementPattern.toLowerCase();
    final eq = exercise.equipment;

    switch (pattern) {
      case 'bench':
        _paintBench(canvas, t, isConcentric, eq);
        break;
      case 'squat':
        _paintSquat(canvas, t, isConcentric, eq);
        break;
      case 'deadlift':
        _paintDeadlift(canvas, t, isConcentric, eq);
        break;
      case 'hinge':
        _paintHinge(canvas, t, isConcentric, eq);
        break;
      case 'overhead_press':
        _paintOverheadPress(canvas, t, isConcentric, eq);
        break;
      case 'lunge':
        _paintLunge(canvas, t, isConcentric, eq);
        break;
      case 'pulldown':
        _paintPulldown(canvas, t, isConcentric, eq);
        break;
      case 'pullup':
        _paintPullup(canvas, t, isConcentric, eq);
        break;
      case 'row':
        _paintRow(canvas, t, isConcentric, eq);
        break;
      case 'curl':
        _paintCurl(canvas, t, isConcentric, eq);
        break;
      case 'pushdown':
        _paintPushdown(canvas, t, isConcentric, eq);
        break;
      case 'dip':
        _paintDip(canvas, t, isConcentric, eq);
        break;
      case 'lateral_raise':
        _paintLateralRaise(canvas, t, isConcentric, eq);
        break;
      case 'fly':
        _paintFly(canvas, t, isConcentric, eq);
        break;
      case 'leg_press':
        _paintLegPress(canvas, t, isConcentric, eq);
        break;
      case 'leg_extension':
        _paintLegExtension(canvas, t, isConcentric, eq);
        break;
      case 'leg_curl_seated':
      case 'leg_curl_prone':
      case 'leg_curl_standing':
      case 'leg_curl_band':
        _paintLegCurl(canvas, t, isConcentric, eq, pattern);
        break;
      case 'calf_raise':
        _paintCalfRaise(canvas, t, isConcentric, eq);
        break;
      case 'crunch':
        _paintCrunch(canvas, t, isConcentric, eq);
        break;
      case 'back_extension':
      case 'roman_chair':
        _paintBackExtension(canvas, t, isConcentric, eq);
        break;
      default:
        _paintSquat(canvas, t, isConcentric, eq);
        break;
    }

    canvas.restore();
  }

  // ===========================================================================
  // 1. BENCH PRESS
  // ===========================================================================
  void _paintBench(Canvas canvas, double t, bool isConcentric, String eq) {
    const headPad = Offset(140, 240);
    const hipPad = Offset(320, 240);

    const hip = Offset(310, 235);
    const shoulder = Offset(175, 230);
    const head = Offset(135, 230);

    // Arms: t=0 is lockout over shoulders, t=1 is bar touching chest
    final wrist = Offset.lerp(const Offset(175, 120), const Offset(205, 215), t)!;
    final elbow = Offset.lerp(const Offset(175, 175), const Offset(205, 250), t)!;

    // Contact: Feet flat on floor (floorY = 345). sole bottom is ankle.y + 8, so ankle.y = 337
    const farAnkle = Offset(384, 331);
    const farToe = Offset(409, 331);
    const nearAnkle = Offset(390, 337);
    const nearToe = Offset(415, 337);

    // LAYER 1: Far background (bench frame, far barbell plate, far leg)
    AnatomicalAthleteRenderer.drawBench(canvas, headPos: headPad, hipPos: hipPad, layer: 1);
    if (eq == 'Barbell') {
      canvas.drawLine(const Offset(155, 110), const Offset(155, 240), Paint()..color = const Color(0xFF37474F)..strokeWidth = 8);
      AnatomicalAthleteRenderer.drawBarbell(canvas, center: wrist, plateRadius: 36, barLength: 160, layer: 1);
    } else {
      AnatomicalAthleteRenderer.drawDumbbell(canvas, center: wrist, angle: 0, length: 34, layer: 1);
    }
    AnatomicalAthleteRenderer.drawLeg(
      canvas,
      hip: hip + const Offset(-6, -6),
      knee: const Offset(365, 250) + const Offset(-6, -6),
      ankle: farAnkle,
      toe: farToe,
      isFar: true,
    );

    // LAYER 2: Support surface & core (bench cushion, torso, head, bar shaft)
    AnatomicalAthleteRenderer.drawBench(canvas, headPos: headPad, hipPos: hipPad, layer: 2);
    if (eq == 'Barbell') {
      AnatomicalAthleteRenderer.drawBarbell(canvas, center: wrist, plateRadius: 36, barLength: 160, layer: 2);
    } else {
      AnatomicalAthleteRenderer.drawDumbbell(canvas, center: wrist, angle: 0, length: 34, layer: 2);
    }
    AnatomicalAthleteRenderer.drawTorso(
      canvas,
      hip: hip,
      shoulder: shoulder,
      highlightChest: highlightMuscles,
    );
    AnatomicalAthleteRenderer.drawHead(
      canvas,
      center: head,
      angle: -math.pi / 2,
      facingRight: true,
    );

    // LAYER 3: Near athlete limbs
    AnatomicalAthleteRenderer.drawLeg(
      canvas,
      hip: hip,
      knee: const Offset(365, 250),
      ankle: nearAnkle,
      toe: nearToe,
      isFar: false,
    );
    AnatomicalAthleteRenderer.drawArm(
      canvas,
      shoulder: shoulder,
      elbow: elbow,
      wrist: wrist,
      isFar: false,
      highlightTriceps: highlightMuscles && t < 0.4,
      highlightDeltoid: highlightMuscles,
    );

    // LAYER 4: Foreground hardware & hand wrap
    if (eq == 'Barbell') {
      AnatomicalAthleteRenderer.drawHandWrap(canvas, handCenter: wrist);
      AnatomicalAthleteRenderer.drawBarbell(canvas, center: wrist, plateRadius: 36, barLength: 160, layer: 4);
    } else {
      AnatomicalAthleteRenderer.drawHandWrap(canvas, handCenter: wrist);
      AnatomicalAthleteRenderer.drawDumbbell(canvas, center: wrist, angle: 0, length: 34, layer: 4);
    }

    // Motion Arc & Arrow
    final arc = [const Offset(175, 120), const Offset(190, 168), const Offset(205, 215)];
    AnatomicalAthleteRenderer.drawMotionArc(canvas, points: arc);
    AnatomicalAthleteRenderer.drawPhaseArrow(
      canvas,
      start: isConcentric ? const Offset(205, 215) : const Offset(175, 120),
      end: isConcentric ? const Offset(175, 120) : const Offset(205, 215),
      isConcentric: isConcentric,
    );

    if (showLabels) {
      AnatomicalAthleteRenderer.drawCalloutBadge(canvas, number: '1', badgePos: const Offset(210, 75), targetPos: wrist);
      AnatomicalAthleteRenderer.drawCalloutBadge(canvas, number: '2', badgePos: const Offset(250, 205), targetPos: shoulder);
      AnatomicalAthleteRenderer.drawCalloutBadge(canvas, number: '3', badgePos: const Offset(435, 305), targetPos: nearAnkle);
    }
  }

  // ===========================================================================
  // 2. SQUAT
  // ===========================================================================
  void _paintSquat(Canvas canvas, double t, bool isConcentric, String eq) {
    // Kinematics: Standing erect (t=0) vs Deep Parallel Squat (t=1)
    const ankle = Offset(270, 337);
    const toe = Offset(298, 337);
    final knee = Offset.lerp(const Offset(270, 250), const Offset(315, 255), t)!;
    final hip = Offset.lerp(const Offset(268, 165), const Offset(210, 250), t)!;
    final shoulder = Offset.lerp(const Offset(270, 85), const Offset(262, 175), t)!;
    final head = Offset.lerp(const Offset(270, 52), const Offset(262, 142), t)!;
    final bar = Offset.lerp(const Offset(266, 82), const Offset(262, 172), t)!;
    final elbow = Offset.lerp(const Offset(255, 110), const Offset(250, 195), t)!;

    const far = Offset(-8, -4);

    // LAYER 1: Far rack upright, far plates, far leg
    if (eq == 'Barbell') {
      AnatomicalAthleteRenderer.drawSquatRack(canvas, rackX: 280, floorY: 345, layer: 1);
      AnatomicalAthleteRenderer.drawBarbell(canvas, center: bar, plateRadius: 36, barLength: 160, layer: 1);
    }
    AnatomicalAthleteRenderer.drawLeg(
      canvas,
      hip: hip + far,
      knee: knee + far,
      ankle: ankle + far,
      toe: toe + far,
      isFar: true,
      highlightQuads: highlightMuscles,
    );

    // LAYER 2: Rack frame, bar shaft on traps, torso, head
    if (eq == 'Barbell') {
      AnatomicalAthleteRenderer.drawSquatRack(canvas, rackX: 280, floorY: 345, layer: 2);
      AnatomicalAthleteRenderer.drawBarbell(canvas, center: bar, plateRadius: 36, barLength: 160, layer: 2);
    }
    AnatomicalAthleteRenderer.drawTorso(
      canvas,
      hip: hip,
      shoulder: shoulder,
      highlightGlutes: highlightMuscles,
      highlightBack: highlightMuscles,
    );
    AnatomicalAthleteRenderer.drawHead(
      canvas,
      center: head,
      angle: 0.15 * t,
      facingRight: true,
    );

    // LAYER 3: Near athlete limbs
    AnatomicalAthleteRenderer.drawLeg(
      canvas,
      hip: hip,
      knee: knee,
      ankle: ankle,
      toe: toe,
      isFar: false,
      highlightQuads: highlightMuscles,
      highlightCalf: highlightMuscles,
    );
    AnatomicalAthleteRenderer.drawArm(
      canvas,
      shoulder: shoulder,
      elbow: elbow,
      wrist: bar,
      isFar: false,
    );

    // LAYER 4: Foreground hardware & hand wrap
    if (eq == 'Barbell') {
      AnatomicalAthleteRenderer.drawHandWrap(canvas, handCenter: bar);
      AnatomicalAthleteRenderer.drawBarbell(canvas, center: bar, plateRadius: 36, barLength: 160, layer: 4);
      AnatomicalAthleteRenderer.drawSquatRack(canvas, rackX: 280, floorY: 345, layer: 4);
    } else if (eq == 'Dumbbell') {
      AnatomicalAthleteRenderer.drawHandWrap(canvas, handCenter: bar);
      AnatomicalAthleteRenderer.drawDumbbell(canvas, center: bar, angle: 0, layer: 4);
    }

    final arc = [const Offset(266, 82), const Offset(264, 127), const Offset(262, 172)];
    AnatomicalAthleteRenderer.drawMotionArc(canvas, points: arc);
    AnatomicalAthleteRenderer.drawPhaseArrow(
      canvas,
      start: isConcentric ? const Offset(262, 172) : const Offset(266, 82),
      end: isConcentric ? const Offset(266, 82) : const Offset(262, 172),
      isConcentric: isConcentric,
    );

    if (showLabels) {
      AnatomicalAthleteRenderer.drawCalloutBadge(canvas, number: '1', badgePos: const Offset(340, 75), targetPos: bar);
      AnatomicalAthleteRenderer.drawCalloutBadge(canvas, number: '2', badgePos: const Offset(365, 230), targetPos: knee);
      AnatomicalAthleteRenderer.drawCalloutBadge(canvas, number: '3', badgePos: const Offset(155, 235), targetPos: hip);
    }
  }

  // ===========================================================================
  // 3. DEADLIFT
  // ===========================================================================
  void _paintDeadlift(Canvas canvas, double t, bool isConcentric, String eq) {
    // Floor-start (t=1) vs Erect Lockout (t=0)
    const ankle = Offset(270, 337);
    const toe = Offset(298, 337);
    final knee = Offset.lerp(const Offset(270, 250), const Offset(295, 265), t)!;
    final hip = Offset.lerp(const Offset(270, 165), const Offset(220, 210), t)!;
    final shoulder = Offset.lerp(const Offset(270, 85), const Offset(290, 125), t)!;
    final head = Offset.lerp(const Offset(270, 52), const Offset(305, 95), t)!;
    final bar = Offset.lerp(const Offset(288, 175), const Offset(290, 309), t)!;
    final elbow = Offset.lerp(const Offset(279, 130), const Offset(290, 217), t)!;

    const far = Offset(-8, -4);

    // LAYER 1: Far plate & far leg
    AnatomicalAthleteRenderer.drawBarbell(canvas, center: bar, plateRadius: 36, barLength: 160, layer: 1);
    AnatomicalAthleteRenderer.drawLeg(
      canvas,
      hip: hip + far,
      knee: knee + far,
      ankle: ankle + far,
      toe: toe + far,
      isFar: true,
      highlightHamstrings: highlightMuscles,
    );

    // LAYER 2: Bar shaft, torso, head
    AnatomicalAthleteRenderer.drawBarbell(canvas, center: bar, plateRadius: 36, barLength: 160, layer: 2);
    AnatomicalAthleteRenderer.drawTorso(
      canvas,
      hip: hip,
      shoulder: shoulder,
      highlightBack: highlightMuscles,
      highlightGlutes: highlightMuscles,
    );
    AnatomicalAthleteRenderer.drawHead(
      canvas,
      center: head,
      angle: 0.25 * t,
      facingRight: true,
    );

    // LAYER 3: Near leg & near arm
    AnatomicalAthleteRenderer.drawLeg(
      canvas,
      hip: hip,
      knee: knee,
      ankle: ankle,
      toe: toe,
      isFar: false,
      highlightHamstrings: highlightMuscles,
      highlightQuads: highlightMuscles && t > 0.4,
    );
    AnatomicalAthleteRenderer.drawArm(
      canvas,
      shoulder: shoulder,
      elbow: elbow,
      wrist: bar,
      isFar: false,
      highlightForearm: highlightMuscles,
    );

    // LAYER 4: Hand wrap & near barbell plate
    AnatomicalAthleteRenderer.drawHandWrap(canvas, handCenter: bar);
    AnatomicalAthleteRenderer.drawBarbell(canvas, center: bar, plateRadius: 36, barLength: 160, layer: 4);

    final arc = [const Offset(288, 175), const Offset(289, 242), const Offset(290, 309)];
    AnatomicalAthleteRenderer.drawMotionArc(canvas, points: arc);
    AnatomicalAthleteRenderer.drawPhaseArrow(
      canvas,
      start: isConcentric ? const Offset(290, 309) : const Offset(288, 175),
      end: isConcentric ? const Offset(288, 175) : const Offset(290, 309),
      isConcentric: isConcentric,
    );

    if (showLabels) {
      AnatomicalAthleteRenderer.drawCalloutBadge(canvas, number: '1', badgePos: const Offset(360, 290), targetPos: bar);
      AnatomicalAthleteRenderer.drawCalloutBadge(canvas, number: '2', badgePos: const Offset(165, 195), targetPos: hip);
      AnatomicalAthleteRenderer.drawCalloutBadge(canvas, number: '3', badgePos: const Offset(245, 105), targetPos: shoulder);
    }
  }

  // ===========================================================================
  // 4. HINGE (RDL / Good Morning)
  // ===========================================================================
  void _paintHinge(Canvas canvas, double t, bool isConcentric, String eq) {
    const ankle = Offset(270, 337);
    const toe = Offset(298, 337);
    final knee = Offset.lerp(const Offset(270, 250), const Offset(265, 255), t)!;
    final hip = Offset.lerp(const Offset(270, 165), const Offset(215, 195), t)!;
    final shoulder = Offset.lerp(const Offset(270, 85), const Offset(300, 190), t)!;
    final head = Offset.lerp(const Offset(270, 52), const Offset(325, 165), t)!;
    final bar = Offset.lerp(const Offset(285, 175), const Offset(295, 260), t)!;
    final elbow = Offset.lerp(const Offset(278, 130), const Offset(298, 225), t)!;

    const far = Offset(-8, -4);

    // LAYER 1: Far plate & far leg
    if (eq == 'Barbell') {
      AnatomicalAthleteRenderer.drawBarbell(canvas, center: bar, plateRadius: 36, barLength: 160, layer: 1);
    } else {
      AnatomicalAthleteRenderer.drawDumbbell(canvas, center: bar, angle: 0, layer: 1);
    }
    AnatomicalAthleteRenderer.drawLeg(
      canvas,
      hip: hip + far,
      knee: knee + far,
      ankle: ankle + far,
      toe: toe + far,
      isFar: true,
      highlightHamstrings: highlightMuscles,
    );

    // LAYER 2: Bar shaft, torso, head
    if (eq == 'Barbell') {
      AnatomicalAthleteRenderer.drawBarbell(canvas, center: bar, plateRadius: 36, barLength: 160, layer: 2);
    } else {
      AnatomicalAthleteRenderer.drawDumbbell(canvas, center: bar, angle: 0, layer: 2);
    }
    AnatomicalAthleteRenderer.drawTorso(
      canvas,
      hip: hip,
      shoulder: shoulder,
      highlightGlutes: highlightMuscles,
      highlightBack: highlightMuscles,
    );
    AnatomicalAthleteRenderer.drawHead(
      canvas,
      center: head,
      angle: 0.3 * t,
      facingRight: true,
    );

    // LAYER 3: Near leg & arm
    AnatomicalAthleteRenderer.drawLeg(
      canvas,
      hip: hip,
      knee: knee,
      ankle: ankle,
      toe: toe,
      isFar: false,
      highlightHamstrings: highlightMuscles,
    );
    AnatomicalAthleteRenderer.drawArm(
      canvas,
      shoulder: shoulder,
      elbow: elbow,
      wrist: bar,
      isFar: false,
    );

    // LAYER 4: Hand wrap & near plate
    AnatomicalAthleteRenderer.drawHandWrap(canvas, handCenter: bar);
    if (eq == 'Barbell') {
      AnatomicalAthleteRenderer.drawBarbell(canvas, center: bar, plateRadius: 36, barLength: 160, layer: 4);
    } else {
      AnatomicalAthleteRenderer.drawDumbbell(canvas, center: bar, angle: 0, layer: 4);
    }

    final arc = [const Offset(285, 175), const Offset(290, 218), const Offset(295, 260)];
    AnatomicalAthleteRenderer.drawMotionArc(canvas, points: arc);
    AnatomicalAthleteRenderer.drawPhaseArrow(
      canvas,
      start: isConcentric ? const Offset(295, 260) : const Offset(285, 175),
      end: isConcentric ? const Offset(285, 175) : const Offset(295, 260),
      isConcentric: isConcentric,
    );

    if (showLabels) {
      AnatomicalAthleteRenderer.drawCalloutBadge(canvas, number: '1', badgePos: const Offset(365, 240), targetPos: bar);
      AnatomicalAthleteRenderer.drawCalloutBadge(canvas, number: '2', badgePos: const Offset(160, 185), targetPos: hip);
    }
  }

  // ===========================================================================
  // 5. OVERHEAD PRESS
  // ===========================================================================
  void _paintOverheadPress(Canvas canvas, double t, bool isConcentric, String eq) {
    const ankle = Offset(270, 337);
    const toe = Offset(298, 337);
    const knee = Offset(270, 250);
    const hip = Offset(270, 165);
    const shoulder = Offset(270, 85);
    const head = Offset(270, 52);

    final bar = Offset.lerp(const Offset(270, 15), const Offset(285, 90), t)!;
    final elbow = Offset.lerp(const Offset(270, 50), const Offset(285, 145), t)!;

    const far = Offset(-8, -4);

    // LAYER 1: Far plate & far leg
    if (eq == 'Barbell') {
      AnatomicalAthleteRenderer.drawBarbell(canvas, center: bar, plateRadius: 36, barLength: 160, layer: 1);
    } else {
      AnatomicalAthleteRenderer.drawDumbbell(canvas, center: bar, angle: 0, layer: 1);
    }
    AnatomicalAthleteRenderer.drawLeg(canvas, hip: hip + far, knee: knee + far, ankle: ankle + far, toe: toe + far, isFar: true);

    // LAYER 2: Bar shaft, torso, head
    if (eq == 'Barbell') {
      AnatomicalAthleteRenderer.drawBarbell(canvas, center: bar, plateRadius: 36, barLength: 160, layer: 2);
    } else {
      AnatomicalAthleteRenderer.drawDumbbell(canvas, center: bar, angle: 0, layer: 2);
    }
    AnatomicalAthleteRenderer.drawTorso(
      canvas,
      hip: hip,
      shoulder: shoulder,
      highlightAbs: highlightMuscles,
    );
    AnatomicalAthleteRenderer.drawHead(canvas, center: head, angle: 0, facingRight: true);

    // LAYER 3: Near leg & near arm
    AnatomicalAthleteRenderer.drawLeg(canvas, hip: hip, knee: knee, ankle: ankle, toe: toe, isFar: false);
    AnatomicalAthleteRenderer.drawArm(
      canvas,
      shoulder: shoulder,
      elbow: elbow,
      wrist: bar,
      isFar: false,
      highlightDeltoid: highlightMuscles,
      highlightTriceps: highlightMuscles && t < 0.5,
    );

    // LAYER 4: Hand wrap & near plate
    AnatomicalAthleteRenderer.drawHandWrap(canvas, handCenter: bar);
    if (eq == 'Barbell') {
      AnatomicalAthleteRenderer.drawBarbell(canvas, center: bar, plateRadius: 36, barLength: 160, layer: 4);
    } else {
      AnatomicalAthleteRenderer.drawDumbbell(canvas, center: bar, angle: 0, layer: 4);
    }

    final arc = [const Offset(270, 15), const Offset(278, 52), const Offset(285, 90)];
    AnatomicalAthleteRenderer.drawMotionArc(canvas, points: arc);
    AnatomicalAthleteRenderer.drawPhaseArrow(
      canvas,
      start: isConcentric ? const Offset(285, 90) : const Offset(270, 15),
      end: isConcentric ? const Offset(270, 15) : const Offset(285, 90),
      isConcentric: isConcentric,
    );

    if (showLabels) {
      AnatomicalAthleteRenderer.drawCalloutBadge(canvas, number: '1', badgePos: const Offset(345, 30), targetPos: bar);
      AnatomicalAthleteRenderer.drawCalloutBadge(canvas, number: '2', badgePos: const Offset(335, 95), targetPos: shoulder);
    }
  }

  // ===========================================================================
  // 6. LUNGE
  // ===========================================================================
  void _paintLunge(Canvas canvas, double t, bool isConcentric, String eq) {
    // Standing erect (t=0) vs Split lunge (t=1)
    final frontKnee = Offset.lerp(const Offset(270, 250), const Offset(340, 255), t)!;
    final frontAnkle = Offset.lerp(const Offset(270, 337), const Offset(340, 337), t)!;
    final frontToe = frontAnkle + const Offset(26, 0);

    final backKnee = Offset.lerp(const Offset(270, 250), const Offset(210, 315), t)!;
    final backAnkle = Offset.lerp(const Offset(270, 337), const Offset(180, 332), t)!;
    final backToe = backAnkle + const Offset(15, 5);

    final hip = Offset.lerp(const Offset(270, 165), const Offset(270, 235), t)!;
    final shoulder = Offset.lerp(const Offset(270, 85), const Offset(270, 155), t)!;
    final head = Offset.lerp(const Offset(270, 52), const Offset(270, 122), t)!;
    final hand = shoulder + const Offset(5, 75);

    // LAYER 1: Far leg & far plate
    if (eq == 'Barbell') {
      AnatomicalAthleteRenderer.drawBarbell(canvas, center: shoulder + const Offset(-4, -3), plateRadius: 36, layer: 1);
    } else if (eq == 'Dumbbell') {
      AnatomicalAthleteRenderer.drawDumbbell(canvas, center: hand, angle: math.pi / 2, layer: 1);
    }
    AnatomicalAthleteRenderer.drawLeg(
      canvas,
      hip: hip,
      knee: backKnee,
      ankle: backAnkle,
      toe: backToe,
      isFar: true,
      highlightQuads: highlightMuscles,
    );

    // LAYER 2: Torso, head, barbell shaft
    if (eq == 'Barbell') {
      AnatomicalAthleteRenderer.drawBarbell(canvas, center: shoulder + const Offset(-4, -3), plateRadius: 36, layer: 2);
    } else if (eq == 'Dumbbell') {
      AnatomicalAthleteRenderer.drawDumbbell(canvas, center: hand, angle: math.pi / 2, layer: 2);
    }
    AnatomicalAthleteRenderer.drawTorso(
      canvas,
      hip: hip,
      shoulder: shoulder,
      highlightGlutes: highlightMuscles,
    );
    AnatomicalAthleteRenderer.drawHead(canvas, center: head, angle: 0, facingRight: true);

    // LAYER 3: Near leg & arm
    AnatomicalAthleteRenderer.drawLeg(
      canvas,
      hip: hip,
      knee: frontKnee,
      ankle: frontAnkle,
      toe: frontToe,
      isFar: false,
      highlightQuads: highlightMuscles,
    );
    AnatomicalAthleteRenderer.drawArm(
      canvas,
      shoulder: shoulder,
      elbow: shoulder + const Offset(3, 40),
      wrist: hand,
      isFar: false,
    );

    // LAYER 4: Hand wrap & near plate
    AnatomicalAthleteRenderer.drawHandWrap(canvas, handCenter: hand, isVertical: true);
    if (eq == 'Dumbbell') {
      AnatomicalAthleteRenderer.drawDumbbell(canvas, center: hand, angle: math.pi / 2, layer: 4);
    } else if (eq == 'Barbell') {
      AnatomicalAthleteRenderer.drawBarbell(canvas, center: shoulder + const Offset(-4, -3), plateRadius: 36, layer: 4);
    }

    AnatomicalAthleteRenderer.drawPhaseArrow(
      canvas,
      start: isConcentric ? const Offset(270, 235) : const Offset(270, 165),
      end: isConcentric ? const Offset(270, 165) : const Offset(270, 235),
      isConcentric: isConcentric,
    );
  }

  // ===========================================================================
  // 7. PULLDOWN
  // ===========================================================================
  void _paintPulldown(Canvas canvas, double t, bool isConcentric, String eq) {
    const towerBase = Offset(430, 345);
    const pulley = Offset(310, 35);
    final bar = Offset.lerp(const Offset(310, 55), const Offset(280, 155), t)!;

    const hip = Offset(245, 252);
    const knee = Offset(310, 235);
    const ankle = Offset(310, 337);
    const toe = Offset(335, 337);

    final shoulder = Offset.lerp(const Offset(235, 145), const Offset(230, 155), t)!;
    final head = Offset.lerp(const Offset(230, 112), const Offset(225, 122), t)!;
    final elbow = Offset.lerp(const Offset(270, 95), const Offset(225, 200), t)!;

    const rollerPos = Offset(305, 222);

    // LAYER 1: Far tower frame & resting plates, far seat post, far thigh roller, far leg
    AnatomicalAthleteRenderer.drawCableTower(
      canvas,
      towerBase: towerBase,
      pulleyPos: pulley,
      handlePos: bar,
      stackTravel: t,
      layer: 1,
    );
    canvas.drawLine(const Offset(250, 260), const Offset(250, 345), Paint()..color = const Color(0xFF37474F)..strokeWidth = 8);
    canvas.drawCircle(rollerPos + const Offset(-6, -4), 12, Paint()..color = const Color(0xFF645138));
    AnatomicalAthleteRenderer.drawLeg(
      canvas,
      hip: hip + const Offset(-6, -4),
      knee: knee + const Offset(-6, -4),
      ankle: ankle + const Offset(-6, -4),
      toe: toe + const Offset(-6, -4),
      isFar: true,
    );

    // LAYER 2: Moving weight plates, cable, seat cushion, torso, head, lat bar shaft
    AnatomicalAthleteRenderer.drawCableTower(
      canvas,
      towerBase: towerBase,
      pulleyPos: pulley,
      handlePos: bar,
      stackTravel: t,
      layer: 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(215, 255, 68, 12), const Radius.circular(3)),
      Paint()..color = const Color(0xFF1E293B),
    );
    AnatomicalAthleteRenderer.drawTorso(
      canvas,
      hip: hip,
      shoulder: shoulder,
      highlightBack: highlightMuscles,
    );
    AnatomicalAthleteRenderer.drawHead(canvas, center: head, angle: 0, facingRight: true);

    // Pulldown bar shaft (chrome)
    canvas.drawLine(
      bar - const Offset(60, 0),
      bar + const Offset(60, 0),
      Paint()..color = const Color(0xFFCFD8DC)..strokeWidth = 6..strokeCap = StrokeCap.round,
    );

    // LAYER 3: Near leg tucked under roller pad, near arm
    AnatomicalAthleteRenderer.drawLeg(
      canvas,
      hip: hip,
      knee: knee,
      ankle: ankle,
      toe: toe,
      isFar: false,
    );
    AnatomicalAthleteRenderer.drawArm(
      canvas,
      shoulder: shoulder,
      elbow: elbow,
      wrist: bar,
      isFar: false,
      highlightBiceps: highlightMuscles,
    );

    // LAYER 4: Near thigh roller bracket, roller cylinder with end-cap, selector pin, hand wrap
    canvas.drawLine(const Offset(305, 260), rollerPos, Paint()..color = const Color(0xFF455A64)..strokeWidth = 8);
    canvas.drawCircle(rollerPos, 13, Paint()..color = const Color(0xFFDAAA5C));
    canvas.drawCircle(rollerPos, 4, Paint()..color = const Color(0xFFECEFF1));
    AnatomicalAthleteRenderer.drawHandWrap(canvas, handCenter: bar);
    AnatomicalAthleteRenderer.drawCableTower(
      canvas,
      towerBase: towerBase,
      pulleyPos: pulley,
      handlePos: bar,
      stackTravel: t,
      layer: 4,
    );

    final arc = [const Offset(310, 55), const Offset(295, 105), const Offset(280, 155)];
    AnatomicalAthleteRenderer.drawMotionArc(canvas, points: arc);
    AnatomicalAthleteRenderer.drawPhaseArrow(
      canvas,
      start: isConcentric ? const Offset(310, 55) : const Offset(280, 155),
      end: isConcentric ? const Offset(280, 155) : const Offset(310, 55),
      isConcentric: isConcentric,
    );
  }

  // ===========================================================================
  // 8. PULLUP
  // ===========================================================================
  void _paintPullup(Canvas canvas, double t, bool isConcentric, String eq) {
    const bar = Offset(280, 45);
    final shoulder = Offset.lerp(const Offset(280, 105), const Offset(280, 50), t)!;
    final hip = Offset.lerp(const Offset(280, 195), const Offset(280, 140), t)!;
    final knee = Offset.lerp(const Offset(275, 275), const Offset(275, 220), t)!;
    final ankle = Offset.lerp(const Offset(270, 337), const Offset(270, 285), t)!;
    final head = Offset.lerp(const Offset(280, 72), const Offset(280, 18), t)!;
    final elbow = Offset.lerp(const Offset(280, 75), const Offset(255, 100), t)!;

    // LAYER 1: Rig posts & far frame
    canvas.drawLine(const Offset(200, 45), const Offset(200, 345), Paint()..color = const Color(0xFF37474F)..strokeWidth = 10);
    canvas.drawLine(const Offset(360, 45), const Offset(360, 345), Paint()..color = const Color(0xFF37474F)..strokeWidth = 10);

    // LAYER 2: Pull-up bar shaft, athlete torso, head, hanging legs
    canvas.drawLine(const Offset(180, 45), const Offset(380, 45), Paint()..color = const Color(0xFFCFD8DC)..strokeWidth = 8..strokeCap = StrokeCap.round);
    AnatomicalAthleteRenderer.drawLeg(canvas, hip: hip, knee: knee, ankle: ankle, toe: ankle + const Offset(15, 10), isFar: false);
    AnatomicalAthleteRenderer.drawTorso(canvas, hip: hip, shoulder: shoulder, highlightBack: highlightMuscles);
    AnatomicalAthleteRenderer.drawHead(canvas, center: head, angle: 0, facingRight: true);

    // LAYER 3: Near arm grasping bar
    AnatomicalAthleteRenderer.drawArm(
      canvas,
      shoulder: shoulder,
      elbow: elbow,
      wrist: bar,
      isFar: false,
      highlightBiceps: highlightMuscles,
      highlightForearm: highlightMuscles,
    );

    // LAYER 4: Hand wrap over bar
    AnatomicalAthleteRenderer.drawHandWrap(canvas, handCenter: bar);

    AnatomicalAthleteRenderer.drawPhaseArrow(
      canvas,
      start: isConcentric ? const Offset(280, 105) : const Offset(280, 50),
      end: isConcentric ? const Offset(280, 50) : const Offset(280, 105),
      isConcentric: isConcentric,
    );
  }

  // ===========================================================================
  // 9. ROW
  // ===========================================================================
  void _paintRow(Canvas canvas, double t, bool isConcentric, String eq) {
    const ankle = Offset(270, 337);
    const toe = Offset(298, 337);
    const knee = Offset(265, 265);
    const hip = Offset(215, 205);
    const shoulder = Offset(310, 155);
    const head = Offset(335, 130);

    final bar = Offset.lerp(const Offset(310, 270), const Offset(275, 195), t)!;
    final elbow = Offset.lerp(const Offset(310, 212), const Offset(235, 145), t)!;

    const far = Offset(-8, -4);

    // LAYER 1: Far plate & far leg
    if (eq == 'Barbell') {
      AnatomicalAthleteRenderer.drawBarbell(canvas, center: bar, plateRadius: 36, barLength: 160, layer: 1);
    } else {
      AnatomicalAthleteRenderer.drawDumbbell(canvas, center: bar, angle: 0, layer: 1);
    }
    AnatomicalAthleteRenderer.drawLeg(canvas, hip: hip + far, knee: knee + far, ankle: ankle + far, toe: toe + far, isFar: true);

    // LAYER 2: Bar shaft, torso, head
    if (eq == 'Barbell') {
      AnatomicalAthleteRenderer.drawBarbell(canvas, center: bar, plateRadius: 36, barLength: 160, layer: 2);
    } else {
      AnatomicalAthleteRenderer.drawDumbbell(canvas, center: bar, angle: 0, layer: 2);
    }
    AnatomicalAthleteRenderer.drawTorso(
      canvas,
      hip: hip,
      shoulder: shoulder,
      highlightBack: highlightMuscles,
    );
    AnatomicalAthleteRenderer.drawHead(canvas, center: head, angle: 0.2, facingRight: true);

    // LAYER 3: Near leg & near arm
    AnatomicalAthleteRenderer.drawLeg(canvas, hip: hip, knee: knee, ankle: ankle, toe: toe, isFar: false);
    AnatomicalAthleteRenderer.drawArm(
      canvas,
      shoulder: shoulder,
      elbow: elbow,
      wrist: bar,
      isFar: false,
      highlightBiceps: highlightMuscles,
    );

    // LAYER 4: Hand wrap & near plate
    AnatomicalAthleteRenderer.drawHandWrap(canvas, handCenter: bar);
    if (eq == 'Barbell') {
      AnatomicalAthleteRenderer.drawBarbell(canvas, center: bar, plateRadius: 36, barLength: 160, layer: 4);
    } else {
      AnatomicalAthleteRenderer.drawDumbbell(canvas, center: bar, angle: 0, layer: 4);
    }

    final arc = [const Offset(310, 270), const Offset(292, 232), const Offset(275, 195)];
    AnatomicalAthleteRenderer.drawMotionArc(canvas, points: arc);
    AnatomicalAthleteRenderer.drawPhaseArrow(
      canvas,
      start: isConcentric ? const Offset(310, 270) : const Offset(275, 195),
      end: isConcentric ? const Offset(275, 195) : const Offset(310, 270),
      isConcentric: isConcentric,
    );
  }

  // ===========================================================================
  // 10. BICEPS CURL
  // ===========================================================================
  void _paintCurl(Canvas canvas, double t, bool isConcentric, String eq) {
    const ankle = Offset(270, 337);
    const toe = Offset(298, 337);
    const knee = Offset(270, 250);
    const hip = Offset(270, 165);
    const shoulder = Offset(270, 85);
    const head = Offset(270, 52);
    const elbow = Offset(270, 140);
    final wrist = Offset.lerp(const Offset(270, 195), const Offset(295, 95), t)!;

    const far = Offset(-8, -4);

    // LAYER 1: Far plate & far leg
    if (eq == 'Barbell') {
      AnatomicalAthleteRenderer.drawBarbell(canvas, center: wrist, plateRadius: 28, barLength: 140, layer: 1);
    } else {
      AnatomicalAthleteRenderer.drawDumbbell(canvas, center: wrist, angle: 0, layer: 1);
    }
    AnatomicalAthleteRenderer.drawLeg(canvas, hip: hip + far, knee: knee + far, ankle: ankle + far, toe: toe + far, isFar: true);

    // LAYER 2: Bar shaft, torso, head
    if (eq == 'Barbell') {
      AnatomicalAthleteRenderer.drawBarbell(canvas, center: wrist, plateRadius: 28, barLength: 140, layer: 2);
    } else {
      AnatomicalAthleteRenderer.drawDumbbell(canvas, center: wrist, angle: 0, layer: 2);
    }
    AnatomicalAthleteRenderer.drawTorso(canvas, hip: hip, shoulder: shoulder);
    AnatomicalAthleteRenderer.drawHead(canvas, center: head, angle: 0, facingRight: true);

    // LAYER 3: Near leg & near arm
    AnatomicalAthleteRenderer.drawLeg(canvas, hip: hip, knee: knee, ankle: ankle, toe: toe, isFar: false);
    AnatomicalAthleteRenderer.drawArm(
      canvas,
      shoulder: shoulder,
      elbow: elbow,
      wrist: wrist,
      isFar: false,
      highlightBiceps: highlightMuscles,
      highlightForearm: highlightMuscles,
    );

    // LAYER 4: Hand wrap & near plate
    AnatomicalAthleteRenderer.drawHandWrap(canvas, handCenter: wrist);
    if (eq == 'Barbell') {
      AnatomicalAthleteRenderer.drawBarbell(canvas, center: wrist, plateRadius: 28, barLength: 140, layer: 4);
    } else {
      AnatomicalAthleteRenderer.drawDumbbell(canvas, center: wrist, angle: 0, layer: 4);
    }

    final arc = [const Offset(270, 195), const Offset(305, 150), const Offset(295, 95)];
    AnatomicalAthleteRenderer.drawMotionArc(canvas, points: arc);
    AnatomicalAthleteRenderer.drawPhaseArrow(
      canvas,
      start: isConcentric ? const Offset(270, 195) : const Offset(295, 95),
      end: isConcentric ? const Offset(295, 95) : const Offset(270, 195),
      isConcentric: isConcentric,
    );
  }

  // ===========================================================================
  // 11. TRICEPS PUSHDOWN
  // ===========================================================================
  void _paintPushdown(Canvas canvas, double t, bool isConcentric, String eq) {
    const towerBase = Offset(390, 345);
    const pulley = Offset(310, 40);
    final handle = Offset.lerp(const Offset(295, 135), const Offset(265, 205), t)!;

    const ankle = Offset(240, 337);
    const toe = Offset(268, 337);
    const knee = Offset(245, 255);
    const hip = Offset(235, 175);
    const shoulder = Offset(255, 95);
    const head = Offset(265, 62);
    const elbow = Offset(265, 150);

    // LAYER 1: Tower housing, guide rods, resting stack, far leg
    AnatomicalAthleteRenderer.drawCableTower(
      canvas,
      towerBase: towerBase,
      pulleyPos: pulley,
      handlePos: handle,
      stackTravel: t,
      isRope: true,
      layer: 1,
    );
    AnatomicalAthleteRenderer.drawLeg(canvas, hip: hip + const Offset(-6, -4), knee: knee + const Offset(-6, -4), ankle: ankle + const Offset(-6, -4), toe: toe + const Offset(-6, -4), isFar: true);

    // LAYER 2: Moving weight plates, cable line, torso, head
    AnatomicalAthleteRenderer.drawCableTower(
      canvas,
      towerBase: towerBase,
      pulleyPos: pulley,
      handlePos: handle,
      stackTravel: t,
      isRope: true,
      layer: 2,
    );
    AnatomicalAthleteRenderer.drawTorso(canvas, hip: hip, shoulder: shoulder);
    AnatomicalAthleteRenderer.drawHead(canvas, center: head, angle: 0.1, facingRight: true);

    // LAYER 3: Near leg & near arm
    AnatomicalAthleteRenderer.drawLeg(canvas, hip: hip, knee: knee, ankle: ankle, toe: toe, isFar: false);
    AnatomicalAthleteRenderer.drawArm(
      canvas,
      shoulder: shoulder,
      elbow: elbow,
      wrist: handle,
      isFar: false,
      highlightTriceps: highlightMuscles,
    );

    // LAYER 4: Hand wrap & selector pin
    AnatomicalAthleteRenderer.drawHandWrap(canvas, handCenter: handle);
    AnatomicalAthleteRenderer.drawCableTower(
      canvas,
      towerBase: towerBase,
      pulleyPos: pulley,
      handlePos: handle,
      stackTravel: t,
      isRope: true,
      layer: 4,
    );

    final arc = [const Offset(295, 135), const Offset(285, 170), const Offset(265, 205)];
    AnatomicalAthleteRenderer.drawMotionArc(canvas, points: arc);
    AnatomicalAthleteRenderer.drawPhaseArrow(
      canvas,
      start: isConcentric ? const Offset(295, 135) : const Offset(265, 205),
      end: isConcentric ? const Offset(265, 205) : const Offset(295, 135),
      isConcentric: isConcentric,
    );
  }

  // ===========================================================================
  // 12. DIPS
  // ===========================================================================
  void _paintDip(Canvas canvas, double t, bool isConcentric, String eq) {
    const bar = Offset(260, 200);
    final shoulder = Offset.lerp(const Offset(260, 115), const Offset(260, 195), t)!;
    final hip = Offset.lerp(const Offset(260, 205), const Offset(260, 285), t)!;
    final knee = Offset.lerp(const Offset(275, 275), const Offset(275, 335), t)!;
    final ankle = Offset.lerp(const Offset(255, 325), const Offset(255, 345), t)!;
    final head = Offset.lerp(const Offset(260, 82), const Offset(260, 162), t)!;
    final elbow = Offset.lerp(const Offset(260, 160), const Offset(215, 190), t)!;

    // LAYER 1: Far dip station bar & frame uprights
    canvas.drawLine(const Offset(210, 200), const Offset(210, 345), Paint()..color = const Color(0xFF37474F)..strokeWidth = 10);
    canvas.drawLine(const Offset(310, 200), const Offset(310, 345), Paint()..color = const Color(0xFF37474F)..strokeWidth = 10);

    // LAYER 2: Athlete torso, head, crossed legs
    AnatomicalAthleteRenderer.drawLeg(canvas, hip: hip, knee: knee, ankle: ankle, toe: ankle + const Offset(15, 5), isFar: false);
    AnatomicalAthleteRenderer.drawTorso(canvas, hip: hip, shoulder: shoulder, highlightChest: highlightMuscles);
    AnatomicalAthleteRenderer.drawHead(canvas, center: head, angle: 0.1, facingRight: true);

    // LAYER 3: Near arm pushing on parallel bar
    AnatomicalAthleteRenderer.drawArm(
      canvas,
      shoulder: shoulder,
      elbow: elbow,
      wrist: bar,
      isFar: false,
      highlightTriceps: highlightMuscles,
      highlightDeltoid: highlightMuscles,
    );

    // LAYER 4: Near parallel bar handle & hand wrap
    canvas.drawLine(const Offset(190, 200), const Offset(330, 200), Paint()..color = const Color(0xFFCFD8DC)..strokeWidth = 10..strokeCap = StrokeCap.round);
    AnatomicalAthleteRenderer.drawHandWrap(canvas, handCenter: bar);

    AnatomicalAthleteRenderer.drawPhaseArrow(
      canvas,
      start: isConcentric ? const Offset(260, 195) : const Offset(260, 115),
      end: isConcentric ? const Offset(260, 115) : const Offset(260, 195),
      isConcentric: isConcentric,
    );
  }

  // ===========================================================================
  // 13. LATERAL RAISE
  // ===========================================================================
  void _paintLateralRaise(Canvas canvas, double t, bool isConcentric, String eq) {
    const ankle = Offset(270, 337);
    const toe = Offset(298, 337);
    const knee = Offset(270, 250);
    const hip = Offset(270, 165);
    const shoulder = Offset(270, 85);
    const head = Offset(270, 52);

    final wrist = Offset.lerp(const Offset(270, 175), const Offset(355, 90), t)!;
    final elbow = Offset.lerp(const Offset(270, 130), const Offset(315, 82), t)!;

    const far = Offset(-8, -4);

    // LAYER 1: Far dumbbell & far leg
    AnatomicalAthleteRenderer.drawDumbbell(canvas, center: wrist + const Offset(-10, -5), angle: 0.2 * t, layer: 1);
    AnatomicalAthleteRenderer.drawLeg(canvas, hip: hip + far, knee: knee + far, ankle: ankle + far, toe: toe + far, isFar: true);

    // LAYER 2: Torso, head
    AnatomicalAthleteRenderer.drawTorso(canvas, hip: hip, shoulder: shoulder);
    AnatomicalAthleteRenderer.drawHead(canvas, center: head, angle: 0, facingRight: true);

    // LAYER 3: Near leg & near arm
    AnatomicalAthleteRenderer.drawLeg(canvas, hip: hip, knee: knee, ankle: ankle, toe: toe, isFar: false);
    AnatomicalAthleteRenderer.drawArm(
      canvas,
      shoulder: shoulder,
      elbow: elbow,
      wrist: wrist,
      isFar: false,
      highlightDeltoid: highlightMuscles,
    );

    // LAYER 4: Hand wrap & near dumbbell
    AnatomicalAthleteRenderer.drawHandWrap(canvas, handCenter: wrist);
    AnatomicalAthleteRenderer.drawDumbbell(canvas, center: wrist, angle: 0.2 * t, layer: 4);

    final arc = [const Offset(270, 175), const Offset(320, 135), const Offset(355, 90)];
    AnatomicalAthleteRenderer.drawMotionArc(canvas, points: arc);
    AnatomicalAthleteRenderer.drawPhaseArrow(
      canvas,
      start: isConcentric ? const Offset(270, 175) : const Offset(355, 90),
      end: isConcentric ? const Offset(355, 90) : const Offset(270, 175),
      isConcentric: isConcentric,
    );
  }

  // ===========================================================================
  // 14. PEC FLY
  // ===========================================================================
  void _paintFly(Canvas canvas, double t, bool isConcentric, String eq) {
    const headPad = Offset(140, 240);
    const hipPad = Offset(320, 240);
    const hip = Offset(310, 235);
    const shoulder = Offset(175, 230);
    const head = Offset(135, 230);

    const nearAnkle = Offset(390, 337);
    const nearToe = Offset(415, 337);

    final wrist = Offset.lerp(const Offset(175, 285), const Offset(175, 120), t)!;
    final elbow = Offset.lerp(const Offset(175, 260), const Offset(175, 175), t)!;

    // LAYER 1: Bench frame, far dumbbell, far leg
    AnatomicalAthleteRenderer.drawBench(canvas, headPos: headPad, hipPos: hipPad, layer: 1);
    AnatomicalAthleteRenderer.drawDumbbell(canvas, center: wrist, angle: math.pi / 2, layer: 1);
    AnatomicalAthleteRenderer.drawLeg(
      canvas,
      hip: hip + const Offset(-6, -6),
      knee: const Offset(365, 250) + const Offset(-6, -6),
      ankle: nearAnkle + const Offset(-6, -6),
      toe: nearToe + const Offset(-6, -6),
      isFar: true,
    );

    // LAYER 2: Bench cushion, torso, head
    AnatomicalAthleteRenderer.drawBench(canvas, headPos: headPad, hipPos: hipPad, layer: 2);
    AnatomicalAthleteRenderer.drawTorso(canvas, hip: hip, shoulder: shoulder, highlightChest: highlightMuscles);
    AnatomicalAthleteRenderer.drawHead(canvas, center: head, angle: -math.pi / 2, facingRight: true);

    // LAYER 3: Near leg & near arm
    AnatomicalAthleteRenderer.drawLeg(canvas, hip: hip, knee: const Offset(365, 250), ankle: nearAnkle, toe: nearToe, isFar: false);
    AnatomicalAthleteRenderer.drawArm(
      canvas,
      shoulder: shoulder,
      elbow: elbow,
      wrist: wrist,
      isFar: false,
      highlightDeltoid: highlightMuscles,
    );

    // LAYER 4: Near dumbbell & hand wrap
    AnatomicalAthleteRenderer.drawHandWrap(canvas, handCenter: wrist, isVertical: true);
    AnatomicalAthleteRenderer.drawDumbbell(canvas, center: wrist, angle: math.pi / 2, layer: 4);
  }

  // ===========================================================================
  // 15. LEG PRESS
  // ===========================================================================
  void _paintLegPress(Canvas canvas, double t, bool isConcentric, String eq) {
    // Sled travels along 45 degree rail
    final sled = Offset.lerp(const Offset(250, 220), const Offset(320, 150), t)!;
    const hip = Offset(145, 305);
    const shoulder = Offset(95, 255);
    const head = Offset(75, 235);

    final knee = Offset.lerp(const Offset(195, 235), const Offset(235, 235), t)!;
    // Sled plate contact: foot soles press flush against angled sled plate
    final ankle = sled + const Offset(-20, 15);
    final toe = sled + const Offset(-5, -5);

    // LAYER 1: Far rail, far guide rods, far weight plates, far leg
    AnatomicalAthleteRenderer.drawLegPressMachine(canvas, sledCenter: sled, footPos: ankle, layer: 1);
    AnatomicalAthleteRenderer.drawLeg(
      canvas,
      hip: hip + const Offset(-6, -6),
      knee: knee + const Offset(-6, -6),
      ankle: ankle + const Offset(-6, -6),
      toe: toe + const Offset(-6, -6),
      isFar: true,
      highlightQuads: highlightMuscles,
    );

    // LAYER 2: 45° backrest and seat pads, athlete torso flush against backrest, headrest, sled footplate
    AnatomicalAthleteRenderer.drawLegPressMachine(canvas, sledCenter: sled, footPos: ankle, layer: 2);
    AnatomicalAthleteRenderer.drawTorso(
      canvas,
      hip: hip,
      shoulder: shoulder,
      highlightGlutes: highlightMuscles,
    );
    AnatomicalAthleteRenderer.drawHead(canvas, center: head, angle: -0.6, facingRight: true);

    // LAYER 3: Near leg pressing firmly against footplate, arm to safety handle
    AnatomicalAthleteRenderer.drawLeg(
      canvas,
      hip: hip,
      knee: knee,
      ankle: ankle,
      toe: toe,
      isFar: false,
      highlightQuads: highlightMuscles,
    );
    AnatomicalAthleteRenderer.drawArm(
      canvas,
      shoulder: shoulder,
      elbow: const Offset(125, 280),
      wrist: const Offset(145, 290),
      isFar: false,
    );

    // LAYER 4: Near rail, near weight plates with lock collar, safety lock handle, hand wrap
    AnatomicalAthleteRenderer.drawHandWrap(canvas, handCenter: const Offset(145, 290), isVertical: true);
    AnatomicalAthleteRenderer.drawLegPressMachine(canvas, sledCenter: sled, footPos: ankle, layer: 4);

    AnatomicalAthleteRenderer.drawPhaseArrow(
      canvas,
      start: isConcentric ? const Offset(250, 220) : const Offset(320, 150),
      end: isConcentric ? const Offset(320, 150) : const Offset(250, 220),
      isConcentric: isConcentric,
    );
  }

  // ===========================================================================
  // 16. LEG EXTENSION
  // ===========================================================================
  void _paintLegExtension(Canvas canvas, double t, bool isConcentric, String eq) {
    const hip = Offset(200, 255);
    const knee = Offset(270, 255); // Pivot axle of machine
    const shoulder = Offset(185, 175);
    const head = Offset(175, 142);

    // Shin roller pad rotates around knee pivot
    final ankle = Offset.lerp(const Offset(270, 335), const Offset(350, 255), t)!;
    final toe = ankle + const Offset(18, -6);

    // LAYER 1: Far frame, guide rods, resting stack, far seat runner, far leg
    AnatomicalAthleteRenderer.drawLegExtensionEquipment(canvas, kneePivot: knee, anklePos: ankle, stackTravel: t, layer: 1);
    AnatomicalAthleteRenderer.drawLeg(
      canvas,
      hip: hip + const Offset(-6, -4),
      knee: knee + const Offset(-6, -4),
      ankle: ankle + const Offset(-6, -4),
      toe: toe + const Offset(-6, -4),
      isFar: true,
      highlightQuads: highlightMuscles,
    );

    // LAYER 2: Seat pad, angled backrest pad, moving weight stack plates, torso, head
    AnatomicalAthleteRenderer.drawLegExtensionEquipment(canvas, kneePivot: knee, anklePos: ankle, stackTravel: t, layer: 2);
    AnatomicalAthleteRenderer.drawTorso(canvas, hip: hip, shoulder: shoulder);
    AnatomicalAthleteRenderer.drawHead(canvas, center: head, angle: 0, facingRight: true);

    // LAYER 3: Near leg, arm resting on side handle
    AnatomicalAthleteRenderer.drawLeg(
      canvas,
      hip: hip,
      knee: knee,
      ankle: ankle,
      toe: toe,
      isFar: false,
      highlightQuads: highlightMuscles,
    );
    AnatomicalAthleteRenderer.drawArm(
      canvas,
      shoulder: shoulder,
      elbow: const Offset(195, 225),
      wrist: const Offset(215, 260),
      isFar: false,
    );

    // LAYER 4: Machine cam axle bolt aligned with knee pivot, rigid lever arm, padded shin roller on anterior shin, selector pin, hand wrap
    AnatomicalAthleteRenderer.drawHandWrap(canvas, handCenter: const Offset(215, 260), isVertical: true);
    AnatomicalAthleteRenderer.drawLegExtensionEquipment(canvas, kneePivot: knee, anklePos: ankle, stackTravel: t, layer: 4);

    final arc = [const Offset(270, 335), const Offset(315, 305), const Offset(350, 255)];
    AnatomicalAthleteRenderer.drawMotionArc(canvas, points: arc);
    AnatomicalAthleteRenderer.drawPhaseArrow(
      canvas,
      start: isConcentric ? const Offset(270, 335) : const Offset(350, 255),
      end: isConcentric ? const Offset(350, 255) : const Offset(270, 335),
      isConcentric: isConcentric,
    );
  }

  // ===========================================================================
  // 17. LEG CURL
  // ===========================================================================
  void _paintLegCurl(Canvas canvas, double t, bool isConcentric, String eq, String pat) {
    if (pat == 'leg_curl_prone') {
      const hip = Offset(230, 240);
      const knee = Offset(300, 240);
      const shoulder = Offset(160, 240);
      const head = Offset(125, 230);

      // Roller curls toward glutes (t=0 extended 370,240; t=1 curled 300,165)
      final ankle = Offset.lerp(const Offset(370, 240), const Offset(300, 165), t)!;
      final toe = ankle + const Offset(12, 10);

      // LAYER 1: Far bench legs, guide rods, resting stack, far leg
      AnatomicalAthleteRenderer.drawLegCurlEquipment(canvas, isProne: true, kneePivot: knee, anklePos: ankle, stackTravel: t, layer: 1);
      AnatomicalAthleteRenderer.drawLeg(
        canvas,
        hip: hip + const Offset(-4, -4),
        knee: knee + const Offset(-4, -4),
        ankle: ankle + const Offset(-4, -4),
        toe: toe + const Offset(-4, -4),
        isFar: true,
        highlightHamstrings: highlightMuscles,
      );

      // LAYER 2: Prone padded bench, torso, head, moving weight plates
      AnatomicalAthleteRenderer.drawLegCurlEquipment(canvas, isProne: true, kneePivot: knee, anklePos: ankle, stackTravel: t, layer: 2);
      AnatomicalAthleteRenderer.drawTorso(canvas, hip: hip, shoulder: shoulder);
      AnatomicalAthleteRenderer.drawHead(canvas, center: head, angle: 0, facingRight: false);

      // LAYER 3: Near leg, arm gripping prone handle
      AnatomicalAthleteRenderer.drawLeg(
        canvas,
        hip: hip,
        knee: knee,
        ankle: ankle,
        toe: toe,
        isFar: false,
        highlightHamstrings: highlightMuscles,
      );
      AnatomicalAthleteRenderer.drawArm(
        canvas,
        shoulder: shoulder,
        elbow: const Offset(150, 260),
        wrist: const Offset(135, 270),
        isFar: false,
      );

      // LAYER 4: Cam axle bolt at knee pivot, lever arm, calf roller behind Achilles, hand wrap, selector pin
      AnatomicalAthleteRenderer.drawHandWrap(canvas, handCenter: const Offset(135, 270), isVertical: true);
      AnatomicalAthleteRenderer.drawLegCurlEquipment(canvas, isProne: true, kneePivot: knee, anklePos: ankle, stackTravel: t, layer: 4);
    } else {
      // Seated leg curl
      const hip = Offset(200, 255);
      const knee = Offset(270, 255);
      const shoulder = Offset(185, 175);
      const head = Offset(175, 142);

      // Roller pad curls down & back (t=0 horizontal 350,255; t=1 curled under 270,335)
      final ankle = Offset.lerp(const Offset(350, 255), const Offset(270, 335), t)!;
      final toe = ankle + const Offset(15, -5);

      // LAYER 1: Far frame, guide rods, resting stack, far leg
      AnatomicalAthleteRenderer.drawLegCurlEquipment(canvas, isProne: false, kneePivot: knee, anklePos: ankle, stackTravel: t, layer: 1);
      AnatomicalAthleteRenderer.drawLeg(
        canvas,
        hip: hip + const Offset(-6, -4),
        knee: knee + const Offset(-6, -4),
        ankle: ankle + const Offset(-6, -4),
        toe: toe + const Offset(-6, -4),
        isFar: true,
        highlightHamstrings: highlightMuscles,
      );

      // LAYER 2: Seated pad, backrest, torso, head, moving weight plates
      AnatomicalAthleteRenderer.drawLegCurlEquipment(canvas, isProne: false, kneePivot: knee, anklePos: ankle, stackTravel: t, layer: 2);
      AnatomicalAthleteRenderer.drawTorso(canvas, hip: hip, shoulder: shoulder);
      AnatomicalAthleteRenderer.drawHead(canvas, center: head, angle: 0, facingRight: true);

      // LAYER 3: Near leg, arm resting on side handle
      AnatomicalAthleteRenderer.drawLeg(
        canvas,
        hip: hip,
        knee: knee,
        ankle: ankle,
        toe: toe,
        isFar: false,
        highlightHamstrings: highlightMuscles,
      );
      AnatomicalAthleteRenderer.drawArm(
        canvas,
        shoulder: shoulder,
        elbow: const Offset(195, 225),
        wrist: const Offset(215, 260),
        isFar: false,
      );

      // LAYER 4: Thigh hold-down roller on anterior thigh, calf roller behind calf/Achilles, cam pivot at knee, selector pin, hand wrap
      AnatomicalAthleteRenderer.drawHandWrap(canvas, handCenter: const Offset(215, 260), isVertical: true);
      AnatomicalAthleteRenderer.drawLegCurlEquipment(canvas, isProne: false, kneePivot: knee, anklePos: ankle, stackTravel: t, layer: 4);
    }
  }

  // ===========================================================================
  // 18. CALF RAISE
  // ===========================================================================
  void _paintCalfRaise(Canvas canvas, double t, bool isConcentric, String eq) {
    const toe = Offset(285, 325); // Fixed forefoot contact on block
    final ankle = Offset.lerp(const Offset(265, 330), const Offset(270, 280), t)!;
    final knee = Offset.lerp(const Offset(270, 240), const Offset(270, 195), t)!;
    final hip = Offset.lerp(const Offset(270, 155), const Offset(270, 110), t)!;
    final shoulder = Offset.lerp(const Offset(270, 75), const Offset(270, 30), t)!;
    final head = Offset.lerp(const Offset(270, 42), const Offset(270, -3), t)!;

    const far = Offset(-8, -4);

    // LAYER 1: Far calf machine frame, guide rods, far leg on block
    canvas.drawLine(const Offset(315, 30), const Offset(315, 345), Paint()..color = const Color(0xFF37474F)..strokeWidth = 8);
    AnatomicalAthleteRenderer.drawLeg(canvas, hip: hip + far, knee: knee + far, ankle: ankle + far, toe: toe + far, isFar: true, highlightCalf: highlightMuscles);

    // LAYER 2: Block step, torso, head
    canvas.drawRect(const Rect.fromLTWH(260, 325, 60, 20), Paint()..color = const Color(0xFF37474F));
    AnatomicalAthleteRenderer.drawTorso(canvas, hip: hip, shoulder: shoulder);
    AnatomicalAthleteRenderer.drawHead(canvas, center: head, angle: 0, facingRight: true);

    // LAYER 3: Near leg anchored to block step, arm holding machine handles
    AnatomicalAthleteRenderer.drawLeg(canvas, hip: hip, knee: knee, ankle: ankle, toe: toe, isFar: false, highlightCalf: highlightMuscles);
    AnatomicalAthleteRenderer.drawArm(
      canvas,
      shoulder: shoulder,
      elbow: shoulder + const Offset(15, 40),
      wrist: shoulder + const Offset(25, 60),
      isFar: false,
    );

    // LAYER 4: Machine shoulder pads resting on shoulders, guide sleeves, hand wrap
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: shoulder + const Offset(0, -5), width: 34, height: 14), const Radius.circular(4)),
      Paint()..color = const Color(0xFFDAAA5C),
    );
    canvas.drawCircle(shoulder + const Offset(0, -5), 4, Paint()..color = const Color(0xFFCFD8DC));
    AnatomicalAthleteRenderer.drawHandWrap(canvas, handCenter: shoulder + const Offset(25, 60), isVertical: true);

    AnatomicalAthleteRenderer.drawPhaseArrow(
      canvas,
      start: isConcentric ? const Offset(255, 335) : const Offset(255, 290),
      end: isConcentric ? const Offset(255, 290) : const Offset(255, 335),
      isConcentric: isConcentric,
    );
  }

  // ===========================================================================
  // 19. CRUNCH / CORE
  // ===========================================================================
  void _paintCrunch(Canvas canvas, double t, bool isConcentric, String eq) {
    const hip = Offset(270, 330);
    const knee = Offset(340, 260);
    const ankle = Offset(380, 337);
    const toe = Offset(405, 337);

    final shoulder = Offset.lerp(const Offset(150, 330), const Offset(200, 265), t)!;
    final head = Offset.lerp(const Offset(115, 330), const Offset(170, 235), t)!;

    // LAYER 1: Mat base
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(90, 340, 330, 8), const Radius.circular(3)),
      Paint()..color = const Color(0xFF1E293B),
    );

    // LAYER 2: Pelvis, torso curling off mat, head
    AnatomicalAthleteRenderer.drawTorso(
      canvas,
      hip: hip,
      shoulder: shoulder,
      highlightAbs: highlightMuscles,
    );
    AnatomicalAthleteRenderer.drawHead(canvas, center: head, angle: -0.4 * t, facingRight: true);

    // LAYER 3: Legs with feet flat on mat, arms behind head
    AnatomicalAthleteRenderer.drawLeg(canvas, hip: hip, knee: knee, ankle: ankle, toe: toe, isFar: false);
    AnatomicalAthleteRenderer.drawArm(
      canvas,
      shoulder: shoulder,
      elbow: shoulder - const Offset(25, 25),
      wrist: head,
      isFar: false,
    );

    AnatomicalAthleteRenderer.drawPhaseArrow(
      canvas,
      start: isConcentric ? const Offset(150, 330) : const Offset(200, 265),
      end: isConcentric ? const Offset(200, 265) : const Offset(150, 330),
      isConcentric: isConcentric,
    );
  }

  // ===========================================================================
  // 20. BACK EXTENSION (ROMAN CHAIR)
  // ===========================================================================
  void _paintBackExtension(Canvas canvas, double t, bool isConcentric, String eq) {
    const hip = Offset(268, 156);
    const knee = Offset(205, 222);
    const ankle = Offset(142, 285);
    const toe = Offset(164, 307);

    final angle = math.pi / 4 + (math.pi / 2) * t;
    final shoulder = hip + Offset(-math.cos(angle) * 115, math.sin(angle) * 115);
    final head = hip + Offset(-math.cos(angle) * 155, math.sin(angle) * 155);

    // LAYER 1: Far Roman chair frame, strut, far ankle roller, far leg
    AnatomicalAthleteRenderer.drawRomanChairBench(canvas, hip: hip, knee: knee, ankle: ankle, toe: toe, layer: 1);
    AnatomicalAthleteRenderer.drawLeg(
      canvas,
      hip: hip + const Offset(-6, -6),
      knee: knee + const Offset(-6, -6),
      ankle: ankle + const Offset(-6, -6),
      toe: toe + const Offset(-6, -6),
      isFar: true,
      highlightHamstrings: highlightMuscles,
    );

    // LAYER 2: Roman chair frame, 45° foot platform, 45° thigh pad, torso, head
    AnatomicalAthleteRenderer.drawRomanChairBench(canvas, hip: hip, knee: knee, ankle: ankle, toe: toe, layer: 2);
    AnatomicalAthleteRenderer.drawTorso(
      canvas,
      hip: hip,
      shoulder: shoulder,
      highlightGlutes: highlightMuscles,
      highlightBack: highlightMuscles,
    );
    AnatomicalAthleteRenderer.drawHead(
      canvas,
      center: head,
      angle: angle - math.pi / 4,
      facingRight: false,
    );

    // LAYER 3: Near leg, crossed arms over chest
    AnatomicalAthleteRenderer.drawLeg(
      canvas,
      hip: hip,
      knee: knee,
      ankle: ankle,
      toe: toe,
      isFar: false,
      highlightHamstrings: highlightMuscles,
    );
    final chestMid = hip + Offset(-math.cos(angle) * 80, math.sin(angle) * 80);
    AnatomicalAthleteRenderer.drawArm(
      canvas,
      shoulder: shoulder,
      elbow: chestMid + Offset(15 * math.sin(angle), 15 * math.cos(angle)),
      wrist: chestMid,
      isFar: false,
    );

    // LAYER 4: Near ankle roller bracket, roller cylinder with chrome bolt, pop-pin
    AnatomicalAthleteRenderer.drawRomanChairBench(canvas, hip: hip, knee: knee, ankle: ankle, toe: toe, layer: 4);

    final arc = [
      hip + Offset(-math.cos(math.pi / 4) * 135, math.sin(math.pi / 4) * 135),
      hip + Offset(-math.cos(math.pi / 2) * 135, math.sin(math.pi / 2) * 135),
      hip + Offset(-math.cos(3 * math.pi / 4) * 135, math.sin(3 * math.pi / 4) * 135),
    ];
    AnatomicalAthleteRenderer.drawMotionArc(canvas, points: arc);
    AnatomicalAthleteRenderer.drawPhaseArrow(
      canvas,
      start: isConcentric ? arc.last : arc.first,
      end: isConcentric ? arc.first : arc.last,
      isConcentric: isConcentric,
    );

    if (showLabels) {
      AnatomicalAthleteRenderer.drawCalloutBadge(canvas, number: '1', badgePos: const Offset(120, 190), targetPos: shoulder);
      AnatomicalAthleteRenderer.drawCalloutBadge(canvas, number: '2', badgePos: const Offset(310, 120), targetPos: hip);
      AnatomicalAthleteRenderer.drawCalloutBadge(canvas, number: '3', badgePos: const Offset(100, 310), targetPos: ankle);
    }
  }

  @override
  bool shouldRepaint(covariant TechniqueDiagramPainter oldDelegate) =>
      phase != oldDelegate.phase ||
      showLabels != oldDelegate.showLabels ||
      highlightMuscles != oldDelegate.highlightMuscles ||
      exercise != oldDelegate.exercise;
}
