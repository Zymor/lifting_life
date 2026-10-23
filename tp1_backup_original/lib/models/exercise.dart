class Exercise {
  final String id;
  final String name;
  final String category; // Chest, Back, Shoulders, Biceps, Triceps, Forearms, Quadriceps, Hamstrings, Glutes, Calves, Core, Full-Body
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final String equipment; // Barbell, Dumbbell, Cable, Machine, Bodyweight, Resistance Band
  final String difficulty; // Beginner, Intermediate, Advanced
  final int suggestedSets;
  final String suggestedReps;
  final int restSeconds;
  final List<String> instructions;
  final List<String> techniqueTips;
  final List<String> commonMistakes;
  final List<String> alternativeNames;
  final String movementPattern; // squat, bench, deadlift, hinge, overhead_press, curl, pulldown, pullup, row, leg_press, lunge, lateral_raise, pushdown, crunch, calf_raise, dip, fly
  final String startPositionDesc;
  final String endPositionDesc;
  final String movementPathDesc;
  final String? glbAssetPath;
  final bool has3dAnimation;
  final bool isPowerliftingCompetition;
  final bool isPowerliftingVariation;

  const Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.equipment,
    required this.difficulty,
    this.suggestedSets = 3,
    this.suggestedReps = '8-12',
    this.restSeconds = 90,
    required this.instructions,
    required this.techniqueTips,
    required this.commonMistakes,
    required this.alternativeNames,
    required this.movementPattern,
    required this.startPositionDesc,
    required this.endPositionDesc,
    required this.movementPathDesc,
    this.glbAssetPath,
    this.has3dAnimation = false,
    this.isPowerliftingCompetition = false,
    this.isPowerliftingVariation = false,
  });
}

