import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'drawing/anatomical_athlete_renderer.dart';

/// Original side-view geometry. This is not a GLB, skin or medical simulation.
class BackExtensionScene {
  final Offset hip, knee, ankle;
  final double torsoLength, topAngle, bottomAngle;
  final int cycleMilliseconds;
  const BackExtensionScene({
    required this.hip,
    required this.knee,
    required this.ankle,
    required this.torsoLength,
    required this.topAngle,
    required this.bottomAngle,
    required this.cycleMilliseconds,
  });
  static BackExtensionScene? _cache;
  static Future<BackExtensionScene> load() async {
    if (_cache != null) return _cache!;
    final data = jsonDecode(
      await rootBundle
          .loadString('assets/data/back_extension_diagram.json')
          .timeout(const Duration(seconds: 8)),
    ) as Map<String, dynamic>;
    Offset point(String key) {
      final values = data[key] as List;
      return Offset(
        (values[0] as num).toDouble(),
        (values[1] as num).toDouble(),
      );
    }

    if (data['version'] != 1 ||
        data['exercise'] != '45-Degree Back Extension') {
      throw const FormatException('Unsupported diagram');
    }
    return _cache = BackExtensionScene(
      hip: point('hip'),
      knee: point('knee'),
      ankle: point('ankle'),
      torsoLength: (data['torsoLength'] as num).toDouble(),
      topAngle: (data['topDegrees'] as num) * math.pi / 180,
      bottomAngle: (data['bottomDegrees'] as num) * math.pi / 180,
      cycleMilliseconds: data['cycleMilliseconds'] as int,
    );
  }

  // Cosine easing yields zero velocity at both turns and at the loop seam.
  double angle(double phase) =>
      topAngle +
      (bottomAngle - topAngle) * (1 - math.cos(phase * math.pi * 2)) / 2;
  Offset shoulder(double phase) =>
      hip +
      Offset(math.cos(angle(phase)), math.sin(angle(phase))) * torsoLength;
}

class BackExtensionDiagram extends StatefulWidget {
  const BackExtensionDiagram({super.key});
  @override
  State<BackExtensionDiagram> createState() => _BackExtensionDiagramState();
}

