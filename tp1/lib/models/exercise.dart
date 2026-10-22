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
  final String? description;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? mediaType; // '3d', 'video', 'image', 'none'
  final String? resistanceType; // 'per_side', 'single_stack', 'dumbbell', 'bodyweight', 'cardio', 'off'
  final String source; // 'lifting_life', 'opengym'
  final String? femaleVariantId;

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
    this.description,
    this.mediaUrl,
    this.thumbnailUrl,
    this.mediaType,
    this.resistanceType,
    this.source = 'lifting_life',
    this.femaleVariantId,
  });

  /// Inferred or explicit resistance loading type for plate calculations and equipment options.
  String get computedResistanceType {
    if (resistanceType != null && resistanceType!.isNotEmpty) {
      return resistanceType!;
    }
    final eqLower = equipment.toLowerCase();
    if (eqLower.contains('barbell') || eqLower.contains('smith')) {
      return 'per_side';
    } else if (eqLower.contains('dumbbell')) {
      return 'dumbbell';
    } else if (eqLower.contains('cable') || eqLower.contains('machine') || eqLower.contains('stack')) {
      return 'single_stack';
    } else if (eqLower.contains('bodyweight') || eqLower.contains('body weight')) {
      return 'bodyweight';
    } else if (eqLower.contains('band')) {
      return 'band';
    } else if (category.toLowerCase() == 'cardio' || eqLower.contains('bike') || eqLower.contains('run')) {
      return 'cardio';
    }
    return 'off';
  }

  /// True if plate calculations (barbell or plate-loaded stack) are relevant.
  bool get supportsPlateLoading {
    final type = computedResistanceType;
    return type == 'per_side' || type == 'single_stack';
  }

  /// Descriptive overview text with fallback to technique cues.
  String get displayDescription {
    if (description != null && description!.trim().isNotEmpty) {
      return description!.trim();
    }
    if (techniqueTips.isNotEmpty) {
      return techniqueTips.first;
    }
    return 'Targeted $category movement utilizing $equipment. Focus on controlled eccentric tempo, full active range of motion, and stable posture.';
  }

  /// Whether this exercise is from the external OpenGym library.
  bool get isOpenGym => source == 'opengym' || id.startsWith('opengym_');
}

