class ExerciseSet {
  final int setNumber;
  final int? reps;
  final double? weight; // in kg
  final double? rpe; // 1.0 - 10.0
  final int? rir; // Repetitions in Reserve (0 - 6)
  final bool isWarmup;
  final bool isCompleted;
  final int? restSeconds;
  final String? notes;
  final int? duration; // in seconds
  final double? distance; // in km

  ExerciseSet({
    this.setNumber = 1,
    this.reps,
    this.weight,
    this.rpe,
    this.rir,
    this.isWarmup = false,
    this.isCompleted = true,
    this.restSeconds = 90,
    this.notes,
    this.duration,
    this.distance,
  });

  double get estimatedOneRepMax {
    final w = weight ?? 0;
    final r = reps ?? 0;
    if (w <= 0 || r <= 0) return 0;
    if (r == 1) return w;
    // Epley formula
    return w * (1 + r / 30.0);
  }

  ExerciseSet copyWith({
    int? setNumber,
    int? reps,
    double? weight,
    double? rpe,
    int? rir,
    bool? isWarmup,
    bool? isCompleted,
    int? restSeconds,
    String? notes,
  }) {
    return ExerciseSet(
      setNumber: setNumber ?? this.setNumber,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      rpe: rpe ?? this.rpe,
      rir: rir ?? this.rir,
      isWarmup: isWarmup ?? this.isWarmup,
      isCompleted: isCompleted ?? this.isCompleted,
      restSeconds: restSeconds ?? this.restSeconds,
      notes: notes ?? this.notes,
      duration: duration,
      distance: distance,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'setNumber': setNumber,
      'reps': reps,
      'weight': weight,
      'rpe': rpe,
      'rir': rir,
      'isWarmup': isWarmup,
      'isCompleted': isCompleted,
      'restSeconds': restSeconds,
      'notes': notes,
      'duration': duration,
      'distance': distance,
    };
  }

  factory ExerciseSet.fromMap(Map<String, dynamic> map) {
    return ExerciseSet(
      setNumber: map['setNumber'] ?? 1,
      reps: map['reps'],
      weight: map['weight']?.toDouble(),
      rpe: map['rpe']?.toDouble(),
      rir: map['rir'],
      isWarmup: map['isWarmup'] ?? false,
      isCompleted: map['isCompleted'] ?? true,
      restSeconds: map['restSeconds'] ?? 90,
      notes: map['notes'],
      duration: map['duration'],
      distance: map['distance']?.toDouble(),
    );
  }
}

class WorkoutExercise {
  final String id;
  final String? exerciseId;
  final String name;
  final String muscleGroup;
  final List<ExerciseSet> sets;
  final int? restTimeSeconds;
  final String? notes;

  WorkoutExercise({
    required this.id,
    this.exerciseId,
    required this.name,
    required this.muscleGroup,
    required this.sets,
    this.restTimeSeconds = 90,
    this.notes,
  });

  double get bestEstimated1RM {
    double best = 0;
    for (final s in sets) {
      if (s.isCompleted && !s.isWarmup && s.estimatedOneRepMax > best) {
        best = s.estimatedOneRepMax;
      }
    }
    return best;
  }

  WorkoutExercise copyWith({
    String? id,
    String? exerciseId,
    String? name,
    String? muscleGroup,
    List<ExerciseSet>? sets,
    int? restTimeSeconds,
    String? notes,
  }) {
    return WorkoutExercise(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      sets: sets ?? this.sets,
      restTimeSeconds: restTimeSeconds ?? this.restTimeSeconds,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exerciseId': exerciseId,
      'name': name,
      'muscleGroup': muscleGroup,
      'sets': sets.map((set) => set.toMap()).toList(),
      'restTimeSeconds': restTimeSeconds,
      'notes': notes,
    };
  }

  factory WorkoutExercise.fromMap(Map<String, dynamic> map) {
    return WorkoutExercise(
      id: map['id'] ?? '',
      exerciseId: map['exerciseId'],
      name: map['name'] ?? '',
      muscleGroup: map['muscleGroup'] ?? '',
      sets: (map['sets'] as List<dynamic>?)
              ?.map((e) => ExerciseSet.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      restTimeSeconds: map['restTimeSeconds'],
      notes: map['notes'],
    );
  }
}

class PersonalRecord {
  final String id;
  final String exerciseName;
  final String category; // Squat, Bench Press, Deadlift, or General
  final double weightKg;
  final int reps;
  final double estimated1RM;
  final DateTime date;
  final bool isCompetitionLift;

