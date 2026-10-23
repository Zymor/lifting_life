import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/nutrition.dart';
import '../services/data_service.dart';

class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DataService.instance,
      builder: (context, _) {
        final dataService = DataService.instance;
        final today = DateTime.now();
        final meals = dataService.getMealsForDate(today);

        double totalCalories = meals.fold(
          0,
          (sum, meal) => sum + meal.calories,
        );
        double totalProtein = meals.fold(0, (sum, meal) => sum + meal.protein);
        double totalCarbs = meals.fold(0, (sum, meal) => sum + meal.carbs);
        double totalFat = meals.fold(0, (sum, meal) => sum + meal.fat);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Nutrition & Fueling'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _showAddMealDialog(context, dataService),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daily Hypertrophy & Strength Macros',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _MacroRow(
                          'Calories',
                          totalCalories,
                          2650,
                          'kcal',
                          AppTheme.powerliftingAmber,
                        ),
                        const SizedBox(height: 12),
                        _MacroRow(
                          'Protein',
                          totalProtein,
                          185,
                          'g',
                          AppTheme.primaryColor,
                        ),
                        const SizedBox(height: 12),
                        _MacroRow(
                          'Carbs',
                          totalCarbs,
                          310,
                          'g',
                          AppTheme.secondaryAccent,
                        ),
                        const SizedBox(height: 12),
                        _MacroRow(
                          'Fat',
                          totalFat,
                          75,
                          'g',
                          AppTheme.musclePrimaryRed,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Meals Logged Today',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                ...meals.map(
                  (meal) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryColor.withValues(
                          alpha: 0.2,
                        ),
                        child: Icon(
                          _getMealIcon(meal.mealType),
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      title: Text(
                        meal.foodName,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '${meal.quantity.toInt()}g • ${meal.calories.toInt()} kcal',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      trailing: Text(
                        '${meal.protein.toInt()}g P / ${meal.carbs.toInt()}g C / ${meal.fat.toInt()}g F',
                        style: const TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddMealDialog(BuildContext context, DataService data) {
    final nameCtrl = TextEditingController(text: 'Post-Workout Whey & Banana');
    final calCtrl = TextEditingController(text: '340');
    final protCtrl = TextEditingController(text: '38');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Log Nutrition Meal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Food / Meal Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: calCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Calories (kcal)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: protCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Protein (g)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final now = DateTime.now();
              data.addMeal(
                MealEntry(
                  id: data.newId(),
                  userId: data.currentUser?.id ?? 'u_owner_alex',
                  mealType: 'snack',
                  foodId: 'custom_meal',
                  foodName: nameCtrl.text.trim(),
                  quantity: 250,
                  calories: double.tryParse(calCtrl.text) ?? 300,
                  protein: double.tryParse(protCtrl.text) ?? 30,
                  carbs: 35,
                  fat: 6,
                  date: now,
                  createdAt: now,
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Log Meal'),
          ),
        ],
      ),
    );
  }

  IconData _getMealIcon(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return Icons.coffee;
      case 'lunch':
        return Icons.lunch_dining;
      case 'dinner':
        return Icons.dinner_dining;
      case 'snack':
        return Icons.cookie;
      default:
        return Icons.restaurant;
    }
  }
}

class _MacroRow extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final String unit;
  final Color color;

  const _MacroRow(this.label, this.value, this.target, this.unit, this.color);

  @override
  Widget build(BuildContext context) {
    final progress = (value / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
            Text(
              '${value.toInt()} / ${target.toInt()} $unit',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: AppTheme.borderColor,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
        ),
      ],
    );
  }
}
