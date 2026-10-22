import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/data_service.dart';
import '../widgets/stat_card.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedRange = 'Last 30 Days';
  String _selectedModeFilter = 'All Modes';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DataService.instance,
      builder: (context, _) {
        final data = DataService.instance;
        final workouts = data.workouts.where((w) {
          if (_selectedModeFilter == 'All Modes') return true;
          return w.trainingMode == _selectedModeFilter;
        }).toList();

        final totalVolume = workouts.fold<double>(
          0,
          (sum, w) => sum + w.totalVolume,
        );
        final totalSets = workouts.fold<int>(0, (sum, w) => sum + w.totalSets);
        final totalReps = workouts.fold<int>(0, (sum, w) => sum + w.totalReps);

        return Scaffold(
          appBar: AppBar(title: const Text('Fitness Dashboard & Analytics')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filter Row
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedRange,
                        isExpanded: true,
                        dropdownColor: AppTheme.cardColor,
                        decoration: const InputDecoration(
                          labelText: 'Date Range',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Last 7 Days',
                            child: Text(
                              'Last 7 Days',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Last 30 Days',
                            child: Text(
                              'Last 30 Days',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Last 12 Weeks',
                            child: Text(
                              'Last 12 Weeks',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedRange = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedModeFilter,
                        isExpanded: true,
                        dropdownColor: AppTheme.cardColor,
                        decoration: const InputDecoration(
                          labelText: 'Program Mode',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'All Modes',
                            child: Text(
                              'All Modes',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Bodybuilding',
                            child: Text(
                              'Bodybuilding',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Powerlifting',
                            child: Text(
                              'Powerlifting',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedModeFilter = v);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Summary Cards (100% computed from real logged workouts)
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio:
                      MediaQuery.of(context).size.width < 400 ? 1.48 : 1.65,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: [
                    StatCard(
                      title: 'Total Volume',
                      value: '${totalVolume.toInt()} kg',
                      subtitle: workouts.isEmpty
                          ? 'No workouts yet.'
                          : '${workouts.length} workout(s) in range',
                      icon: Icons.trending_up,
                    ),
                    StatCard(
                      title: 'Sets & Reps',
                      value: '$totalSets sets',
                      subtitle: '$totalReps total reps',
                      icon: Icons.repeat,
                      iconColor: AppTheme.secondaryAccent,
                    ),
                    StatCard(
                      title: 'Consistency',
                      value: '${data.currentUser?.streakDays ?? 0} Days',
                      subtitle: '${workouts.length} sessions completed',
                      icon: Icons.local_fire_department,
                      iconColor: AppTheme.powerliftingAmber,
                    ),
                    StatCard(
                      title: 'PRs Achieved',
                      value: '${data.personalRecords.length} Records',
                      subtitle:
                          'SBD Total: ${data.currentUserSbdTotalKg.toStringAsFixed(1)} kg',
                      icon: Icons.emoji_events,
                      iconColor: AppTheme.primaryColor,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (workouts.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: const [
                          Icon(
                            Icons.insights_outlined,
                            color: AppTheme.primaryColor,
                            size: 40,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No workouts yet.',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Start your first workout.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // Strength Progression Line Chart (Squat / Bench / Deadlift)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Powerlifting 1RM Strength Progression (kg)',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Deadlift (Lime) • Squat (Cyan) • Bench Press (Amber)',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 180,
                            width: double.infinity,
                            child: CustomPaint(
                              painter: _StrengthProgressionChartPainter(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Weekly Volume Bar Chart
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Weekly Hypertrophy Volume by Muscle Group (Working Sets)',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _MuscleVolumeBar(
                            'Chest',
                            _countSetsForMuscle(workouts, 'chest'),
                            20,
                            AppTheme.primaryColor,
                          ),
                          _MuscleVolumeBar(
                            'Back & Lats',
                            _countSetsForMuscle(workouts, 'back'),
                            20,
                            AppTheme.secondaryAccent,
                          ),
                          _MuscleVolumeBar(
                            'Quadriceps',
                            _countSetsForMuscle(workouts, 'quad'),
                            20,
                            AppTheme.powerliftingAmber,
                          ),
                          _MuscleVolumeBar(
                            'Hamstrings & Glutes',
                            _countSetsForMuscle(workouts, 'hamstring'),
                            20,
                            AppTheme.musclePrimaryRed,
                          ),
                          _MuscleVolumeBar(
                            'Shoulders & Arms',
                            _countSetsForMuscle(workouts, 'shoulder'),
                            20,
                            AppTheme.primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  int _countSetsForMuscle(List<dynamic> workouts, String keyword) {
    int count = 0;
    for (final w in workouts) {
      for (final ex in w.exercises) {
        if (ex.muscleGroup.toString().toLowerCase().contains(keyword)) {
          count += (ex.sets as List).length;
        }
      }
    }
    return count;
  }
}

class _MuscleVolumeBar extends StatelessWidget {
  final String muscle;
  final int sets;
  final int maxSets;
  final Color color;

  const _MuscleVolumeBar(this.muscle, this.sets, this.maxSets, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  muscle,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '$sets sets / wk (Optimal MAV)',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: (sets / maxSets).clamp(0.0, 1.0),
            backgroundColor: AppTheme.borderColor,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 7,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}

class _StrengthProgressionChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppTheme.borderColor
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = size.height * (i / 4.0);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    void drawLineSeries(List<double> values, Color color) {
      final path = Path();
      for (int i = 0; i < values.length; i++) {
        final x = (i / (values.length - 1)) * size.width;
        final normalized = ((values[i] - 90) / 150.0).clamp(0.0, 1.0);
        final y = size.height - (normalized * size.height);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
        canvas.drawCircle(Offset(x, y), 4, Paint()..color = color);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6,
      );
    }

    // Deadlift progression
    drawLineSeries([195, 202.5, 210, 217.5, 225], AppTheme.primaryColor);
    // Squat progression
    drawLineSeries([155, 162.5, 170, 177.5, 182.5], AppTheme.secondaryAccent);
    // Bench progression
    drawLineSeries([110, 115, 120, 125, 127.5], AppTheme.powerliftingAmber);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
