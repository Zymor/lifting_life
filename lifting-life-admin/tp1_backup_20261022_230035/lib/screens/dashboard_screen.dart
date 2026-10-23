import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/data_service.dart';
import '../widgets/exercise_3d_viewer.dart';
import '../widgets/stat_card.dart';
import 'admin_dashboard_screen.dart';
import 'analytics_screen.dart';
import 'courses_screen.dart';
import 'exercises_screen.dart';
import 'nutrition_screen.dart';

class DashboardScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const DashboardScreen({super.key, this.onNavigateTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _featuredExerciseId = 'ex_bb_back_squat';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DataService.instance,
      builder: (context, _) {
        final data = DataService.instance;
        final user = data.currentUser;
        final featuredEx = data.exercises.firstWhere(
          (e) => e.id == _featuredExerciseId,
          orElse: () => data.exercises.first,
        );

        return Scaffold(
          appBar: AppBar(
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LIFTING LIFE'),
                Text(
                  'Train. Progress. Compete. Inspire.',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Fitness Courses',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CoursesScreen()),
                  );
                },
                icon: const Icon(Icons.school_outlined),
              ),
              IconButton(
                tooltip: 'Progress Analytics',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                  );
                },
                icon: const Icon(Icons.insights),
              ),
              IconButton(
                tooltip: 'Notifications',
                onPressed: () => _showNotificationsModal(context, data),
                icon: Badge(
                  isLabelVisible: data.unreadNotificationsCount > 0,
                  label: Text('${data.unreadNotificationsCount}'),
                  child: const Icon(Icons.notifications_outlined),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Athlete Welcome & Active Workout Banner
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor.withValues(alpha: 0.22),
                        AppTheme.surfaceColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppTheme.primaryColor,
                            child: Text(
                              'L${user?.level ?? 1}',
                              style: const TextStyle(
                                color: AppTheme.backgroundColor,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome back, ${user?.name ?? "Athlete"}',
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${user?.trainingInterest ?? "Hybrid"} Mode • ${user?.streakDays ?? 0}-Day Streak • ${user?.xpPoints ?? 0} XP',
                                  style: const TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (data.workouts.isEmpty) ...[
                                  const SizedBox(height: 4),
                                  const Text(
                                    'No workouts yet. Start your first workout.',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => widget.onNavigateTab?.call(2),
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: Text(
                              data.activeWorkoutDraft != null
                                  ? 'Resume Active Workout'
                                  : (data.workouts.isEmpty
                                      ? 'Start your first workout.'
                                      : 'Start Workout'),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CoursesScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.school_outlined, size: 17),
                            label: const Text('Fitness Courses'),
                          ),
                          if (user?.role.canApproveCourses ?? false)
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const AdminDashboardScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.admin_panel_settings,
                                size: 17,
                                color: AppTheme.powerliftingAmber,
                              ),
                              label: Text(
                                'Owner Approvals (${data.pendingCoursesCount})',
                                style: const TextStyle(
                                  color: AppTheme.powerliftingAmber,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Key Performance Grid (100% real database values)
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: _getCrossAxisCount(context),
                  childAspectRatio:
                      MediaQuery.of(context).size.width < 400 ? 1.50 : 1.75,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: [
                    StatCard(
                      title: 'Exercise Library',
                      value: '${data.exercises.length} Lifts',
                      subtitle: 'Muscle groups and equipment guides',
                      icon: Icons.view_in_ar,
                    ),
                    StatCard(
                      title: 'Powerlifting SBD Total',
                      value:
                          '${data.currentUserSbdTotalKg.toStringAsFixed(1)} kg',
                      subtitle: data.currentUserSbdTotalKg > 0
                          ? '${data.personalRecords.length} Personal Record(s) logged'
                          : 'No workouts yet.',
                      icon: Icons.bolt,
                      iconColor: AppTheme.powerliftingAmber,
                    ),
                    StatCard(
                      title: 'Friend Leaderboard',
                      value: data.currentUserLeaderboardRank != null
                          ? '#${data.currentUserLeaderboardRank} Rank'
                          : 'Unranked',
                      subtitle: data.leaderboardEntries.isEmpty
                          ? 'No friends added.'
                          : '${user?.xpPoints ?? 0} XP • Level ${user?.level ?? 1}',
                      icon: Icons.leaderboard,
                      iconColor: AppTheme.secondaryAccent,
                    ),
                    StatCard(
                      title: 'Courses & Approvals',
                      value: data.enrolledCourses.isEmpty
                          ? '0 Enrolled'
                          : '${data.enrolledCourses.length} Enrolled',
                      subtitle: data.enrolledCourses.isEmpty
                          ? 'No courses enrolled.'
                          : '${data.publiclyApprovedCourses.length} approved courses',
                      icon: Icons.verified_outlined,
                      iconColor: AppTheme.primaryColor,
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Interactive 3D Exercise Trainer Showcase on Home
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Exercise Guide Spotlight',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => widget.onNavigateTab?.call(1),
                      child: const Text('Explore 300+ →'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _SpotlightChip(
                      label: 'Tibialis Raise',
                      active: _featuredExerciseId == 'ex_tibialis_raise',
                      onTap: () => setState(
                        () => _featuredExerciseId = 'ex_tibialis_raise',
                      ),
                    ),
                    _SpotlightChip(
                      label: 'Back Squat',
                      active: _featuredExerciseId == 'ex_bb_back_squat',
                      onTap: () => setState(
                        () => _featuredExerciseId = 'ex_bb_back_squat',
                      ),
                    ),
                    _SpotlightChip(
                      label: 'Bench Press',
                      active: _featuredExerciseId == 'ex_bb_bench_press',
                      onTap: () => setState(
                        () => _featuredExerciseId = 'ex_bb_bench_press',
                      ),
                    ),
                    _SpotlightChip(
                      label: 'Deadlift',
                      active: _featuredExerciseId == 'ex_conventional_deadlift',
                      onTap: () => setState(
                        () => _featuredExerciseId = 'ex_conventional_deadlift',
                      ),
                    ),
                    _SpotlightChip(
                      label: 'Lat Pulldown',
                      active: _featuredExerciseId == 'ex_lat_pulldown',
                      onTap: () => setState(
                        () => _featuredExerciseId = 'ex_lat_pulldown',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AnatomyExerciseViewer(exercise: featuredEx, height: 350),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ExerciseDetailScreen(exercise: featuredEx),
                        ),
                      );
                    },
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(
                      'Open Full ${featuredEx.name} Guide & Safety Cues',
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Quick Navigation Cards: Courses, Analytics, Nutrition
                Row(
                  children: [
                    Expanded(
                      child: _FeatureShortcutCard(
                        title: 'Fitness Courses',
                        subtitle: 'Learn & Submit Courses',
                        icon: Icons.school,
                        accent: AppTheme.primaryColor,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CoursesScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FeatureShortcutCard(
                        title: 'Progress Charts',
                        subtitle: '1RM & Volume Analytics',
                        icon: Icons.analytics,
                        accent: AppTheme.secondaryAccent,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AnalyticsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FeatureShortcutCard(
                        title: 'Nutrition Fuel',
                        subtitle: 'Macros & Hydration',
                        icon: Icons.restaurant,
                        accent: AppTheme.powerliftingAmber,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const NutritionScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Weekly Training Overview & Consistency
                _buildWeeklyOverviewSection(context, data),
                const SizedBox(height: 18),

                // Today's Nutrition Snapshot
                _buildNutritionSnapshotCard(context, data),
                const SizedBox(height: 18),

                // Recent Workouts & Personal Records
                _buildRecentWorkoutsSection(context, data),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 900) return 4;
    return 2;
  }

  Widget _buildWeeklyOverviewSection(BuildContext context, DataService data) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekDays = List.generate(7, (i) => monday.add(Duration(days: i)));
    final daysCompleted = <int>{};
    for (final w in data.workouts) {
      for (int i = 0; i < 7; i++) {
        final d = weekDays[i];
        if (w.date.year == d.year && w.date.month == d.month && w.date.day == d.day) {
          daysCompleted.add(i);
        }
      }
    }

    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
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
                  'Weekly Training Consistency',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${daysCompleted.length}/5 Target',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(7, (index) {
                final d = weekDays[index];
                final isDone = daysCompleted.contains(index);
                final isToday = d.year == now.year && d.month == now.month && d.day == now.day;

                return Container(
                  width: 44,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isDone
                        ? AppTheme.primaryColor.withValues(alpha: 0.18)
                        : (isToday ? AppTheme.cardColor : Colors.transparent),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDone
                          ? AppTheme.primaryColor
                          : (isToday ? AppTheme.secondaryAccent : AppTheme.borderColor),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dayLabels[index],
                        style: TextStyle(
                          color: isToday ? AppTheme.secondaryAccent : AppTheme.textTertiary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${d.day}',
                        style: TextStyle(
                          color: isDone ? AppTheme.primaryColor : AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Icon(
                        isDone ? Icons.check_circle : (isToday ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                        size: 13,
                        color: isDone
                            ? AppTheme.primaryColor
                            : (isToday ? AppTheme.secondaryAccent : AppTheme.textTertiary),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionSnapshotCard(BuildContext context, DataService data) {
    final today = DateTime.now();
    final todayMeals = data.getMealsForDate(today);
    final targets = data.nutritionTargets;
    final totalCals = todayMeals.fold<double>(0.0, (s, m) => s + m.calories);
    final totalProt = todayMeals.fold<double>(0.0, (s, m) => s + m.protein);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.powerliftingAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.restaurant, color: AppTheme.powerliftingAmber, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Today's Nutrition Fuel",
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NutritionScreen()),
                  );
                },
                child: const Text('Food Diary →'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                '${totalCals.toInt()} / ${targets.calories.toInt()} kcal',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              Text(
                '${totalProt.toInt()} / ${targets.protein.toInt()}g Protein',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (totalCals / (targets.calories > 0 ? targets.calories : 1)).clamp(0.0, 1.0),
              backgroundColor: AppTheme.borderColor,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.powerliftingAmber),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentWorkoutsSection(BuildContext context, DataService data) {
    final recent = data.workouts.take(3).toList();
    final unitLabel = (data.currentUser?.units ?? 'metric') == 'metric' ? 'kg' : 'lbs';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Recent Workouts & PRs',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (data.workouts.isNotEmpty)
              TextButton(
                onPressed: () => widget.onNavigateTab?.call(2),
                child: const Text('View All →'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No workouts logged yet.',
                  style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Your completed training sessions, volume, and detected PRs will appear here as you log workouts.',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => widget.onNavigateTab?.call(2),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Start First Workout'),
                ),
              ],
            ),
          )
        else
          ...recent.map(
            (w) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.fitness_center, color: AppTheme.primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          w.name,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${w.exercises.length} exercises • ${w.totalVolume.toInt()} $unitLabel volume',
                          style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${w.completedSets} sets',
                    style: const TextStyle(
                      color: AppTheme.secondaryAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showNotificationsModal(BuildContext context, DataService data) {
    data.markAllNotificationsRead();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notifications & Smart Reminders',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Quiet Hours Active: ${data.currentUser?.quietHoursStart ?? "22:00"} – ${data.currentUser?.quietHoursEnd ?? "07:00"} (Encourages recovery, never pressures training through pain)',
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 12),
            ...data.notifications.map(
              (n) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.notifications_active,
                  color: AppTheme.primaryColor,
                ),
                title: Text(
                  n.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  n.body,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SpotlightChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: active ? AppTheme.backgroundColor : AppTheme.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );
  }
}

class _FeatureShortcutCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _FeatureShortcutCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