class _BackExtensionDiagramState extends State<BackExtensionDiagram>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion;
  late Future<BackExtensionScene> _asset;
  final _viewportKey = GlobalKey();
  bool _labels = true;
  bool _reducedMotion = false;
  bool _tickerEnabled = true;
  double _speed = 1;
  int _cycle = 6000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    );
    _motion.addListener(_checkVisibility);
    _asset = BackExtensionScene.load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    if (_reducedMotion || !_tickerEnabled) _motion.stop();
  }

  bool _isVisible() {
    final target = _viewportKey.currentContext?.findRenderObject();
    if (target is! RenderBox || !target.attached || !target.hasSize) {
      return false;
    }
    Rect visible = Offset.zero & MediaQuery.sizeOf(context);
    // Check every scroll viewport, including a nested list or clipped panel.
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
    if (_motion.isAnimating && !_isVisible()) _pause();
  }

  void _pause() {
    _motion.stop();
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  void _play() {
    if (_reducedMotion || !_tickerEnabled || !_isVisible()) return;
    _motion.duration = Duration(milliseconds: (_cycle / _speed).round());
    _motion.repeat();
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.removeListener(_checkVisibility);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF171C24),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF34404F)),
    ),
    child: FutureBuilder<BackExtensionScene>(
      future: _asset,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('The technique diagram could not be loaded.'),
              TextButton(
                onPressed: () => setState(() {
                  _asset = BackExtensionScene.load();
                }),
                child: const Text('Retry diagram'),
              ),
            ],
          );
        }
        if (!snapshot.hasData) return const Text('Loading technique diagram…');
        final scene = snapshot.data!;
        _cycle = scene.cycleMilliseconds;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Animated technique diagram',
              style: TextStyle(
                color: Color(0xFFB8FF3B),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '45-Degree Back Extension',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Text(
              'Hip-hinge variation · 2D side view',
              style: TextStyle(color: Color(0xFFBFCADA)),
            ),
            const SizedBox(height: 12),
            RepaintBoundary(
              key: _viewportKey,
              child: LayoutBuilder(
                builder: (context, constraints) => SizedBox(
                  height: math.min(constraints.maxWidth * 370 / 560, 340),
                  child: AnimatedBuilder(
                    animation: _motion,
                    builder: (_, child) => CustomPaint(
                      key: const ValueKey('back-extension-paint'),
                      painter: BackExtensionPainter(
                        scene,
                        _motion.value,
                        _labels,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
            if (_labels)
              const Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  Text('1  Thigh pad'),
                  Text('2  Ankle restraint'),
                  Text('3  Foot platform'),
                  Text('4  Bench frame'),
                ],
              ),
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: _motion,
              builder: (context, _) => Column(
                children: [
                  Text(
                    _motion.value < .02 || _motion.value > .98
                        ? 'Aligned start / finish'
                        : _motion.value < .48
                        ? 'Lower with control'
                        : _motion.value < .52
                        ? 'Comfortable bottom position'
                        : 'Return to alignment',
                    style: const TextStyle(color: Color(0xFFB8FF3B)),
                  ),
                  Slider(
                    key: const ValueKey('back-extension-timeline'),
                    label: '${(_motion.value * 100).round()}% of repetition',
                    value: _motion.value,
                    activeColor: const Color(0xFFB8FF3B),
                    onChanged: (value) {
                      _pause();
                      _motion.value = value;
                    },
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB8FF3B),
                    foregroundColor: const Color(0xFF0B0F14),
                  ),
                  onPressed: _reducedMotion
                      ? null
                      : (_motion.isAnimating ? _pause : _play),
                  icon: Icon(
                    _motion.isAnimating ? Icons.pause : Icons.play_arrow,
                  ),
                  label: Text(_motion.isAnimating ? 'Pause' : 'Play'),
                ),
                OutlinedButton(
                  onPressed: () {
                    _pause();
                    _motion.value = 0;
                  },
                  child: const Text('Restart'),
                ),
                OutlinedButton(
                  onPressed: () {
                    final playing = _motion.isAnimating;
                    setState(() => _speed = _speed == 1 ? .5 : 1);
                    if (playing) _play();
                  },
                  child: Text(_speed == 1 ? 'Speed: 1×' : 'Speed: 0.5×'),
                ),
                OutlinedButton(
                  onPressed: () => setState(() => _labels = !_labels),
                  child: Text(_labels ? 'Hide labels' : 'Show labels'),
                ),
              ],
            ),
            if (_reducedMotion)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Reduced motion is on. Use the timeline to inspect poses.',
                ),
              ),
            const SizedBox(height: 16),
            const Text('Setup', style: TextStyle(fontWeight: FontWeight.bold)),
            const Text(
              'Adjust the pad below the hip crease. Support both feet '
              'on the platform and secure the ankles against the restraints. '
              'Cross your arms over your chest.',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 10),
            const Text(
              'Movement',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text(
              'Hinge at the hips with a steady trunk. Lower through a '
              'comfortable range, then return until your torso lines up with '
              'your legs. Avoid swinging or arching past that position.',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 10),
            const Text(
              'Example range only. Adjust the bench and range to your '
              'proportions and control. The schematic simplifies anatomy; '
              'it is not individual form assessment.',
              style: TextStyle(color: Color(0xFFBFCADA), height: 1.4),
            ),
            const SizedBox(height: 10),
            const SelectableText(
              'Movement reference: Andersen et al., JSSM (2021), '
              'Roman chair protocol and Figure 1 C–D.\n'
              'https://doi.org/10.52082/jssm.2021.181',
              style: TextStyle(fontSize: 12, color: Color(0xFFBFCADA)),
            ),
          ],
        );
      },
    ),
  );
}

