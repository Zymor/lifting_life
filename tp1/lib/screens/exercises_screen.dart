import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/exercise.dart';
import '../services/data_service.dart';
import 'exercise_detail_screen.dart';

export 'exercise_detail_screen.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _selectedCategory = 'All';
  String _selectedEquipment = 'All';
  String _selectedDifficulty = 'All';
  String _sortBy = 'Name (A-Z)';
  bool _favoritesOnly = false;
  int _displayLimit = 60;

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

  List<String> get _equipmentList => [
        'All',
        ...(DataService.instance.exercises
            .map((e) => e.equipment)
            .toSet()
            .toList()
          ..sort())
      ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      if (mounted) {
        setState(() {
          _displayLimit += 60;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
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
        final allFiltered = _filteredExercises(data);
        final displayList = allFiltered.take(_displayLimit).toList();

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Exercise Library'),
                Text(
                  '${allFiltered.length} of ${data.exercises.length} exercises • Universal Guide',
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
                icon: const Icon(Icons.sort, color: AppTheme.textSecondary),
                tooltip: 'Sort By',
                onSelected: (v) => setState(() => _sortBy = v),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'Name (A-Z)',
                    child: Text('Name (A-Z)'),
                  ),
                  PopupMenuItem(
                    value: 'Muscle Group',
                    child: Text('Muscle Group'),
                  ),
                  PopupMenuItem(
                    value: 'Difficulty',
                    child: Text('Difficulty Level'),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Search Input
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() => _displayLimit = 60),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search 5,800+ exercises, equipment, muscles...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppTheme.textSecondary,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: AppTheme.textSecondary,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _displayLimit = 60);
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.surfaceColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          const BorderSide(color: AppTheme.primaryColor),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),

              // Horizontal Muscle Category Filter Strip
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat;
                    return ActionChip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: isSelected
                          ? AppTheme.primaryColor.withValues(alpha: 0.18)
                          : AppTheme.surfaceColor,
                      side: BorderSide(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : AppTheme.borderColor,
                      ),
                      label: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedCategory = cat;
                          _displayLimit = 60;
                        });
                      },
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
                              onPressed: () {
                                setState(() {
                                  _selectedEquipment = eq;
                                  _displayLimit = 60;
                                });
                              },
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
                          DropdownMenuItem(
                            value: 'All',
                            child: Text('All Levels'),
                          ),
                          DropdownMenuItem(
                            value: 'Beginner',
                            child: Text('Beginner'),
                          ),
                          DropdownMenuItem(
                            value: 'Intermediate',
                            child: Text('Intermediate'),
                          ),
                          DropdownMenuItem(
                            value: 'Advanced',
                            child: Text('Advanced'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _selectedDifficulty = v;
                              _displayLimit = 60;
                            });
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
                child: allFiltered.isEmpty
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
                                  _displayLimit = 60;
                                });
                              },
                              child: const Text('Reset All Filters'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: displayList.length +
                            (allFiltered.length > displayList.length ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == displayList.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          final ex = displayList[index];
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
                                    // Exercise Thumbnail or Category Icon
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: ex.has3dAnimation
                                            ? AppTheme.primaryColor
                                                .withValues(alpha: 0.14)
                                            : AppTheme.surfaceColor,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                          color: ex.has3dAnimation
                                              ? AppTheme.primaryColor
                                                  .withValues(alpha: 0.4)
                                              : AppTheme.borderColor,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            ex.has3dAnimation
                                                ? Icons.view_in_ar
                                                : _iconForCategory(
                                                    ex.category),
                                            color: ex.has3dAnimation
                                                ? AppTheme.primaryColor
                                                : AppTheme.textSecondary,
                                            size: 22,
                                          ),
                                          Text(
                                            ex.has3dAnimation ? '3D' : 'Guide',
                                            style: TextStyle(
                                              color: ex.has3dAnimation
                                                  ? AppTheme.primaryColor
                                                  : AppTheme.textTertiary,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 14),

                                    // Name, Muscle Group, Equipment
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
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color:
                                                        AppTheme.textPrimary,
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              if (ex.isPowerliftingCompetition)
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                    left: 6,
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme
                                                        .powerliftingAmber
                                                        .withValues(
                                                      alpha: 0.2,
                                                    ),
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
                                                          FontWeight.w900,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                ex.category,
                                                style: const TextStyle(
                                                  color:
                                                      AppTheme.textSecondary,
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                ),
                                              ),
                                              const Text(
                                                ' • ',
                                                style: TextStyle(
                                                  color:
                                                      AppTheme.textTertiary,
                                                  fontSize: 10,
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  ex.equipment,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color:
                                                        AppTheme.textTertiary,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Favorite Toggle Button
                                    IconButton(
                                      onPressed: () {
                                        data.toggleFavoriteExercise(ex.id);
                                      },
                                      icon: Icon(
                                        isFav
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: isFav
                                            ? AppTheme.powerliftingAmber
                                            : AppTheme.textTertiary,
                                        size: 22,
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

  IconData _iconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'chest':
        return Icons.fitness_center;
      case 'back':
        return Icons.swap_vert;
      case 'shoulders':
        return Icons.airline_seat_recline_extra;
      case 'biceps':
      case 'triceps':
      case 'forearms':
        return Icons.sports_kabaddi;
      case 'quadriceps':
      case 'hamstrings':
      case 'glutes':
      case 'calves':
        return Icons.directions_walk;
      case 'core':
        return Icons.shield_outlined;
      case 'cardio':
        return Icons.directions_run;
      default:
        return Icons.accessibility_new;
    }
  }
}
