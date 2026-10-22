import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/program.dart';
import '../models/workout.dart';
import '../services/data_service.dart';
import '../widgets/exercise_3d_viewer.dart';
import '../widgets/plate_calculator.dart';
import 'exercises_screen.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _restTimer;
  Timer? _workoutStopwatch;
  final ValueNotifier<int> _restSecondsRemaining = ValueNotifier(0);
  DateTime? _restEndsAt;
  final ValueNotifier<int> _elapsedWorkoutSeconds = ValueNotifier(0);
  final Set<int> _expanded3DExerciseIndices = {};

  // Powerlifting 1RM Calculator state
  double _calcWeight = 140;
  int _calcReps = 5;
  final double _calcRpe = 8.5;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _workoutStopwatch = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && DataService.instance.activeWorkoutDraft != null) {
        _elapsedWorkoutSeconds.value = DateTime.now()
            .difference(DataService.instance.activeWorkoutDraft!.createdAt)
            .inSeconds.clamp(0, 2592000);
      }
    });
  }

  void _ensureActiveWorkoutInitialized() {
    final data = DataService.instance;
    final user = data.currentUser;
    if (user == null || data.activeWorkoutDraft != null) return;
    final now = DateTime.now();
    data.saveActiveWorkoutDraft(Workout(
      id: data.newId(), userId: user.id, name: 'New workout',
      trainingMode: 'Bodybuilding', date: now, createdAt: now,
      exercises: [],
    ));
    _expanded3DExerciseIndices.clear();
  }

  void _startRestTimer(int seconds) {
    _restTimer?.cancel();
    _restEndsAt = DateTime.now().add(Duration(seconds: seconds));
    _restSecondsRemaining.value = seconds;
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      _restSecondsRemaining.value = _restEndsAt!.difference(DateTime.now())
          .inSeconds.clamp(0, 86400);
      if (_restSecondsRemaining.value == 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _workoutStopwatch?.cancel();
    _elapsedWorkoutSeconds.dispose();
    _restSecondsRemaining.dispose();
    _tabController.dispose();
    super.dispose();
  }

  String _formatDuration(int totalSec) {
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DataService.instance,
      builder: (context, _) {
        final data = DataService.instance;
        final unitLabel =
            (data.currentUser?.units ?? 'metric') == 'metric' ? 'kg' : 'lbs';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Workout & Training Hub'),
            actions: [
              IconButton(
                tooltip: 'Plate Calculator',
                icon: const Icon(Icons.calculate_outlined),
                onPressed: () => PlateCalculatorDialog.show(
                  context,
                  unit: unitLabel,
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppTheme.primaryColor,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: const [
                Tab(icon: Icon(Icons.edit_note), text: 'Active Logger'),
                Tab(icon: Icon(Icons.fitness_center), text: 'Bodybuilding'),
                Tab(icon: Icon(Icons.bolt), text: 'Powerlifting SBD'),
                Tab(icon: Icon(Icons.history), text: 'History & Templates'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildActiveLoggerTab(context, data, unitLabel),
              _buildBodybuildingTab(context, data),
              _buildPowerliftingTab(context, data, unitLabel),
              _buildHistoryTab(context, data, unitLabel),
            ],
          ),
        );
      },
    );
  }

  // ============================================================================
  // TAB 1: ACTIVE WORKOUT TRACKER
  // ============================================================================
  Widget _buildActiveLoggerTab(
    BuildContext context,
    DataService data,
    String unitLabel,
  ) {
    final draft = data.activeWorkoutDraft;
    if (draft == null) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: _ensureActiveWorkoutInitialized,
          icon: const Icon(Icons.add),
          label: const Text('START NEW WORKOUT SESSION'),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Live Session Metrics Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withValues(alpha: 0.18),
                AppTheme.surfaceColor,
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          draft.name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${draft.trainingMode} • Saved on this device',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Rename Workout',
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => _promptRenameWorkout(context, draft),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 8,
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: _elapsedWorkoutSeconds,
                    builder: (context, seconds, _) => _LiveStatItem(
                      label: 'Duration', value: _formatDuration(seconds),
                    ),
                  ),
                  _LiveStatItem(
                    label: 'Volume',
                    value: '${draft.totalVolume.toInt()} $unitLabel',
                  ),
                  _LiveStatItem(
                    label: 'Sets Done',
                    value: '${draft.completedSets}/${draft.totalSets}',
                  ),
                  _LiveStatItem(
                    label: 'Est. 1RM Peak',
                    value:
                        '${draft.highestEstimated1RM.toStringAsFixed(1)} $unitLabel',
                  ),
                ],
              ),
              ValueListenableBuilder<int>(
                valueListenable: _restSecondsRemaining,
                builder: (context, seconds, _) {
                  if (seconds <= 0) return const SizedBox.shrink();
                  return Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text('Rest: ${_formatDuration(seconds)}'),
                      TextButton(onPressed: () => _startRestTimer(seconds + 30),
                        child: const Text('+30s')),
                      TextButton(onPressed: () {
                        _restTimer?.cancel();
                        _restSecondsRemaining.value = 0;
                      }, child: const Text('Skip')),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Exercise Cards in Active Workout
        ...List.generate(draft.exercises.length, (exIndex) {
          final wEx = draft.exercises[exIndex];
          return Card(
            key: ValueKey(wEx.id),
            margin: const EdgeInsets.only(bottom: 14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            final fullEx = data.findExerciseByNameOrDefault(
                              wEx.name,
                            );
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ExerciseDetailScreen(exercise: fullEx),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              const Icon(
                                Icons.view_in_ar,
                                color: AppTheme.primaryColor,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  wEx.name,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          setState(() {
                            if (_expanded3DExerciseIndices.contains(exIndex)) {
                              _expanded3DExerciseIndices.remove(exIndex);
                            } else {
                              _expanded3DExerciseIndices.add(exIndex);
                            }
                          });
                        },
                        icon: const Icon(
                          Icons.accessibility_new,
                          size: 15,
                          color: kAnatomyPrimaryNeonGreen,
                        ),
                        label: Text(
                          _expanded3DExerciseIndices.contains(exIndex)
                              ? 'Hide guide'
                              : 'Exercise guide',
                          style: const TextStyle(
                            color: kAnatomyPrimaryNeonGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Exercise actions',
                        onSelected: (action) {
                          if (action == 'swap') {
                            _showExercisePicker(context, swapIndex: exIndex);
                            return;
                          }
                          if (action == 'warmup') {
                            _generateWarmupSets(exIndex, unitLabel);
                            return;
                          }
                          if (action == 'plates') {
                            final firstW = wEx.sets.isNotEmpty ? (wEx.sets.first.weight ?? 60.0) : 60.0;
                            PlateCalculatorDialog.show(context, initialWeight: firstW, unit: unitLabel);
                            return;
                          }
                          final updated = List<WorkoutExercise>.from(draft.exercises);
                          if (action == 'remove') {
                            updated.removeAt(exIndex);
                          } else {
                            final target = action == 'up' ? exIndex - 1 : exIndex + 1;
                            if (target < 0 || target >= updated.length) return;
                            final moved = updated.removeAt(exIndex);
                            updated.insert(target, moved);
                          }
                          _expanded3DExerciseIndices.clear();
                          data.saveActiveWorkoutDraft(draft.copyWith(exercises: updated));
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'swap', child: Text('Swap exercise')),
                          const PopupMenuItem(value: 'warmup', child: Text('Generate warm-up ladder')),
                          const PopupMenuItem(value: 'plates', child: Text('Plate calculator')),
                          if (exIndex > 0)
                            const PopupMenuItem(value: 'up', child: Text('Move up')),
                          if (exIndex < draft.exercises.length - 1)
                            const PopupMenuItem(value: 'down', child: Text('Move down')),
                          const PopupMenuItem(value: 'remove', child: Text('Remove exercise')),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    '${wEx.muscleGroup} • Rest ${wEx.restTimeSeconds ?? 90}s • Best e1RM: ${wEx.bestEstimated1RM.toStringAsFixed(1)} $unitLabel',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  if (_expanded3DExerciseIndices.contains(exIndex)) ...[
                    const SizedBox(height: 10),
                    Builder(
                      builder: (context) {
                        final fullEx = data.findExerciseByNameOrDefault(
                          wEx.name,
                        );
                        return AnatomyExerciseViewer(
                          exercise: fullEx,
                          exerciseId: fullEx.id,
                          animationPath: fullEx.glbAssetPath,
                          primaryMuscles: fullEx.primaryMuscles,
                          secondaryMuscles: fullEx.secondaryMuscles,
                          height: 220,
                          compactMode: true,
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Table Header: Set | Weight | Reps | RPE | Done
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44,
                          child: Text(
                            'SET',
                            style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'WEIGHT',
                            style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'REPS',
                            style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'RPE',
                            style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          child: Center(
                            child: Text(
                              'DONE',
                              style: TextStyle(
                                color: AppTheme.textTertiary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),

                  // Set Rows
                  ...List.generate(wEx.sets.length, (setIndex) {
                    final s = wEx.sets[setIndex];
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: s.isCompleted
                            ? AppTheme.primaryColor.withValues(alpha: 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 44,
                            child: InkWell(
                              onTap: () {
                                // Toggle Warm-up vs Working Set
                                _updateSet(
                                  exIndex,
                                  setIndex,
                                  s.copyWith(isWarmup: !s.isWarmup),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: s.isWarmup
                                      ? AppTheme.powerliftingAmber
                                          .withValues(alpha: 0.2)
                                      : AppTheme.cardColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  s.isWarmup ? 'W' : '${setIndex + 1}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: s.isWarmup
                                        ? AppTheme.powerliftingAmber
                                        : AppTheme.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => _editSetValuesDialog(
                                context,
                                exIndex,
                                setIndex,
                                s,
                                unitLabel,
                              ),
                              child: Text(
                                '${(s.weight ?? 0).toStringAsFixed(s.weight == s.weight?.roundToDouble() ? 0 : 1)} $unitLabel',
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => _editSetValuesDialog(
                                context,
                                exIndex,
                                setIndex,
                                s,
                                unitLabel,
                              ),
                              child: Text(
                                '${s.reps ?? 0}',
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => _editSetValuesDialog(
                                context,
                                exIndex,
                                setIndex,
                                s,
                                unitLabel,
                              ),
                              child: Text(
                                '${s.rpe ?? 8.0}',
                                style: const TextStyle(
                                  color: AppTheme.secondaryAccent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 44,
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                final nowDone = !s.isCompleted;
                                _updateSet(
                                  exIndex,
                                  setIndex,
                                  s.copyWith(isCompleted: nowDone),
                                );
                                if (nowDone) {
                                  _startRestTimer(wEx.restTimeSeconds ?? 90);
                                }
                              },
                              icon: Icon(
                                s.isCompleted
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: s.isCompleted
                                    ? AppTheme.primaryColor
                                    : AppTheme.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          final lastSet = wEx.sets.isNotEmpty
                              ? wEx.sets.last
                              : ExerciseSet(weight: 60, reps: 8, rpe: 8.0);
                          final updatedSets = List<ExerciseSet>.from(wEx.sets)
                            ..add(
                              ExerciseSet(
                                setNumber: wEx.sets.length + 1,
                                weight: lastSet.weight,
                                reps: lastSet.reps,
                                rpe: lastSet.rpe,
                                isCompleted: false,
                              ),
                            );
                          final updatedExList = List<WorkoutExercise>.from(
                            draft.exercises,
                          );
                          updatedExList[exIndex] = wEx.copyWith(
                            sets: updatedSets,
                          );
                          data.saveActiveWorkoutDraft(
                            draft.copyWith(exercises: updatedExList),
                          );
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Set'),
                      ),
                      if (wEx.sets.length > 1)
                        TextButton.icon(
                          onPressed: () {
                            final updatedSets = List<ExerciseSet>.from(wEx.sets)
                              ..removeLast();
                            final updatedExList = List<WorkoutExercise>.from(
                              draft.exercises,
                            );
                            updatedExList[exIndex] = wEx.copyWith(
                              sets: updatedSets,
                            );
                            data.saveActiveWorkoutDraft(
                              draft.copyWith(exercises: updatedExList),
                            );
                          },
                          icon: const Icon(Icons.remove, size: 16),
                          label: const Text('Remove Set'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),

        // Action Buttons: Add Exercise, Save Template, Finish Workout
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showExercisePicker(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Exercise'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  data.saveWorkoutTemplate(draft);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Saved to Workout Templates!'),
                    ),
                  );
                },
                icon: const Icon(Icons.bookmark_border),
                label: const Text('Save Template'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _finishActiveWorkout(context, draft),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('COMPLETE & SAVE WORKOUT'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _updateSet(int exIndex, int setIndex, ExerciseSet updatedSet) {
    final data = DataService.instance;
    final draft = data.activeWorkoutDraft;
    if (draft == null) return;
    final exList = List<WorkoutExercise>.from(draft.exercises);
    final sets = List<ExerciseSet>.from(exList[exIndex].sets);
    sets[setIndex] = updatedSet;
    exList[exIndex] = exList[exIndex].copyWith(sets: sets);
    data.saveActiveWorkoutDraft(draft.copyWith(exercises: exList));
  }

  void _generateWarmupSets(int exIndex, String unitLabel) {
    final data = DataService.instance;
    final draft = data.activeWorkoutDraft;
    if (draft == null || exIndex < 0 || exIndex >= draft.exercises.length) return;

    final wEx = draft.exercises[exIndex];
    double workingWeight = 60.0;
    for (final s in wEx.sets) {
      if (!s.isWarmup && (s.weight ?? 0) > 0) {
        workingWeight = s.weight!;
        break;
      }
    }
    if (wEx.sets.isNotEmpty && (wEx.sets.first.weight ?? 0) > 0) {
      workingWeight = wEx.sets.first.weight!;
    }

    final double barWeight = unitLabel.contains('lb') ? 45.0 : 20.0;
    final double step = unitLabel.contains('lb') ? 5.0 : 2.5;

    double roundWeight(double val) {
      return (val / step).round() * step;
    }

    final List<ExerciseSet> warmups = [];
    if (workingWeight > barWeight) {
      warmups.add(ExerciseSet(
        setNumber: 1,
        weight: barWeight,
        reps: 10,
        isWarmup: true,
        isCompleted: false,
        notes: 'Barbell warm-up',
      ));
      final double halfW = roundWeight(workingWeight * 0.5);
      if (halfW > barWeight) {
        warmups.add(ExerciseSet(
          setNumber: 2,
          weight: halfW,
          reps: 5,
          isWarmup: true,
          isCompleted: false,
          notes: '50% working weight',
        ));
      }
      final double seventyW = roundWeight(workingWeight * 0.7);
      if (seventyW > halfW) {
        warmups.add(ExerciseSet(
          setNumber: 3,
          weight: seventyW,
          reps: 3,
          isWarmup: true,
          isCompleted: false,
          notes: '70% working weight',
        ));
      }
      final double eightyFiveW = roundWeight(workingWeight * 0.85);
      if (eightyFiveW > seventyW && eightyFiveW < workingWeight) {
        warmups.add(ExerciseSet(
          setNumber: 4,
          weight: eightyFiveW,
          reps: 1,
          isWarmup: true,
          isCompleted: false,
          notes: '85% potentiation single',
        ));
      }
    }

    final remainingWorkingSets = wEx.sets.where((s) => !s.isWarmup).toList();
    if (remainingWorkingSets.isEmpty) {
      remainingWorkingSets.add(ExerciseSet(
        setNumber: warmups.length + 1,
        weight: workingWeight,
        reps: 8,
        isWarmup: false,
        isCompleted: false,
      ));
    }

    final allSets = [...warmups, ...remainingWorkingSets];
    for (int i = 0; i < allSets.length; i++) {
      allSets[i] = allSets[i].copyWith(setNumber: i + 1);
    }

    final updatedExList = List<WorkoutExercise>.from(draft.exercises);
    updatedExList[exIndex] = wEx.copyWith(sets: allSets);
    data.saveActiveWorkoutDraft(draft.copyWith(exercises: updatedExList));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generated ${warmups.length} warm-up sets based on ${workingWeight.toStringAsFixed(1)} $unitLabel.'),
        backgroundColor: AppTheme.cardColor,
      ),
    );
  }

  void _editSetValuesDialog(
    BuildContext context,
    int exIndex,
    int setIndex,
    ExerciseSet current,
    String unitLabel,
  ) {
    final weightCtrl = TextEditingController(
      text: '${current.weight ?? 60}',
    );
    final repsCtrl = TextEditingController(text: '${current.reps ?? 8}');
    double rpeVal = current.rpe ?? 8.0;
    bool warmup = current.isWarmup;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: Text('Edit Set ${setIndex + 1}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: 'Weight ($unitLabel)'),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.calculate_outlined, size: 16),
                  label: const Text('Calculate Plates', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    final currentW = double.tryParse(weightCtrl.text) ?? (current.weight ?? 60.0);
                    PlateCalculatorDialog.show(
                      context,
                      initialWeight: currentW,
                      unit: unitLabel,
                      onApplyWeight: (newW) {
                        setDialogState(() {
                          weightCtrl.text = newW.toStringAsFixed(newW % 1 == 0 ? 0 : 1);
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
              const SizedBox(height: 10),
              TextField(
                controller: repsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Repetitions'),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RPE: ${rpeVal.toStringAsFixed(1)} (${(10 - rpeVal).toStringAsFixed(1)} RIR)',
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                ],
              ),
              Slider(
                value: rpeVal,
                min: 5.0,
                max: 10.0,
                divisions: 10,
                activeColor: AppTheme.primaryColor,
                onChanged: (v) => setDialogState(() => rpeVal = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Warm-up Set'),
                value: warmup,
                onChanged: (v) => setDialogState(() => warmup = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final w = double.tryParse(weightCtrl.text) ?? current.weight;
                final r = int.tryParse(repsCtrl.text) ?? current.reps;
                _updateSet(
                  exIndex,
                  setIndex,
                  current.copyWith(
                    weight: w,
                    reps: r,
                    rpe: rpeVal,
                    isWarmup: warmup,
                  ),
                );
                Navigator.pop(ctx);
              },
              child: const Text('Save Set'),
            ),
          ],
        ),
      ),
    );
  }

  void _promptRenameWorkout(BuildContext context, Workout draft) {
    final ctrl = TextEditingController(text: draft.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Workout Session Name'),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                DataService.instance.saveActiveWorkoutDraft(
                  draft.copyWith(name: ctrl.text.trim()),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    ).then((_) => ctrl.dispose());
  }

  void _showExercisePicker(BuildContext context, {int? swapIndex}) {
    final data = DataService.instance;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                swapIndex != null
                    ? 'Swap Exercise'
                    : 'Add Exercise to Workout',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: data.exercises.length,
                itemBuilder: (_, i) {
                  final ex = data.exercises[i];
                  return ListTile(
                    leading: const Icon(
                      Icons.view_in_ar,
                      color: AppTheme.primaryColor,
                    ),
                    title: Text(ex.name),
                    subtitle: Text('${ex.category} • ${ex.equipment}'),
                    onTap: () {
                      final draft = data.activeWorkoutDraft;
                      if (draft != null) {
                        final newWEx = WorkoutExercise(
                          id: data.newId(),
                          exerciseId: ex.id,
                          name: ex.name,
                          muscleGroup: ex.category,
                          restTimeSeconds: ex.restSeconds,
                          sets: [
                            ExerciseSet(
                              setNumber: 1,
                              weight: 60,
                              reps: 8,
                              rpe: 8.0,
                              isCompleted: false,
                            ),
                            ExerciseSet(
                              setNumber: 2,
                              weight: 60,
                              reps: 8,
                              rpe: 8.5,
                              isCompleted: false,
                            ),
                            ExerciseSet(
                              setNumber: 3,
                              weight: 60,
                              reps: 8,
                              rpe: 9.0,
                              isCompleted: false,
                            ),
                          ],
                        );
                        final list = List<WorkoutExercise>.from(
                          draft.exercises,
                        );
                        if (swapIndex != null) {
                          list[swapIndex] = newWEx;
                        } else {
                          list.add(newWEx);
                        }
                        data.saveActiveWorkoutDraft(
                          draft.copyWith(exercises: list),
                        );
                      }
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _finishActiveWorkout(BuildContext context, Workout draft) {
    final completed = draft.copyWith(
      date: DateTime.now(),
      durationMinutes: (DateTime.now().difference(draft.createdAt).inMinutes).clamp(1, 720),
    );
    final resultMsg = DataService.instance.addWorkout(completed);
    if (DataService.instance.activeWorkoutDraft != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resultMsg)));
      return;
    }
    _restTimer?.cancel();
    _restSecondsRemaining.value = 0;
    _elapsedWorkoutSeconds.value = 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Expanded(child: Text('Workout Summary')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              resultMsg,
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text('Total Volume: ${completed.totalVolume.toInt()} kg'),
            Text('Completed Sets: ${completed.completedSets}'),
            Text('Total Repetitions: ${completed.totalReps}'),
            Text(
              'Best Estimated 1RM: ${completed.highestEstimated1RM.toStringAsFixed(1)} kg',
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _tabController.animateTo(3);
            },
            child: const Text('View Workout History'),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 2: BODYBUILDING SYSTEM
  // ============================================================================
  Widget _buildBodybuildingTab(BuildContext context, DataService data) {
    final bbPrograms = data.programs
        .where((p) => p.mode == 'Bodybuilding')
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bodybuilding Hypertrophy System',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'PPL, Upper/Lower, Full Body, Bro Split & Custom Splits with progressive overload & deload guidance.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () =>
                    _showCreateCustomProgramDialog(context, 'Bodybuilding'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Custom Split'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...bbPrograms.map((prog) => _buildProgramCard(context, prog)),
      ],
    );
  }

  // ============================================================================
  // TAB 3: POWERLIFTING SYSTEM (SBD, 1RM CALCULATOR, VARIATIONS & BLOCKS)
  // ============================================================================
  Widget _buildPowerliftingTab(
    BuildContext context,
    DataService data,
    String unitLabel,
  ) {
    final plPrograms = data.programs
        .where((p) => p.mode == 'Powerlifting')
        .toList();

    double bestLift(String category) {
      return data.personalRecords
          .where((p) => p.category == category)
          .fold<double>(
            0,
            (best, p) => p.estimated1RM > best ? p.estimated1RM : best,
          );
    }

    final squatPr = bestLift('Squat');
    final benchPr = bestLift('Bench Press');
    final deadliftPr = bestLift('Deadlift');
    final sbdTotal = squatPr + benchPr + deadliftPr;

    // 1RM Epley + RPE adjusted estimate
    final rir = (10.0 - _calcRpe).clamp(0.0, 5.0);
    final effectiveReps = _calcReps + rir;
    final estimated1RM = _calcWeight * (1 + effectiveReps / 30.0);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Competition SBD Total Board
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.powerliftingAmber.withValues(alpha: 0.2),
                AppTheme.surfaceColor,
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppTheme.powerliftingAmber.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'POWERLIFTING SBD TOTAL',
                    style: TextStyle(
                      color: AppTheme.powerliftingAmber,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    '${sbdTotal.toStringAsFixed(1)} $unitLabel',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _SbdLiftBox('SQUAT', '${squatPr.toStringAsFixed(1)} $unitLabel'),
                  const SizedBox(width: 8),
                  _SbdLiftBox('BENCH', '${benchPr.toStringAsFixed(1)} $unitLabel'),
                  const SizedBox(width: 8),
                  _SbdLiftBox(
                    'DEADLIFT',
                    '${deadliftPr.toStringAsFixed(1)} $unitLabel',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Interactive 1RM & RPE Percentage Calculator
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estimated 1RM & Training Percentage Calculator',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Load: ${_calcWeight.toInt()} $unitLabel',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Slider(
                            value: _calcWeight,
                            min: 20,
                            max: 300,
                            divisions: 56,
                            activeColor: AppTheme.powerliftingAmber,
                            onChanged: (v) => setState(() => _calcWeight = v),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reps: $_calcReps @ RPE ${_calcRpe.toStringAsFixed(1)}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Slider(
                            value: _calcReps.toDouble(),
                            min: 1,
                            max: 12,
                            divisions: 11,
                            activeColor: AppTheme.primaryColor,
                            onChanged: (v) =>
                                setState(() => _calcReps = v.round()),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Estimated True 1-Rep Max:',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${estimated1RM.toStringAsFixed(1)} $unitLabel',
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [95, 90, 85, 80, 75, 70].map((pct) {
                          final load = estimated1RM * (pct / 100.0);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: Text(
                              '$pct%: ${load.toStringAsFixed(1)} $unitLabel',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Powerlifting Competition Variations Quick-Launch
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Powerlifting Variations & Logging',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'Pause Barbell Squat',
                    'Barbell Front Squat',
                    'Pause Bench Press',
                    'Close-Grip Barbell Bench Press',
                    'Romanian Deadlift (RDL)',
                    'Deficit Barbell Deadlift',
                  ].map((varName) {
                    return ActionChip(
                      avatar: const Icon(
                        Icons.view_in_ar,
                        size: 15,
                        color: AppTheme.powerliftingAmber,
                      ),
                      label: Text(varName),
                      onPressed: () {
                        final ex = data.findExerciseByNameOrDefault(varName);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ExerciseDetailScreen(exercise: ex),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Powerlifting Programs
        ...plPrograms.map((prog) => _buildProgramCard(context, prog)),
      ],
    );
  }

  Widget _buildProgramCard(BuildContext context, TrainingProgram prog) {
    final isPl = prog.mode == 'Powerlifting';
    final accent = isPl ? AppTheme.powerliftingAmber : AppTheme.primaryColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${prog.splitType.toUpperCase()} • ${prog.daysPerWeek} DAYS/WK',
                    style: TextStyle(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${prog.weeksDuration} Weeks • ${prog.difficulty}',
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              prog.name,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              prog.description,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deload: ${prog.deloadGuidance}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Recovery: ${prog.recoveryGuidance}',
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...prog.schedule.map((day) {
              return ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  day.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Focus: ${day.focusMuscles.join(", ")}',
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 11,
                  ),
                ),
                children: [
                  ...day.exercises.map(
                    (presc) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(
                        Icons.view_in_ar,
                        color: AppTheme.primaryColor,
                        size: 18,
                      ),
                      title: Text(
                        '${presc.exerciseName} (${presc.sets} × ${presc.repsRange})',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Rest ${presc.restSeconds}s • ${presc.intensityGuidance}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      onTap: () {
                        final ex = DataService.instance
                            .findExerciseByNameOrDefault(presc.exerciseName);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ExerciseDetailScreen(exercise: ex),
                          ),
                        );
                      },
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        final data = DataService.instance;
                        final newDraft = Workout(
                          id: data.newId(),
                          userId: data.currentUser?.id ?? 'u_owner_alex',
                          name: '${prog.name} — ${day.title}',
                          trainingMode: prog.mode,
                          date: DateTime.now(),
                          createdAt: DateTime.now(),
                          exercises: day.exercises.map((p) {
                            return WorkoutExercise(
                              id: data.newId(),
                              name: p.exerciseName,
                              muscleGroup: p.muscleGroup,
                              restTimeSeconds: p.restSeconds,
                              sets: List.generate(
                                p.sets,
                                (i) => ExerciseSet(
                                  setNumber: i + 1,
                                  weight: 80,
                                  reps: 8,
                                  rpe: p.targetRpe ?? 8.0,
                                  isCompleted: false,
                                ),
                              ),
                            );
                          }).toList(),
                        );
                        data.saveActiveWorkoutDraft(newDraft);
                        _tabController.animateTo(0);
                      },
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('Load Day into Logger'),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showCreateCustomProgramDialog(BuildContext context, String mode) {
    final nameCtrl = TextEditingController();
    final splitCtrl = TextEditingController(text: 'Custom Hypertrophy Split');
    int days = 4;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Create Custom Training Program'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Program Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: splitCtrl,
              decoration: const InputDecoration(labelText: 'Split Structure'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                DataService.instance.addCustomProgram(
                  TrainingProgram(
                    id: DataService.instance.newId(),
                    name: nameCtrl.text.trim(),
                    mode: mode,
                    splitType: splitCtrl.text.trim(),
                    difficulty: 'Intermediate',
                    weeksDuration: 8,
                    daysPerWeek: days,
                    description: 'User-customized periodized training split.',
                    deloadGuidance: 'Deload every 6th week (-40% sets).',
                    recoveryGuidance: 'Sleep 8h and track RIR.',
                    isCustom: true,
                    schedule: const [
                      ProgramDay(
                        dayNumber: 1,
                        title: 'Custom Day 1 — Upper Compound Focus',
                        focusMuscles: ['Chest', 'Back', 'Shoulders'],
                        exercises: [
                          ProgramExercisePrescription(
                            exerciseName: 'Barbell Bench Press',
                            muscleGroup: 'Chest',
                            sets: 4,
                            repsRange: '6-10',
                            targetRpe: 8.5,
                            restSeconds: 120,
                            intensityGuidance: 'Progressive overload.',
                            movementPattern: 'bench',
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Create Program'),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 4: WORKOUT HISTORY & TEMPLATES
  // ============================================================================
  Widget _buildHistoryTab(
    BuildContext context,
    DataService data,
    String unitLabel,
  ) {
    final history = data.workouts.reversed.toList();
    final templates = data.workoutTemplates;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Saved Workout Templates',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        ...templates.map(
          (tpl) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppTheme.cardColor,
                child: Icon(Icons.bookmark, color: AppTheme.primaryColor),
              ),
              title: Text(
                tpl.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${tpl.exercises.length} exercises • ${tpl.trainingMode}',
              ),
              trailing: OutlinedButton(
                onPressed: () {
                  data.saveActiveWorkoutDraft(
                    tpl.copyWith(id: data.newId(), isTemplate: false),
                  );
                  _tabController.animateTo(0);
                },
                child: const Text('Start'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Completed Workout History',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        if (history.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.fitness_center_outlined,
                    color: AppTheme.primaryColor,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No workouts yet.',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Start your first workout.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...history.map(
          (w) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          w.name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${w.date.day}/${w.date.month}/${w.date.year}',
                        style: const TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${w.trainingMode} • ${w.durationMinutes} min • ${w.totalSets} sets • Volume: ${w.totalVolume.toInt()} $unitLabel',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (w.notes != null && w.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      w.notes!,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        data.saveActiveWorkoutDraft(
                          w.copyWith(
                            id: data.newId(),
                            date: DateTime.now(),
                          ),
                        );
                        _tabController.animateTo(0);
                      },
                      icon: const Icon(Icons.copy, size: 15),
                      label: const Text('Duplicate into Logger'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveStatItem extends StatelessWidget {
  final String label;
  final String value;

  const _LiveStatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SbdLiftBox extends StatelessWidget {
  final String lift;
  final String weight;

  const _SbdLiftBox(this.lift, this.weight);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          children: [
            Text(
              lift,
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              weight,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
