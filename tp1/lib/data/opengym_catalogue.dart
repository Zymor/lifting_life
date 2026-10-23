import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/exercise.dart';

/// Adapter for the bundled OpenGym exercise catalogue.
class OpenGymCatalogue {
  static Future<List<Exercise>> load() async {
    final text = await rootBundle.loadString(
      'assets/data/opengym_catalogue.json',
    );
    final rows = (jsonDecode(text.replaceFirst('\uFEFF', '')) as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    // Map parent ID -> row for fast lookup of variantOf
    final byId = {for (final row in rows) row['id'] as String: row};

    Map<String, dynamic> resolve(Map<String, dynamic> row, Set<String> seen) {
      final id = row['id'] as String;
      if (!seen.add(id)) {
        throw FormatException('Circular exercise variant: $id');
      }
      if (row['name'] != null) return row;
      final parent = byId[row['variantOf']];
      if (parent == null) {
        throw FormatException('Missing exercise variant: $id');
      }
      return {...resolve(parent, seen), ...row};
    }

    return rows.map((row) => fromMap(resolve(row, {}))).toList();
  }

  static Exercise fromMap(Map<String, dynamic> row) {
    final rawId = row['id'] as String? ?? '0000';
    final target = (row['target'] as String? ?? '').toLowerCase();
    final body = (row['bodyPart'] as String? ?? '').toLowerCase();
    final rawCategory = (row['category'] as String? ?? '').toLowerCase();

    // Precise category mapping across all 12 canonical muscle categories
    final category = _resolveCategory(target, body);

    final rawEquipment = (row['equipment'] as String? ?? 'other').toLowerCase();
    final equipment = _resolveEquipment(rawEquipment);
    final steps = List<String>.from(row['instructions'] ?? const []);
    final desc = row['description'] as String? ?? '';
    final secondary = List<String>.from(row['secondaryMuscles'] ?? const []);
    final femaleVar = row['femaleVariant'] as String?;

    // Determine difficulty
    final difficulty = _resolveDifficulty(rawCategory, rawEquipment, row['name'] as String? ?? '');

    // Determine resistance type
    final resistanceType = _resolveResistanceType(rawEquipment, rawCategory);

    final primaryName = target.isNotEmpty ? title(target) : category;
    final secondaryNames = secondary.map((m) => title(m)).toList();

    return Exercise(
      id: 'opengym_$rawId',
      name: title(row['name'] as String? ?? 'Exercise $rawId'),
      category: category,
      primaryMuscles: [primaryName],
      secondaryMuscles: secondaryNames,
      equipment: equipment,
      difficulty: difficulty,
      suggestedSets: 3,
      suggestedReps: rawCategory == 'cardio' ? '15-20 min' : (rawCategory == 'plyometrics' ? '10-15' : '8-12'),
      restSeconds: rawCategory == 'cardio' ? 45 : 90,
      instructions: steps,
      techniqueTips: [
        if (desc.isNotEmpty) desc,
        'Maintain steady cadence throughout positive and negative portions of the movement.',
      ],
      commonMistakes: const [
        'Using excessive momentum or jerking weights.',
        'Shortening the full active range of motion.',
      ],
      alternativeNames: const [],
      movementPattern: _resolveMovementPattern(target, rawEquipment, category),
      startPositionDesc: steps.isNotEmpty ? steps.first : 'Assume starting position with proper alignment and brace core.',
      endPositionDesc: steps.length > 2 ? steps[steps.length ~/ 2] : 'Contract target muscles at peak excursion before controlled return.',
      movementPathDesc: 'Controlled concentric effort followed by deliberate eccentric resistance.',
      glbAssetPath: null,
      has3dAnimation: false,
      isPowerliftingCompetition: false,
      isPowerliftingVariation: false,
      description: desc,
      mediaUrl: 'exercise-media/clip/$rawId.mp4',
      thumbnailUrl: 'exercise-media/still/$rawId.webp',
      mediaType: 'video',
      resistanceType: resistanceType,
      source: 'opengym',
      femaleVariantId: femaleVar != null ? 'opengym_$femaleVar' : null,
    );
  }

  static String _resolveCategory(String target, String body) {
    // 1. Direct Target Match
    if (target == 'pectorals') return 'Chest';
    if (target == 'lats' || target == 'upper back' || target == 'traps' || target == 'spine') return 'Back';
    if (target == 'delts' || target == 'rotator cuff' || target == 'levator scapulae' || target == 'sternocleidomastoid') return 'Shoulders';
    if (target == 'biceps' || target == 'brachialis') return 'Biceps';
    if (target == 'triceps') return 'Triceps';
    if (target == 'forearms' || target == 'wrist flexors' || target == 'wrist extensors') return 'Forearms';
    if (target == 'quads' || target == 'quadriceps') return 'Quadriceps';
    if (target == 'hamstrings') return 'Hamstrings';
    if (target == 'glutes' || target == 'abductors' || target == 'adductors') return 'Glutes';
    if (target == 'calves' || target == 'soleus' || target == 'shins') return 'Calves';
    if (target == 'abs' || target == 'core' || target == 'obliques' || target == 'serratus anterior') return 'Core';
    if (target == 'cardiovascular system') return 'Full-Body';

    // 2. Body Part Fallback
    if (body == 'chest') return 'Chest';
    if (body == 'back') return 'Back';
    if (body == 'shoulders' || body == 'neck') return 'Shoulders';
    if (body == 'waist') return 'Core';
    if (body == 'lower legs') return 'Calves';
    if (body == 'upper legs') return 'Quadriceps';
    if (body == 'lower arms') return 'Forearms';
    if (body == 'upper arms') return 'Triceps';
    if (body == 'cardio' || body == 'full body') return 'Full-Body';

    return 'Full-Body';
  }

  static String _resolveEquipment(String raw) {
    const map = {
      'body weight': 'Bodyweight',
      'band': 'Resistance Band',
      'barbell': 'Barbell',
      'olympic barbell': 'Olympic Barbell',
      'ez barbell': 'EZ Barbell',
      'dumbbell': 'Dumbbell',
      'cable': 'Cable',
      'leverage machine': 'Machine',
      'smith machine': 'Smith Machine',
      'kettlebell': 'Kettlebell',
      'medicine ball': 'Medicine Ball',
      'stability ball': 'Stability Ball',
      'bosu ball': 'Bosu Ball',
      'wheel roller': 'Ab Wheel',
      'rope': 'Battle Rope',
      'assisted': 'Assisted Machine',
      'weighted': 'Weighted Bodyweight',
      'trap bar': 'Hex Bar',
      'stationary bike': 'Stationary Bike',
      'hammer': 'Sledgehammer',
      'sled machine': 'Sled',
      'roller': 'Foam Roller',
      'skierg machine': 'SkiErg',
      'elliptical machine': 'Elliptical',
    };
    return map[raw] ?? title(raw);
  }

  static String _resolveDifficulty(String cat, String eq, String name) {
    final lowerName = name.toLowerCase();
    if (cat == 'olympic' ||
        lowerName.contains('clean') ||
        lowerName.contains('snatch') ||
        lowerName.contains('muscle up') ||
        lowerName.contains('planche') ||
        lowerName.contains('dragon flag') ||
        lowerName.contains('pistol squat')) {
      return 'Advanced';
    }
    if (cat == 'stretching' ||
        cat == 'mobility' ||
        cat == 'rehab' ||
        eq == 'body weight' ||
        lowerName.contains('stretch') ||
        lowerName.contains('circle') ||
        lowerName.contains('curl')) {
      return 'Beginner';
    }
    return 'Intermediate';
  }

  static String _resolveResistanceType(String eq, String cat) {
    if (cat == 'cardio') return 'cardio';
    if (eq.contains('barbell') || eq.contains('smith') || eq.contains('olympic')) return 'per_side';
    if (eq.contains('dumbbell') || eq.contains('kettlebell')) return 'dumbbell';
    if (eq.contains('cable') || eq.contains('machine') || eq.contains('assisted')) return 'single_stack';
    if (eq.contains('body weight') || eq.contains('weighted')) return 'bodyweight';
    if (eq.contains('band')) return 'band';
    return 'off';
  }

  static String _resolveMovementPattern(String target, String eq, String cat) {
    final t = target.toLowerCase();
    if (t.contains('pectoral') || t.contains('chest')) return 'bench';
    if (t.contains('quad') || t.contains('leg')) return 'squat';
    if (t.contains('hamstring') || t.contains('glute')) return 'deadlift';
    if (t.contains('lat') || t.contains('back')) return 'row';
    if (t.contains('delt') || t.contains('shoulder')) return 'overhead_press';
    if (t.contains('bicep')) return 'curl';
    if (t.contains('tricep')) return 'pushdown';
    if (t.contains('calf')) return 'calf_raise';
    if (t.contains('abs') || t.contains('core')) return 'crunch';
    return 'general';
  }

  static String title(String text) => text
      .split(' ')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');

  /// Preserve tp1 IDs and richer existing demonstrations for exact name matches.
  static List<Exercise> merge(
    List<Exercise> existing,
    List<Exercise> incoming,
  ) {
    final names = existing.map((e) => e.name.trim().toLowerCase()).toSet();
    final ids = existing.map((e) => e.id).toSet();
    return [
      ...existing,
      ...incoming.where(
        (e) => ids.add(e.id) && names.add(e.name.trim().toLowerCase()),
      ),
    ];
  }
}