  const PersonalRecord({
    required this.id,
    required this.exerciseName,
    required this.category,
    required this.weightKg,
    required this.reps,
    required this.estimated1RM,
    required this.date,
    this.isCompetitionLift = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exerciseName': exerciseName,
      'category': category,
      'weightKg': weightKg,
      'reps': reps,
      'estimated1RM': estimated1RM,
      'date': date.toIso8601String(),
      'isCompetitionLift': isCompetitionLift,
    };
  }

  factory PersonalRecord.fromMap(Map<String, dynamic> map) {
    return PersonalRecord(
      id: (map['id'] ?? '').toString(),
      exerciseName: (map['exerciseName'] ?? '').toString(),
      category: (map['category'] ?? 'General').toString(),
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 0,
      reps: (map['reps'] as num?)?.toInt() ?? 1,
      estimated1RM: (map['estimated1RM'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse((map['date'] ?? '').toString()) ?? DateTime.now(),
      isCompetitionLift: map['isCompetitionLift'] == true,
    );
  }
}

class Workout {
  final String id;
  final String userId;
  final String name;
  final String trainingMode; // Bodybuilding, Powerlifting, Hybrid
  final DateTime date;
  final List<WorkoutExercise> exercises;
  final int durationMinutes;
  final String? notes;
  final bool isTemplate;
  final DateTime createdAt;

  Workout({
    required this.id,
    required this.userId,
    required this.name,
    this.trainingMode = 'Bodybuilding',
    required this.date,
    required this.exercises,
    this.durationMinutes = 0,
    this.notes,
    this.isTemplate = false,
    required this.createdAt,
  });

  double get totalVolume {
    double volume = 0;
    for (var exercise in exercises) {
      for (var set in exercise.sets) {
        if (set.isCompleted && set.reps != null && set.weight != null) {
          volume += set.reps! * set.weight!;
        }
      }
    }
    return volume;
  }

  int get totalSets {
    return exercises.fold(0, (sum, ex) => sum + ex.sets.length);
  }

  int get completedSets {
    return exercises.fold(
      0,
      (sum, ex) => sum + ex.sets.where((s) => s.isCompleted).length,
    );
  }

  int get totalReps {
    int reps = 0;
    for (final ex in exercises) {
      for (final s in ex.sets) {
        if (s.isCompleted && s.reps != null) {
          reps += s.reps!;
        }
      }
    }
    return reps;
  }

  double get highestEstimated1RM {
    double best = 0;
    for (final ex in exercises) {
      if (ex.bestEstimated1RM > best) {
        best = ex.bestEstimated1RM;
      }
    }
    return best;
  }

  Workout copyWith({
    String? id,
    String? name,
    String? trainingMode,
    DateTime? date,
    List<WorkoutExercise>? exercises,
    int? durationMinutes,
    String? notes,
    bool? isTemplate,
  }) {
    return Workout(
      id: id ?? this.id,
      userId: userId,
      name: name ?? this.name,
      trainingMode: trainingMode ?? this.trainingMode,
      date: date ?? this.date,
      exercises: exercises ?? this.exercises,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      notes: notes ?? this.notes,
      isTemplate: isTemplate ?? this.isTemplate,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'trainingMode': trainingMode,
      'date': date.toIso8601String(),
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'durationMinutes': durationMinutes,
      'notes': notes,
      'isTemplate': isTemplate,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Workout.fromMap(Map<String, dynamic> map) {
    return Workout(
      id: (map['id'] ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      name: (map['name'] ?? 'Workout Session').toString(),
      trainingMode: (map['trainingMode'] ?? 'Bodybuilding').toString(),
      date: DateTime.tryParse((map['date'] ?? '').toString()) ?? DateTime.now(),
      exercises: (map['exercises'] as List<dynamic>?)
              ?.map((e) => WorkoutExercise.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 0,
      notes: map['notes']?.toString(),
      isTemplate: map['isTemplate'] == true,
      createdAt: DateTime.tryParse((map['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
