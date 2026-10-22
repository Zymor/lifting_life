import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../models/exercise_demonstration.dart';
import '../services/data_service.dart';
import 'back_extension_diagram.dart';
import 'exercise_technique_diagram.dart';

// Retained for callers that display the catalog's qualitative muscle groups.
const Color kAnatomyPrimaryNeonGreen = Color(0xFF39FF14);
const Color kAnatomySecondaryGreen = Color(0xFF9DDF91);
const Color kAnatomyNeutralGray = Color(0xFF6B7280);
const Color kAnatomyDarkTendon = Color(0xFF374151);
const Color kAnatomyLightFiber = Color(0xFFCBD5E1);

/// Compatibility surface for existing screens. Playback and camera arguments
/// are intentionally inactive until a real renderer and reviewed clips exist.
class AnatomyExerciseViewer extends StatefulWidget {
  final Exercise? exercise;
  final AssetBundle? guideBundle;
  final String? exerciseId;
  final String? animationPath;
  final String? animationAsset;
  final List<String>? primaryMuscles;
  final List<String>? secondaryMuscles;
  final String cameraView; // 'Front', 'Side', 'Back', 'Left', 'Right'
  final String? initialCamera;
  final double playbackSpeed;
  final double? initialSpeed;
  final bool showMuscleLabels;
  final bool highlightMuscles;
  final double height;
  final bool compactMode;
  final bool initialStandingPose;
  final ValueChanged<Exercise>? onSelectExercise;

  const AnatomyExerciseViewer({
    super.key,
    this.exercise,
    this.guideBundle,
    this.exerciseId,
    this.animationPath,
    this.animationAsset,
    this.primaryMuscles,
    this.secondaryMuscles,
    this.cameraView = 'Front',
    this.initialCamera,
    this.playbackSpeed = 1.0,
    this.initialSpeed,
    this.showMuscleLabels = true,
    this.highlightMuscles = true,
    this.height = 410,
    this.compactMode = false,
    this.initialStandingPose = false,
    this.onSelectExercise,
  });

  @override
  State<AnatomyExerciseViewer> createState() => _AnatomyExerciseViewerState();
}

/// Alias preserving backward compatibility across all screens
class Exercise3DViewer extends AnatomyExerciseViewer {
  const Exercise3DViewer({
    super.key,
    required Exercise super.exercise,
    super.height = 390,
    super.compactMode = false,
  });
}

class _AnatomyExerciseViewerState extends State<AnatomyExerciseViewer> {
  late Future<List<ExerciseDemonstration>> _catalog;
  bool _showMuscles = false;

  @override
  void initState() {
    super.initState();
    _catalog = ExerciseDemonstrationCatalog.load(bundle: widget.guideBundle);
  }

  @override
  void didUpdateWidget(covariant AnatomyExerciseViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.guideBundle != widget.guideBundle) {
      _catalog = ExerciseDemonstrationCatalog.load(bundle: widget.guideBundle);
    }
    if (oldWidget.exercise != widget.exercise ||
        oldWidget.exerciseId != widget.exerciseId) {
      _showMuscles = false;
    }
  }

  Exercise? get _exercise {
    if (widget.exercise != null) return widget.exercise;
    if (widget.exerciseId == null) return null;
    for (final exercise in DataService.instance.exercises) {
      if (exercise.id == widget.exerciseId) return exercise;
    }
    return null; // Never substitute an unrelated exercise.
  }

  Widget _paragraph(String text, {Color color = const Color(0xFFCFD6E1)}) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(text, style: TextStyle(color: color, height: 1.5)),
      );

  @override
  Widget build(BuildContext context) {
    final exercise = _exercise;
    if (exercise == null) {
      return Container(
        key: const ValueKey('exercise-demonstration-unavailable'),
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF171C24),
          border: Border.all(color: const Color(0xFF34404F)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'EXERCISE GUIDE',
              style: TextStyle(
                color: Color(0xFFB8FF3B),
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Select an exercise',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            _paragraph(
              'Select an exercise from your workout or the exercise library '
              'to view demonstration and equipment details.',
            ),
          ],
        ),
      );
    }

    if (exercise.name == '45-Degree Back Extension' &&
        exercise.equipment == 'Bodyweight') {
      return BackExtensionDiagram(key: ValueKey(exercise.id));
    }

    final equipmentWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FutureBuilder<List<ExerciseDemonstration>>(
          future: _catalog,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _paragraph('Equipment details could not be loaded.'),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFB8FF3B),
                    ),
                    onPressed: () => setState(() {
                      _catalog = ExerciseDemonstrationCatalog.load(
                        bundle: widget.guideBundle,
                      );
                    }),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry equipment details'),
                  ),
                ],
              );
            }
            if (!snapshot.hasData) {
              return _paragraph('Loading equipment details…');
            }
            ExerciseDemonstration? guide;
            for (final item in snapshot.data!) {
              if (item.exerciseName == exercise.name &&
                  item.equipment == exercise.equipment) {
                guide = item;
                break;
              }
            }
            if (guide == null) {
              return _paragraph(
                'Equipment category: ${exercise.equipment}. '
                'A guide for this exact variation is not available yet.',
              );
            }
            final selected = guide;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Equipment for this variation',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: selected.equipmentParts
                      .map(
                        (part) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B0F14),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF455365),
                            ),
                          ),
                          child: Text(
                            part,
                            style: const TextStyle(
                              color: Color(0xFFDFE6EF),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                if (!widget.compactMode && selected.reference != null) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Setup',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  _paragraph(selected.setup),
                  const SizedBox(height: 10),
                  const Text(
                    'Movement cue',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  _paragraph(selected.cue),
                  _paragraph(
                    'Adjust stance, grip and range to your '
                    'proportions and the equipment.',
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Written reference · NASM',
                    style: TextStyle(color: Color(0xFFB8FF3B)),
                  ),
                  SelectableText(
                    selected.reference!,
                    style: const TextStyle(
                      color: Color(0xFFCFD6E1),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        if (!widget.compactMode && widget.showMuscleLabels) ...[
          const SizedBox(height: 10),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFB8FF3B),
            ),
            onPressed: () => setState(() => _showMuscles = !_showMuscles),
            child: Text(
              _showMuscles ? 'Hide muscle groups' : 'Show muscle groups',
            ),
          ),
          if (_showMuscles) ...[
            _paragraph(
              'Primary: ${(widget.primaryMuscles ?? exercise.primaryMuscles).join(', ')}',
              color: kAnatomyPrimaryNeonGreen,
            ),
            _paragraph(
              'Secondary: ${(widget.secondaryMuscles ?? exercise.secondaryMuscles).join(', ')}',
              color: kAnatomySecondaryGreen,
            ),
            _paragraph(
              'Green: primary · pale green: secondary. '
              'Catalog muscle groups, not measured activation.',
            ),
          ],
        ],
      ],
    );

    return ExerciseTechniqueDiagram(
      key: ValueKey('technique-${exercise.id}'),
      exercise: exercise,
      compactMode: widget.compactMode,
      canvasHeight: 180,
      equipmentSection: equipmentWidget,
    );
  }
}
