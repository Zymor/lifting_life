import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../services/data_service.dart';
import '../widgets/exercise_media_player.dart';
import '../widgets/plate_calculator.dart';

/// Universal Exercise Detail Screen.
/// Provides a consistent, responsive, high-end presentation for every exercise in Lifting Life.
class ExerciseDetailScreen extends StatefulWidget {
  final Exercise exercise;

  const ExerciseDetailScreen({
    super.key,
    required this.exercise,
  });

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  late String _selectedResistanceMode;
  double _estWeightKg = 60.0;
  int _estReps = 8;
  bool _instructionsExpanded = true;

  @override
  void initState() {
    super.initState();
    _selectedResistanceMode = widget.exercise.computedResistanceType == 'per_side'
        ? 'Per side'
        : (widget.exercise.computedResistanceType == 'single_stack'
            ? 'Single stack'
            : (widget.exercise.computedResistanceType == 'dumbbell'
                ? 'Each dumbbell'
                : 'Off'));
  }

  double get _calculated1RM {
    if (_estReps <= 1) return _estWeightKg;
    // Epley formula: weight * (1 + reps / 30)
    return _estWeightKg * (1.0 + (_estReps / 30.0));
  }

  void _showAddToPlanSheet(BuildContext context, DataService data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return _AddToPlanModalContent(
          exercise: widget.exercise,
          data: data,
          onExerciseAdded: (planName) {
            Navigator.of(sheetContext).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppTheme.primaryColor,
                behavior: SnackBarBehavior.floating,
                content: Text(
                  'Added "${widget.exercise.name}" to "$planName"!',
                  style: const TextStyle(
                    color: AppTheme.backgroundColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPlateCalculatorSheet(BuildContext context) {
    PlateCalculatorDialog.show(
      context,
      initialWeight: _estWeightKg,
      onApplyWeight: (val) {
        setState(() => _estWeightKg = val);
      },
    );
  }

  void _addToActiveWorkout(BuildContext context, DataService data) {
    final currentDraft = data.activeWorkoutDraft;
    final newWorkoutEx = WorkoutExercise(
      id: data.newId(),
      exerciseId: widget.exercise.id,
      name: widget.exercise.name,
      muscleGroup: widget.exercise.category,
      sets: List.generate(
        widget.exercise.suggestedSets,
        (i) => ExerciseSet(
          setNumber: i + 1,
          reps: int.tryParse(widget.exercise.suggestedReps.split('-').first) ?? 10,
          weight: _estWeightKg,
          isWarmup: i == 0,
          isCompleted: false,
        ),
      ),
    );

    if (currentDraft == null) {
      data.saveActiveWorkoutDraft(
        Workout(
          id: data.newId(),
          userId: data.currentUser?.id ?? 'u_owner_alex',
          name: '${widget.exercise.category} Session',
          trainingMode: widget.exercise.isPowerliftingCompetition
              ? 'Powerlifting'
              : 'Bodybuilding',
          date: DateTime.now(),
          exercises: [newWorkoutEx],
          createdAt: DateTime.now(),
        ),
      );
    } else {
      final updatedList = List<WorkoutExercise>.from(currentDraft.exercises)
        ..add(newWorkoutEx);
      data.saveActiveWorkoutDraft(
        currentDraft.copyWith(exercises: updatedList),
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Added "${widget.exercise.name}" to Active Session!',
          style: const TextStyle(
            color: AppTheme.backgroundColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;

    return ListenableBuilder(
      listenable: DataService.instance,
      builder: (context, _) {
        final data = DataService.instance;
        final isFav = data.favoriteExerciseIds.contains(ex.id);

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            backgroundColor: AppTheme.backgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              ex.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: [
              IconButton(
                tooltip: isFav ? 'Remove from Favorites' : 'Add to Favorites',
                onPressed: () {
                  data.toggleFavoriteExercise(ex.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      content: Text(
                        !isFav
                            ? 'Saved "${ex.name}" to Favorites.'
                            : 'Removed "${ex.name}" from Favorites.',
                      ),
                    ),
                  );
                },
                icon: Icon(
                  isFav ? Icons.star : Icons.star_border,
                  color: isFav
                      ? AppTheme.powerliftingAmber
                      : AppTheme.textSecondary,
                  size: 26,
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceColor,
                border: Border(top: BorderSide(color: AppTheme.borderColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppTheme.borderColor),
                      ),
                      onPressed: () => _addToActiveWorkout(context, data),
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text(
                        'Add to Workout',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        _addToActiveWorkout(context, data);
                      },
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text(
                        'Start Exercise',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Large Media Container (3D / Video / High-Def Biomechanical Diagram)
                ExerciseMediaPlayer(
                  exercise: ex,
                  height: 330,
                  autoPlay: true,
                ),
                const SizedBox(height: 14),

                // 2. Dynamic Muscle and Equipment Tags
                _buildDynamicTags(ex),
                const SizedBox(height: 14),

                // 3. Exercise Description
                _buildDescriptionCard(ex),
                const SizedBox(height: 14),

                // 4. Large Green "+ Add to My Plan" Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.black,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => _showAddToPlanSheet(context, data),
                    icon: const Icon(Icons.add_circle, size: 22),
                    label: const Text(
                      '+ Add to My Plan',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // 5. Intelligent Resistance & Plate Loading Section
                _buildResistanceAndPlateSection(context, ex),
                const SizedBox(height: 16),

                // 6. Interactive One-Rep Max (1RM) Estimator
                if (ex.computedResistanceType != 'cardio') ...[
                  _buildOneRepMaxCalculator(ex),
                  const SizedBox(height: 16),
                ],

                // 7. Step-by-Step Instructions ("How To")
                _buildInstructionsCard(ex),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDynamicTags(Exercise ex) {
    final tags = <Widget>[];

    // Major Category / Body Part
    tags.add(
      _DynamicTagChip(
        label: ex.category,
        icon: Icons.accessibility_new,
        color: AppTheme.primaryColor,
        isAccent: true,
      ),
    );

    // Primary Target Muscles
    for (final muscle in ex.primaryMuscles) {
      if (muscle.toLowerCase() != ex.category.toLowerCase()) {
        tags.add(
          _DynamicTagChip(
            label: muscle,
            icon: Icons.radar,
            color: AppTheme.primaryColor,
          ),
        );
      }
    }

    // Equipment
    tags.add(
      _DynamicTagChip(
        label: ex.equipment,
        icon: Icons.fitness_center,
        color: AppTheme.powerliftingAmber,
      ),
    );

    // Secondary Muscles (up to 3)
    for (final muscle in ex.secondaryMuscles.take(3)) {
      tags.add(
        _DynamicTagChip(
          label: muscle,
          icon: null,
          color: AppTheme.textSecondary,
        ),
      );
    }

    // Difficulty
    tags.add(
      _DynamicTagChip(
        label: ex.difficulty,
        icon: Icons.speed,
        color: AppTheme.secondaryAccent,
      ),
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags,
    );
  }

  Widget _buildDescriptionCard(Exercise ex) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 17),
              SizedBox(width: 8),
              Text(
                'Exercise Overview',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ex.displayDescription,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResistanceAndPlateSection(BuildContext context, Exercise ex) {
    final type = ex.computedResistanceType;

    // Hide plate loading for bodyweight or cardio
    if (type == 'cardio') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cardiovascular Tracking',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'This exercise tracks duration, distance, and perceived rate of exertion (RPE). Plate loading is automatically disabled.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (type == 'bodyweight') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resistance: Bodyweight',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Bodyweight resistance model. External plate loading is omitted by default.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildSegmentButton('Bodyweight Only', _selectedResistanceMode == 'Off', () {
                  setState(() => _selectedResistanceMode = 'Off');
                }),
                const SizedBox(width: 8),
                _buildSegmentButton('Weighted (+ Belt)', _selectedResistanceMode == 'Per side', () {
                  setState(() => _selectedResistanceMode = 'Per side');
                }),
              ],
            ),
          ],
        ),
      );
    }

    // Barbell, Smith, Plate-loaded or Cable Machine
    final isBarbell = type == 'per_side';
    final isDumbbell = type == 'dumbbell';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isDumbbell ? 'Dumbbell Load Configuration' : 'Plate Loading & Resistance',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isBarbell)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppTheme.primaryColor,
                  ),
                  onPressed: () => _showPlateCalculatorSheet(context),
                  icon: const Icon(Icons.calculate_outlined, size: 16),
                  label: const Text('Plate Calculator', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isDumbbell
                ? 'Specify whether logged weights represent each individual dumbbell or the combined pair total.'
                : 'Select how weights are loaded. Feeds the visual sleeve breakdown on your working sets.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: isDumbbell
                  ? [
                      _buildSegmentButton(
                        'Each dumbbell',
                        _selectedResistanceMode == 'Each dumbbell',
                        () => setState(() => _selectedResistanceMode = 'Each dumbbell'),
                      ),
                      const SizedBox(width: 8),
                      _buildSegmentButton(
                        'Combined total',
                        _selectedResistanceMode == 'Single stack',
                        () => setState(() => _selectedResistanceMode = 'Single stack'),
                      ),
                    ]
                  : [
                      _buildSegmentButton(
                        'Per side',
                        _selectedResistanceMode == 'Per side',
                        () => setState(() => _selectedResistanceMode = 'Per side'),
                      ),
                      const SizedBox(width: 8),
                      _buildSegmentButton(
                        'Single stack',
                        _selectedResistanceMode == 'Single stack',
                        () => setState(() => _selectedResistanceMode = 'Single stack'),
                      ),
                      const SizedBox(width: 8),
                      _buildSegmentButton(
                        'Off',
                        _selectedResistanceMode == 'Off',
                        () => setState(() => _selectedResistanceMode = 'Off'),
                      ),
                    ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.18) : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildOneRepMaxCalculator(Exercise ex) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Estimated One-Rep Max (1RM)',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_calculated1RM.toStringAsFixed(1)} kg',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStepperControl(
                  label: 'Working Weight',
                  valueStr: '${_estWeightKg.toStringAsFixed(1)} kg',
                  onMinus: () {
                    setState(() {
                      if (_estWeightKg > 5) _estWeightKg -= 2.5;
                    });
                  },
                  onPlus: () {
                    setState(() {
                      _estWeightKg += 2.5;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStepperControl(
                  label: 'Reps Performed',
                  valueStr: '$_estReps reps',
                  onMinus: () {
                    setState(() {
                      if (_estReps > 1) _estReps -= 1;
                    });
                  },
                  onPlus: () {
                    setState(() {
                      if (_estReps < 15) _estReps += 1;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Based on the Epley & Brzycki formula blend from submaximal sets.',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperControl({
    required String label,
    required String valueStr,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: onMinus,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.remove, size: 16, color: AppTheme.primaryColor),
                ),
              ),
              Text(
                valueStr,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              InkWell(
                onTap: onPlus,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.add, size: 16, color: AppTheme.primaryColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard(Exercise ex) {
    final steps = ex.instructions.isNotEmpty
        ? ex.instructions
        : [
            ex.startPositionDesc.isNotEmpty
                ? ex.startPositionDesc
                : 'Set up in a balanced, stable stance with proper posture and core braced.',
            ex.movementPathDesc.isNotEmpty
                ? ex.movementPathDesc
                : 'Initiate the movement smoothly through the targeted active range of motion.',
            'Maintain steady breathing (inhale on negative, exhale on exertion).',
            ex.endPositionDesc.isNotEmpty
                ? ex.endPositionDesc
                : 'Pause briefly at peak contraction before returning to the start position.',
          ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _instructionsExpanded = !_instructionsExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.format_list_numbered, color: AppTheme.primaryColor, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Step-by-Step Instructions',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _instructionsExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_instructionsExpanded) ...[
            const Divider(color: AppTheme.borderColor, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < steps.length; i++) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.primaryColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              steps[i],
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (ex.techniqueTips.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline, color: AppTheme.powerliftingAmber, size: 17),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pro Tip: ${ex.techniqueTips.first}',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dynamic chip used under media for body part, muscles, equipment.
class _DynamicTagChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final bool isAccent;

  const _DynamicTagChip({
    required this.label,
    this.icon,
    required this.color,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: isAccent
            ? color.withValues(alpha: 0.18)
            : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAccent ? color : AppTheme.borderColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: isAccent ? color : AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Content modal for selecting or creating a workout plan.
class _AddToPlanModalContent extends StatefulWidget {
  final Exercise exercise;
  final DataService data;
  final ValueChanged<String> onExerciseAdded;

  const _AddToPlanModalContent({
    required this.exercise,
    required this.data,
    required this.onExerciseAdded,
  });

  @override
  State<_AddToPlanModalContent> createState() => _AddToPlanModalContentState();
}

class _AddToPlanModalContentState extends State<_AddToPlanModalContent> {
  final TextEditingController _newPlanController = TextEditingController();
  bool _isCreatingNew = false;
  int _targetSets = 3;
  String _targetReps = '8-12';
  final double _defaultWeightKg = 20.0;

  @override
  void dispose() {
    _newPlanController.dispose();
    super.dispose();
  }

  Future<void> _handleAddToExisting(Workout plan) async {
    await widget.data.addExerciseToPlan(
      templateId: plan.id,
      exercise: widget.exercise,
      sets: _targetSets,
      reps: _targetReps,
      defaultWeightKg: _defaultWeightKg,
    );
    widget.onExerciseAdded(plan.name);
  }

  Future<void> _handleCreateNewPlan() async {
    final name = _newPlanController.text.trim();
    if (name.isEmpty) return;

    final newPlan = await widget.data.createNewWorkoutPlan(
      name: name,
      trainingMode: 'Hypertrophy',
      initialExercise: widget.exercise,
      sets: _targetSets,
      reps: _targetReps,
      defaultWeightKg: _defaultWeightKg,
    );
    widget.onExerciseAdded(newPlan.name);
  }

  @override
  Widget build(BuildContext context) {
    final plans = widget.data.workoutTemplates;

    return Padding(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Add to Workout Plan',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Add "${widget.exercise.name}" to one of your training routines.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),

          // Sets and Reps Config
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune, color: AppTheme.primaryColor, size: 18),
                const SizedBox(width: 10),
                const Text(
                  'Sets:',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(width: 6),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _targetSets,
                    dropdownColor: AppTheme.cardColor,
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                    items: [1, 2, 3, 4, 5, 6].map((s) {
                      return DropdownMenuItem(value: s, child: Text('$s sets'));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _targetSets = v);
                    },
                  ),
                ),
                const Spacer(),
                const Text(
                  'Reps:',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(width: 6),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _targetReps,
                    dropdownColor: AppTheme.cardColor,
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                    items: const [
                      DropdownMenuItem(value: '5x5', child: Text('5 reps')),
                      DropdownMenuItem(value: '6-8', child: Text('6-8 reps')),
                      DropdownMenuItem(value: '8-12', child: Text('8-12 reps')),
                      DropdownMenuItem(value: '12-15', child: Text('12-15 reps')),
                      DropdownMenuItem(value: '15-20', child: Text('15-20 reps')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _targetReps = v);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Create New vs Existing Switcher
          if (!_isCreatingNew) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Existing Routine',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _isCreatingNew = true),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Plan', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: plans.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No workout plans created yet.\nTap "New Plan" above to create one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: plans.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final plan = plans[idx];
                        final alreadyHas = plan.exercises.any(
                          (e) => e.exerciseId == widget.exercise.id,
                        );

                        return Material(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _handleAddToExisting(plan),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.calendar_today_outlined,
                                      color: AppTheme.primaryColor,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          plan.name,
                                          style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          '${plan.exercises.length} exercises • ${plan.trainingMode}',
                                          style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (alreadyHas)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceColor,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppTheme.borderColor),
                                      ),
                                      child: const Text(
                                        'Added',
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    )
                                  else
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 14,
                                      color: AppTheme.primaryColor,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ] else ...[
            // Create New Routine Form
            const Text(
              'Create New Workout Routine',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _newPlanController,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. Upper Body Hypertrophy',
                hintStyle: const TextStyle(color: AppTheme.textTertiary),
                filled: true,
                fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _isCreatingNew = false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: _handleCreateNewPlan,
                    child: const Text(
                      'Create & Add',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
