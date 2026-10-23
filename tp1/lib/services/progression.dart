import '../models/workout.dart';

/// Conservative targets based solely on completed working sets.
class ProgressionTarget {
  final double weight;
  final int reps;
  final String reason;
  const ProgressionTarget(this.weight, this.reps, this.reason);
  static ProgressionTarget? next(
    WorkoutExercise exercise, {
    int minReps = 8,
    int maxReps = 12,
    double increment = 2.5,
  }) {
    final sets = exercise.sets.where((s) => !s.isWarmup).toList();
    if (sets.isEmpty || minReps < 1 || maxReps < minReps || increment <= 0) {
      return null;
    }
    final complete = sets
        .where((s) => s.isCompleted && (s.reps ?? 0) > 0)
        .toList();
    if (complete.isEmpty) return null;
    final weight = complete
        .map((s) => s.weight ?? 0)
        .reduce((a, b) => a > b ? a : b);
    final reps = complete
        .map((s) => s.reps ?? 0)
        .reduce((a, b) => a < b ? a : b);
    if (complete.length != sets.length || reps < minReps) {
      return ProgressionTarget(
        weight,
        minReps,
        'Repeat the load: some sets were incomplete or below the rep range.',
      );
    }
    if (complete.every(
      (s) => (s.reps ?? 0) >= maxReps && (s.weight ?? 0) == weight,
    )) {
      if (weight == 0) {
        return ProgressionTarget(
          0,
          maxReps + 1,
          'Bodyweight: add a repetition before considering external load.',
        );
      }
      return ProgressionTarget(
        weight + increment,
        minReps,
        'Every working set reached the top of the range. Increase load and restart at the lower target.',
      );
    }
    return ProgressionTarget(
      weight,
      (reps + 1).clamp(minReps, maxReps),
      'Keep the load and build repetitions within the range.',
    );
  }
}
