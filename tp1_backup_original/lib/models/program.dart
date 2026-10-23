class ProgramExercisePrescription {
  final String exerciseName;
  final String muscleGroup;
  final int sets;
  final String repsRange;
  final double? targetRpe;
  final int? percentage1RM;
  final int restSeconds;
  final String intensityGuidance;
  final String movementPattern;

  const ProgramExercisePrescription({
    required this.exerciseName,
    required this.muscleGroup,
    required this.sets,
    required this.repsRange,
    this.targetRpe,
    this.percentage1RM,
    required this.restSeconds,
    required this.intensityGuidance,
    required this.movementPattern,
  });
}

class ProgramDay {
  final int dayNumber;
  final String title;
  final List<String> focusMuscles;
  final List<ProgramExercisePrescription> exercises;

  const ProgramDay({
    required this.dayNumber,
    required this.title,
    required this.focusMuscles,
    required this.exercises,
  });
}

class TrainingProgram {
  final String id;
  final String name;
  final String mode; // Bodybuilding or Powerlifting
  final String splitType;
  final String difficulty; // Beginner, Intermediate, Advanced
  final int weeksDuration;
  final int daysPerWeek;
  final String description;
  final String deloadGuidance;
  final String recoveryGuidance;
  final List<ProgramDay> schedule;
  final bool isCustom;
  final bool isFeatured;

  const TrainingProgram({
    required this.id,
    required this.name,
    required this.mode,
    required this.splitType,
    required this.difficulty,
    required this.weeksDuration,
    required this.daysPerWeek,
    required this.description,
    required this.deloadGuidance,
    required this.recoveryGuidance,
    required this.schedule,
    this.isCustom = false,
    this.isFeatured = false,
  });

  TrainingProgram copyWith({
    String? name,
    String? splitType,
    String? difficulty,
    int? weeksDuration,
    int? daysPerWeek,
    String? description,
    List<ProgramDay>? schedule,
    bool? isCustom,
    bool? isFeatured,
  }) {
    return TrainingProgram(
      id: id,
      name: name ?? this.name,
      mode: mode,
      splitType: splitType ?? this.splitType,
      difficulty: difficulty ?? this.difficulty,
      weeksDuration: weeksDuration ?? this.weeksDuration,
      daysPerWeek: daysPerWeek ?? this.daysPerWeek,
      description: description ?? this.description,
      deloadGuidance: deloadGuidance,
      recoveryGuidance: recoveryGuidance,
      schedule: schedule ?? this.schedule,
      isCustom: isCustom ?? this.isCustom,
      isFeatured: isFeatured ?? this.isFeatured,
    );
  }
}