/// Side-view rigid segments: the hip pivot and all supports remain fixed.
class BackExtensionPainter extends CustomPainter {
  final BackExtensionScene scene;
  final double phase;
  final bool labels;
  BackExtensionPainter(this.scene, this.phase, this.labels);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 560, size.height / 370);
    canvas.save();
    canvas.translate(
      (size.width - 560 * scale) / 2,
      (size.height - 370 * scale) / 2,
    );
    canvas.scale(scale);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 560, 370),
        const Radius.circular(16),
      ),
      Paint()..color = const Color(0xFF0B0F14),
    );

    void line(Offset a, Offset b, Color color, double width) => canvas.drawLine(
      a,
      b,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );

    // -------------------------------------------------------------------------
    // LAYER 1: Far Background (Far frame runner, far support strut, far roller)
    // -------------------------------------------------------------------------
    AnatomicalAthleteRenderer.drawRomanChairBench(
      canvas,
      hip: scene.hip,
      knee: scene.knee,
      ankle: scene.ankle,
      toe: const Offset(153, 309),
      layer: 1,
    );

    // Far leg (depth shaded darker, resting on far support surfaces)
    const far = Offset(-7, -5);
    AnatomicalAthleteRenderer.drawLeg(
      canvas,
      hip: scene.hip + far,
      knee: scene.knee + far,
      ankle: scene.ankle + far,
      toe: const Offset(153, 309),
      isFar: true,
      highlightHamstrings: phase > 0.45 && phase < 0.95,
    );

    // -------------------------------------------------------------------------
    // LAYER 2: Support Surfaces & Moving Core (Main frame, footplate, thigh pad)
    // -------------------------------------------------------------------------
    AnatomicalAthleteRenderer.drawRomanChairBench(
      canvas,
      hip: scene.hip,
      knee: scene.knee,
      ankle: scene.ankle,
      toe: const Offset(160, 310),
      layer: 2,
    );

    // Biomechanical Motion Arc (Shoulder & Head Trajectory)
    final arcPoints = <Offset>[];
    for (int step = 0; step <= 20; step++) {
      arcPoints.add(scene.shoulder(step / 20));
    }
    AnatomicalAthleteRenderer.drawMotionArc(canvas, points: arcPoints);

    // Directional Phase Drive Arrow
    final isConcentric = phase > 0.5;
    final topShoulder = scene.shoulder(0);
    final botShoulder = scene.shoulder(0.5);
    if (isConcentric) {
      AnatomicalAthleteRenderer.drawPhaseArrow(
        canvas,
        start: botShoulder,
        end: topShoulder,
        isConcentric: true,
        progress: ((phase - 0.5) * 2).clamp(0.1, 0.9),
      );
    } else {
      AnatomicalAthleteRenderer.drawPhaseArrow(
        canvas,
        start: topShoulder,
        end: botShoulder,
        isConcentric: false,
        progress: (phase * 2).clamp(0.1, 0.9),
      );
    }

    // Articulated Torso (hinges around the hip crease at top edge of thigh pad)
    final angle = scene.angle(phase);
    final direction = Offset(math.cos(angle), math.sin(angle));
    final normal = Offset(-direction.dy, direction.dx);
    final shoulder = scene.shoulder(phase);

    AnatomicalAthleteRenderer.drawTorso(
      canvas,
      hip: scene.hip,
      shoulder: shoulder,
      highlightBack: true, // Erector Spinae
      highlightGlutes: true, // Gluteus Maximus
    );

    // Head & Neck
    final head = shoulder + direction * 34;
    AnatomicalAthleteRenderer.drawHead(
      canvas,
      center: head,
      angle: angle + math.pi / 2,
      facingRight: true,
    );

    // -------------------------------------------------------------------------
    // LAYER 3: Near Athlete Limbs (Near leg flush on footplate, folded arms)
    // -------------------------------------------------------------------------
    AnatomicalAthleteRenderer.drawLeg(
      canvas,
      hip: scene.hip,
      knee: scene.knee,
      ankle: scene.ankle,
      toe: const Offset(160, 310),
      isFar: false,
      highlightHamstrings: phase > 0.45 && phase < 0.95,
      highlightCalf: false,
    );

    // Hip joint articulation cap
    canvas.drawCircle(scene.hip, 11, Paint()..color = const Color(0xFF6F8CA9));

    // Folded Arms across chest (rotates with trunk)
    final elbow = shoulder - direction * 40 + normal * 26;
    final hand = shoulder - direction * 20 - normal * 8;
    AnatomicalAthleteRenderer.drawArm(
      canvas,
      shoulder: shoulder + normal * 8,
      elbow: elbow,
      wrist: hand,
      isFar: false,
      highlightForearm: false,
    );

    // -------------------------------------------------------------------------
    // LAYER 4: Near Restraints & Hardware (Near ankle roller, pop-pin, callouts)
    // -------------------------------------------------------------------------
    AnatomicalAthleteRenderer.drawRomanChairBench(
      canvas,
      hip: scene.hip,
      knee: scene.knee,
      ankle: scene.ankle,
      toe: const Offset(160, 310),
      layer: 4,
    );

    // Interactive Numbered Callout Badges
    if (labels) {
      void marker(String number, Offset at, Offset target) {
        line(at, target, const Color(0xFF9DABB9), 1.5);
        canvas.drawCircle(at, 13, Paint()..color = const Color(0xFFDAAA5C));
        final text = TextPainter(
          text: TextSpan(
            text: number,
            style: const TextStyle(
              fontSize: 18,
              fontFamily: 'Roboto',
              fontWeight: FontWeight.bold,
              color: Color(0xFF0B0F14),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, at - Offset(text.width / 2, text.height / 2));
      }

      marker('1', const Offset(304, 280), const Offset(260, 198));
      marker('2', const Offset(84, 253), const Offset(134, 269));
      marker('3', const Offset(83, 312), const Offset(140, 308));
      marker('4', const Offset(402, 325), const Offset(337, 325));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BackExtensionPainter oldDelegate) =>
      phase != oldDelegate.phase ||
      labels != oldDelegate.labels ||
      scene != oldDelegate.scene;
}
