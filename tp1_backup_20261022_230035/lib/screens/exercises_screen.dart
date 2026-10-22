import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../services/data_service.dart';
import '../widgets/exercise_3d_viewer.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _selectedEquipment = 'All';
  String _selectedDifficulty = 'All';
  String _sortBy = 'Name (A-Z)';
  bool _favoritesOnly = false;

  static const List<String> _categories = [
    'All',
    'Chest',
    'Back',
    'Shoulders',
    'Biceps',
    'Triceps',
    'Forearms',
    'Quadriceps',
    'Hamstrings',
    'Glutes',
    'Calves',
    'Core',
    'Full-Body',
  ];

  static const List<String> _equipmentList = [
    'All',
    'Barbell',
    'Dumbbell',
    'Cable',
    'Machine',
    'Bodyweight',
    'Resistance Band',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Exercise> _filteredExercises(DataService data) {
    final query = _searchController.text.trim().toLowerCase();
    final favs = data.favoriteExerciseIds;

    final filtered = data.exercises.where((ex) {
      if (_favoritesOnly && !favs.contains(ex.id)) return false;
      if (_selectedCategory != 'All' && ex.category != _selectedCategory) {
        return false;
      }
      if (_selectedEquipment != 'All' && ex.equipment != _selectedEquipment) {
        return false;
      }
      if (_selectedDifficulty != 'All' &&
          ex.difficulty != _selectedDifficulty) {
        return false;
      }
      if (query.isNotEmpty) {
        final matchName = ex.name.toLowerCase().contains(query);
        final matchMuscle = ex.primaryMuscles
            .any((m) => m.toLowerCase().contains(query));
        final matchEq = ex.equipment.toLowerCase().contains(query);
        return matchName || matchMuscle || matchEq;
      }
      return true;
    }).toList();

    if (_sortBy == 'Name (A-Z)') {
      filtered.sort((a, b) => a.name.compareTo(b.name));
    } else if (_sortBy == 'Muscle Group') {
      filtered.sort((a, b) => a.category.compareTo(b.category));
    } else if (_sortBy == 'Difficulty') {
      filtered.sort((a, b) => a.difficulty.compareTo(b.difficulty));
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DataService.instance,
      builder: (context, _) {
        final data = DataService.instance;
        final list = _filteredExercises(data);

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Exercise Library'),
                Text(
                  '${list.length} of ${data.exercises.length} exercises • 360° Biomechanics',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Favorites Only',
                onPressed: () =>
                    setState(() => _favoritesOnly = !_favoritesOnly),
                icon: Icon(
                  _favoritesOnly ? Icons.favorite : Icons.favorite_border,
                  color: _favoritesOnly
                      ? AppTheme.musclePrimaryRed
                      : AppTheme.textSecondary,
                ),
              ),
              PopupMenuButton<String>(
                initialValue: _sortBy,
                tooltip: 'Sort Exercises',
                icon: const Icon(Icons.sort),
                onSelected: (v) => setState(() => _sortBy = v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'Name (A-Z)', child: Text('Sort: Name (A-Z)')),
                  PopupMenuItem(
                    value: 'Muscle Group',
                    child: Text('Sort: Muscle Group'),
                  ),
                  PopupMenuItem(value: 'Difficulty', child: Text('Sort: Difficulty')),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Search & Filter Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search 200+ exercises, muscles, or equipment...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppTheme.textSecondary,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear, size: 18),
                          )
                        : null,
                  ),
                ),
              ),

              // Muscle Category Chips
              SizedBox(
                height: 40,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final selected = _selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _selectedCategory = cat),
                      selectedColor: AppTheme.primaryColor,
                      labelStyle: TextStyle(
                        color: selected
                            ? AppTheme.backgroundColor
                            : AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),

              // Equipment & Difficulty Secondary Filters
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 34,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _equipmentList.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 6),
                          itemBuilder: (context, index) {
                            final eq = _equipmentList[index];
                            final selected = _selectedEquipment == eq;
                            return ActionChip(
                              visualDensity: VisualDensity.compact,
                              backgroundColor: selected
                                  ? AppTheme.secondaryAccent
                                      .withValues(alpha: 0.22)
                                  : AppTheme.surfaceColor,
                              side: BorderSide(
                                color: selected
                                    ? AppTheme.secondaryAccent
                                    : AppTheme.borderColor,
                              ),
                              label: Text(
                                eq == 'All' ? 'All Equipment' : eq,
                                style: TextStyle(
                                  color: selected
                                      ? AppTheme.secondaryAccent
                                      : AppTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: () =>
                                  setState(() => _selectedEquipment = eq),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedDifficulty,
                        dropdownColor: AppTheme.cardColor,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All Levels')),
                          DropdownMenuItem(value: 'Beginner', child: Text('Beginner')),
                          DropdownMenuItem(
                            value: 'Intermediate',
                            child: Text('Intermediate'),
                          ),
                          DropdownMenuItem(value: 'Advanced', child: Text('Advanced')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedDifficulty = v);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Exercise List
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.search_off,
                              size: 52,
                              color: AppTheme.textTertiary,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No matching exercises found',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _selectedCategory = 'All';
                                  _selectedEquipment = 'All';
                                  _selectedDifficulty = 'All';
                                  _favoritesOnly = false;
                                });
                              },
                              child: const Text('Reset All Filters'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final ex = list[index];
                          final isFav =
                              data.favoriteExerciseIds.contains(ex.id);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ExerciseDetailScreen(exercise: ex),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 54,
                                      height: 54,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: const Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.view_in_ar,
                                            color: AppTheme.primaryColor,
                                            size: 22,
                                          ),
                                          Text(
                                            'Guide',
                                            style: TextStyle(
                                              color: AppTheme.primaryColor,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  ex.name,
                                                  style: const TextStyle(
                                                    color: AppTheme.textPrimary,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              if (ex.isPowerliftingCompetition)
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                    left: 6,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme
                                                        .powerliftingAmber
                                                        .withValues(alpha: 0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    'SBD',
                                                    style: TextStyle(
                                                      color: AppTheme
                                                          .powerliftingAmber,
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${ex.category} • ${ex.equipment} • ${ex.difficulty}',
                                            style: const TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Primary: ${ex.primaryMuscles.join(", ")} • ${ex.suggestedSets}×${ex.suggestedReps}',
                                            style: const TextStyle(
                                              color: AppTheme.textTertiary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          data.toggleFavoriteExercise(ex.id),
                                      icon: Icon(
                                        isFav
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: isFav
                                            ? AppTheme.musclePrimaryRed
                                            : AppTheme.textTertiary,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ExerciseDetailScreen extends StatelessWidget {
  final Exercise exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  void _addToActiveWorkout(BuildContext context) {
    final data = DataService.instance;
    final currentDraft = data.activeWorkoutDraft;
    final newWorkoutEx = WorkoutExercise(
      id: data.newId(),
      exerciseId: exercise.id,
      name: exercise.name,
      muscleGroup: exercise.category,
      restTimeSeconds: exercise.restSeconds,
      sets: List.generate(
        exercise.suggestedSets,
        (i) => ExerciseSet(
          setNumber: i + 1,
          weight: exercise.equipment == 'Bodyweight' ? 0 : 60,
          reps: 8,
          rpe: 8.0,
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
          name: '${exercise.category} Session',
          trainingMode: exercise.isPowerliftingCompetition
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
        content: Text(
          'Added "${exercise.name}" (${exercise.suggestedSets} sets) to Active Workout!',
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
    return ListenableBuilder(
      listenable: DataService.instance,
      builder: (context, _) {
        final data = DataService.instance;
        final isFav = data.favoriteExerciseIds.contains(exercise.id);

        return Scaffold(
          appBar: AppBar(
            title: Text(exercise.name),
            actions: [
              IconButton(
                onPressed: () => data.toggleFavoriteExercise(exercise.id),
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav
                      ? AppTheme.musclePrimaryRed
                      : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceColor,
                border: Border(top: BorderSide(color: AppTheme.borderColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 10,
                        ),
                      ),
                      onPressed: () => _addToActiveWorkout(context),
                      icon: const Icon(Icons.add_circle_outline, size: 15),
                      label: const Text(
                        'Add to Workout',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 10,
                        ),
                      ),
                      onPressed: () {
                        data.toggleFavoriteExercise(exercise.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              !isFav
                                  ? 'Saved "${exercise.name}" to Favorites.'
                                  : 'Removed "${exercise.name}" from Favorites.',
                            ),
                          ),
                        );
                      },
                      icon: Icon(
                        isFav ? Icons.bookmark : Icons.bookmark_border,
                        size: 15,
                        color: isFav
                            ? kAnatomyPrimaryNeonGreen
                            : AppTheme.textPrimary,
                      ),
                      label: Text(
                        isFav ? 'Saved' : 'Save Exercise',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAnatomyPrimaryNeonGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 10,
                        ),
                      ),
                      onPressed: () {
                        _addToActiveWorkout(context);
                      },
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text(
                        'Start Exercise',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. TOP SECTION: Exercise Name, Main Muscle Group, Difficulty, Equipment
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _TopMetaBadge(
                              icon: Icons.accessibility_new,
                              label: 'Main Muscle: ${exercise.category}',
                              color: kAnatomyPrimaryNeonGreen,
                            ),
                            _TopMetaBadge(
                              icon: Icons.speed,
                              label: 'Difficulty: ${exercise.difficulty}',
                              color: AppTheme.secondaryAccent,
                            ),
                            _TopMetaBadge(
                              icon: Icons.fitness_center,
                              label: 'Equipment: ${exercise.equipment}',
                              color: AppTheme.powerliftingAmber,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 2. CENTER SECTION: Large Interactive 3D Muscular Anatomy Model
                AnatomyExerciseViewer(
                  exercise: exercise,
                  exerciseId: exercise.id,
                  animationPath: exercise.glbAssetPath,
                  primaryMuscles: exercise.primaryMuscles,
                  secondaryMuscles: exercise.secondaryMuscles,
                  cameraView: 'Front',
                  playbackSpeed: 1.0,
                  showMuscleLabels: true,
                  height: 390,
                  onSelectExercise: (selectedEx) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) =>
                            ExerciseDetailScreen(exercise: selectedEx),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // 3. LOWER SECTION: Primary & Secondary Muscles Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Muscle groups · not measured activation',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'PRIMARY TARGET MUSCLES (#39FF14 NEON GREEN)',
                          style: TextStyle(
                            color: kAnatomyPrimaryNeonGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: exercise.primaryMuscles.map((m) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: kAnatomyPrimaryNeonGreen.withValues(
                                  alpha: 0.16,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: kAnatomyPrimaryNeonGreen,
                                ),
                              ),
                              child: Text(
                                m,
                                style: const TextStyle(
                                  color: kAnatomyPrimaryNeonGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'SECONDARY ASSISTING MUSCLES (#9DDF91 LIGHT GREEN)',
                          style: TextStyle(
                            color: kAnatomySecondaryGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: exercise.secondaryMuscles.map((m) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: kAnatomySecondaryGreen.withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: kAnatomySecondaryGreen,
                                ),
                              ),
                              child: Text(
                                m,
                                style: const TextStyle(
                                  color: kAnatomySecondaryGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Quick Prescription Badges (Suggested sets/reps & Rest time)
                Row(
                  children: [
                    _SpecPill(
                      label: 'Equipment',
                      value: exercise.equipment,
                      icon: Icons.fitness_center,
                    ),
                    const SizedBox(width: 8),
                    _SpecPill(
                      label: 'Suggested Sets × Reps',
                      value:
                          '${exercise.suggestedSets} × ${exercise.suggestedReps}',
                      icon: Icons.repeat,
                    ),
                    const SizedBox(width: 8),
                    _SpecPill(
                      label: 'Rest Time',
                      value: '${exercise.restSeconds}s',
                      icon: Icons.timer_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Start, End & Movement Path Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Exercise notes',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _KineRow('Start Position', exercise.startPositionDesc),
                        const SizedBox(height: 8),
                        _KineRow('End Position', exercise.endPositionDesc),
                        const SizedBox(height: 8),
                        _KineRow('Movement Path', exercise.movementPathDesc),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Step-by-Step Instructions
                _SectionCard(
                  title: 'Step-by-Step Execution',
                  icon: Icons.format_list_numbered,
                  accent: AppTheme.primaryColor,
                  items: exercise.instructions,
                  numbered: true,
                ),
                const SizedBox(height: 14),

                // Technique & Safety Tips
                _SectionCard(
                  title: 'Pro Technique & Safety Cues',
                  icon: Icons.verified_user_outlined,
                  accent: AppTheme.secondaryAccent,
                  items: exercise.techniqueTips,
                ),
                const SizedBox(height: 14),

                // Common Mistakes
                _SectionCard(
                  title: 'Common Mistakes to Avoid',
                  icon: Icons.warning_amber_rounded,
                  accent: AppTheme.errorColor,
                  items: exercise.commonMistakes,
                ),
                const SizedBox(height: 14),

                // Alternative Exercises
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Biomechanically Similar Alternatives',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: exercise.alternativeNames.map((altName) {
                            return ActionChip(
                              avatar: const Icon(
                                Icons.swap_horiz,
                                size: 15,
                                color: AppTheme.primaryColor,
                              ),
                              label: Text(altName),
                              onPressed: () {
                                final altEx =
                                    data.findExerciseByNameOrDefault(altName);
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ExerciseDetailScreen(exercise: altEx),
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
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SpecPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SpecPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: AppTheme.primaryColor),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KineRow extends StatelessWidget {
  final String label;
  final String text;

  const _KineRow(this.label, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final List<String> items;
  final bool numbered;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.items,
    this.numbered = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(items.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        numbered ? '${i + 1}' : '•',
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        items[i],
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TopMetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _TopMetaBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

