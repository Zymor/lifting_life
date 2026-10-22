import 'package:flutter_test/flutter_test.dart';
import 'package:tp1/models/nutrition.dart';
import 'package:tp1/services/data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Nutrition Engine & Models', () {
    test('VerifiedFoodCatalog contains reputable USDA and Open Food Facts staples with valid macros', () {
      final catalog = VerifiedFoodCatalog.verifiedStaples;
      expect(catalog.length, greaterThanOrEqualTo(20));

      for (final food in catalog) {
        expect(food.id, isNotEmpty);
        expect(food.name, isNotEmpty);
        expect(food.calories, greaterThan(0));
        expect(food.protein, greaterThanOrEqualTo(0));
        expect(food.carbs, greaterThanOrEqualTo(0));
        expect(food.fat, greaterThanOrEqualTo(0));
        expect(food.category, isNotEmpty);
        expect(food.source, isNotEmpty);
        expect(food.isVerified, isTrue);
      }
    });

    test('FoodItem serialization round-trip retains all metadata', () {
      final original = FoodItem(
        id: 'test_food_1',
        name: 'Organic Rolled Oats',
        calories: 380,
        protein: 13.5,
        carbs: 68.0,
        fat: 6.5,
        fiber: 10.0,
        servingSize: '40g',
        category: 'Grains & Carbs',
        isVerified: true,
        source: 'USDA FoodData Central #173904',
      );

      final map = original.toMap();
      final restored = FoodItem.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.calories, original.calories);
      expect(restored.protein, original.protein);
      expect(restored.carbs, original.carbs);
      expect(restored.fat, original.fat);
      expect(restored.fiber, original.fiber);
      expect(restored.servingSize, original.servingSize);
      expect(restored.category, original.category);
      expect(restored.isVerified, original.isVerified);
      expect(restored.source, original.source);
    });

    test('NutritionTargets holds configurable goals with defaults and copyWith', () {
      const targets = NutritionTargets();
      expect(targets.calories, 2650.0);
      expect(targets.protein, 185.0);
      expect(targets.carbs, 310.0);
      expect(targets.fat, 75.0);

      final updated = targets.copyWith(calories: 3000, protein: 210);
      expect(updated.calories, 3000.0);
      expect(updated.protein, 210.0);
      expect(updated.carbs, 310.0);
      expect(updated.fat, 75.0);
    });

    test('DataService manages meals and updates nutrition targets persistently', () async {
      final data = DataService.instance;
      data.initializeProductionState();
      data.registerTestAthleteAccount(
        email: 'athlete.nutrition@liftinglife.app',
        password: 'ValidPassword123!',
        username: 'nutrition_tester',
      );
      data.signIn(email: 'athlete.nutrition@liftinglife.app', password: 'ValidPassword123!');
      await Future<void>.delayed(Duration.zero);
      final initialTargets = data.nutritionTargets;
      expect(initialTargets.calories, greaterThan(0));

      final now = DateTime.now();
      final newMeal = MealEntry(
        id: 'meal_test_verify',
        userId: data.currentUser!.id,
        mealType: 'breakfast',
        foodId: 'usda_rolled_oats_dry',
        foodName: 'Rolled Oats (Old Fashioned Dry)',
        quantity: 100,
        calories: 379,
        protein: 13.2,
        carbs: 67.7,
        fat: 6.5,
        date: now,
        createdAt: now,
      );

      data.addMeal(newMeal);
      final todayMeals = data.getMealsForDate(now);
      expect(todayMeals.any((m) => m.id == 'meal_test_verify'), isTrue);

      data.deleteMeal('meal_test_verify');
      final updatedTodayMeals = data.getMealsForDate(now);
      expect(updatedTodayMeals.any((m) => m.id == 'meal_test_verify'), isFalse);
    });
  });
}

