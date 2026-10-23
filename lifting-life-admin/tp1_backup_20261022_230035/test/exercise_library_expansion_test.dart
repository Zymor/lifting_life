import 'package:flutter_test/flutter_test.dart';
import 'package:tp1/data/exercise_seed_data.dart';

void main() {
  group('Exercise Library 300+ Expansion Verification', () {
    final exercises = ExerciseSeedData.build200PlusExercises();

    test('Library contains over 300 unique exercises', () {
      final names = <String, int>{};
      for (final e in exercises) {
        final key = e.name.toLowerCase().trim();
        names[key] = (names[key] ?? 0) + 1;
      }
      final dupes = names.entries.where((e) => e.value > 1).map((e) => e.key).toList();
      expect(dupes, isEmpty, reason: 'Duplicate exercise names found: $dupes');
      expect(exercises.length, greaterThanOrEqualTo(300));
    });

    test('All 12 required muscle categories are represented', () {
      const requiredCategories = [
        'Chest',
        'Back',
        'Shoulders',
        'Biceps',
        'Triceps',
        'Quadriceps',
        'Hamstrings',
        'Glutes',
        'Calves',
        'Core',
        'Full-Body',
        'Forearms',
      ];

      final existingCategories = exercises.map((e) => e.category).toSet();
      for (final cat in requiredCategories) {
        expect(existingCategories.contains(cat), isTrue, reason: 'Category $cat must be present');
        final count = exercises.where((e) => e.category == cat).length;
        expect(count, greaterThanOrEqualTo(5), reason: 'Category $cat should have at least 5 exercises');
      }
    });

    test('Diverse equipment types are supported', () {
      const expectedEquipment = [
        'Barbell',
        'Dumbbell',
        'Cable',
        'Machine',
        'Bodyweight',
        'Resistance Band',
      ];

      final equipmentInUse = exercises.map((e) => e.equipment).toSet();
      for (final eq in expectedEquipment) {
        expect(equipmentInUse.contains(eq), isTrue, reason: 'Equipment $eq must be represented');
      }
    });

    test('Every exercise contains required instructions, muscles, and safety cues', () {
      for (final ex in exercises) {
        expect(ex.id, isNotEmpty);
        expect(ex.name, isNotEmpty);
        expect(ex.category, isNotEmpty);
        expect(ex.primaryMuscles, isNotEmpty);
        expect(ex.instructions, isNotEmpty);
        expect(ex.techniqueTips, isNotEmpty);
        expect(ex.commonMistakes, isNotEmpty);
        expect(ex.movementPattern, isNotEmpty);
        // Ensure no fake 3D asset paths are claimed without actual files
        expect(ex.has3dAnimation, isFalse);
        expect(ex.glbAssetPath, isNull);
      }
    });
  });
}
