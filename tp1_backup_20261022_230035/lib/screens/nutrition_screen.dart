import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/nutrition.dart';
import '../services/data_service.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  DateTime _selectedDate = DateTime.now();

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              onPrimary: AppTheme.backgroundColor,
              surface: AppTheme.surfaceColor,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DataService.instance,
      builder: (context, _) {
        final data = DataService.instance;
        final targets = data.nutritionTargets;
        final meals = data.getMealsForDate(_selectedDate);

        double totalCalories = meals.fold(0.0, (sum, m) => sum + m.calories);
        double totalProtein = meals.fold(0.0, (sum, m) => sum + m.protein);
        double totalCarbs = meals.fold(0.0, (sum, m) => sum + m.carbs);
        double totalFat = meals.fold(0.0, (sum, m) => sum + m.fat);

        final double caloriesRemaining = targets.calories - totalCalories;

        final isToday = _isSameDay(_selectedDate, DateTime.now());

        return Scaffold(
          appBar: AppBar(
            title: const Text('Nutrition & Fueling'),
            actions: [
              IconButton(
                tooltip: 'Configure Macro Targets',
                icon: const Icon(Icons.tune),
                onPressed: () => _showEditTargetsDialog(context, data, targets),
              ),
              IconButton(
                tooltip: 'Log Food',
                icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor),
                onPressed: () => _showLogFoodModal(context, data),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Bar Selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: AppTheme.textPrimary),
                        onPressed: () => _changeDate(-1),
                      ),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: AppTheme.primaryColor),
                              const SizedBox(width: 8),
                              Text(
                                isToday
                                    ? 'Today (${_formatDate(_selectedDate)})'
                                    : _formatDate(_selectedDate),
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: AppTheme.textPrimary),
                        onPressed: () => _changeDate(1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Daily Macro Overview Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor.withValues(alpha: 0.12),
                        AppTheme.surfaceColor,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CALORIE BUDGET',
                                style: TextStyle(
                                  color: AppTheme.textTertiary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '${totalCalories.toInt()}',
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    ' / ${targets.calories.toInt()} kcal',
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: caloriesRemaining >= 0
                                  ? AppTheme.primaryColor.withValues(alpha: 0.15)
                                  : AppTheme.errorColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: caloriesRemaining >= 0
                                    ? AppTheme.primaryColor.withValues(alpha: 0.4)
                                    : AppTheme.errorColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  caloriesRemaining >= 0
                                      ? '${caloriesRemaining.toInt()} left'
                                      : '${(-caloriesRemaining).toInt()} over',
                                  style: TextStyle(
                                    color: caloriesRemaining >= 0 ? AppTheme.primaryColor : AppTheme.errorColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                const Text(
                                  'net calories',
                                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (totalCalories / (targets.calories > 0 ? targets.calories : 1)).clamp(0.0, 1.0),
                          backgroundColor: AppTheme.borderColor,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            caloriesRemaining >= 0 ? AppTheme.primaryColor : AppTheme.errorColor,
                          ),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Macronutrient Columns (Protein, Carbs, Fat)
                      Row(
                        children: [
                          Expanded(
                            child: _MacroColumn(
                              name: 'Protein',
                              current: totalProtein,
                              target: targets.protein,
                              unit: 'g',
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MacroColumn(
                              name: 'Carbs',
                              current: totalCarbs,
                              target: targets.carbs,
                              unit: 'g',
                              color: AppTheme.secondaryAccent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MacroColumn(
                              name: 'Fat',
                              current: totalFat,
                              target: targets.fat,
                              unit: 'g',
                              color: AppTheme.powerliftingAmber,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Meal Categories Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Daily Meals & Food Diary',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showLogFoodModal(context, data),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Meal'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                _buildMealCategorySection(context, data, meals, 'breakfast', 'Breakfast', Icons.free_breakfast),
                _buildMealCategorySection(context, data, meals, 'lunch', 'Lunch', Icons.lunch_dining),
                _buildMealCategorySection(context, data, meals, 'dinner', 'Dinner', Icons.dinner_dining),
                _buildMealCategorySection(context, data, meals, 'snack', 'Snacks & Supplements', Icons.cookie),

                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMealCategorySection(
    BuildContext context,
    DataService data,
    List<MealEntry> allMeals,
    String typeKey,
    String title,
    IconData icon,
  ) {
    final sectionMeals = allMeals.where((m) => m.mealType == typeKey).toList();
    final double sectionCals = sectionMeals.fold(0.0, (s, m) => s + m.calories);
    final double sectionProt = sectionMeals.fold(0.0, (s, m) => s + m.protein);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  '${sectionCals.toInt()} kcal • ${sectionProt.toInt()}g P',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 18, color: AppTheme.primaryColor),
                  tooltip: 'Log to $title',
                  onPressed: () => _showLogFoodModal(context, data, preselectedMealType: typeKey),
                ),
              ],
            ),
          ),
          if (sectionMeals.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No food logged for $title yet.',
                  style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                ),
              ),
            )
          else ...[
            const Divider(color: AppTheme.borderColor, height: 1),
            ...sectionMeals.map(
              (meal) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                title: Text(
                  meal.foodName,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  '${meal.quantity.toInt()}g • ${meal.calories.toInt()} kcal',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${meal.protein.toInt()}g P / ${meal.carbs.toInt()}g C / ${meal.fat.toInt()}g F',
                      style: const TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.textTertiary),
                      tooltip: 'Remove',
                      onPressed: () => data.deleteMeal(meal.id),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showLogFoodModal(BuildContext context, DataService data, {String preselectedMealType = 'breakfast'}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LogFoodSheet(
        data: data,
        date: _selectedDate,
        initialMealType: preselectedMealType,
      ),
    );
  }

  void _showEditTargetsDialog(BuildContext context, DataService data, NutritionTargets current) {
    final calCtrl = TextEditingController(text: current.calories.toInt().toString());
    final protCtrl = TextEditingController(text: current.protein.toInt().toString());
    final carbsCtrl = TextEditingController(text: current.carbs.toInt().toString());
    final fatCtrl = TextEditingController(text: current.fat.toInt().toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Configure Daily Macro Targets'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: calCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target Calories (kcal)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: protCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target Protein (g)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: carbsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target Carbohydrates (g)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: fatCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target Dietary Fat (g)'),
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
              final newTargets = current.copyWith(
                calories: double.tryParse(calCtrl.text) ?? current.calories,
                protein: double.tryParse(protCtrl.text) ?? current.protein,
                carbs: double.tryParse(carbsCtrl.text) ?? current.carbs,
                fat: double.tryParse(fatCtrl.text) ?? current.fat,
              );
              data.updateNutritionTargets(newTargets);
              Navigator.pop(ctx);
            },
            child: const Text('Save Targets'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _MacroColumn extends StatelessWidget {
  final String name;
  final double current;
  final double target;
  final String unit;
  final Color color;

  const _MacroColumn({
    required this.name,
    required this.current,
    required this.target,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (current / (target > 0 ? target : 1)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${current.toInt()} / ${target.toInt()}$unit',
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.borderColor,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogFoodSheet extends StatefulWidget {
  final DataService data;
  final DateTime date;
  final String initialMealType;

  const _LogFoodSheet({
    required this.data,
    required this.date,
    required this.initialMealType,
  });

  @override
  State<_LogFoodSheet> createState() => _LogFoodSheetState();
}

class _LogFoodSheetState extends State<_LogFoodSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _selectedMealType;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  // Custom food controllers
  final _customNameCtrl = TextEditingController();
  final _customCalCtrl = TextEditingController();
  final _customProtCtrl = TextEditingController();
  final _customCarbsCtrl = TextEditingController();
  final _customFatCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedMealType = widget.initialMealType;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customNameCtrl.dispose();
    _customCalCtrl.dispose();
    _customProtCtrl.dispose();
    _customCarbsCtrl.dispose();
    _customFatCtrl.dispose();
    super.dispose();
  }

  void _logFoodItem(FoodItem food, double grams) {
    final factor = grams / 100.0;
    final entry = MealEntry(
      id: widget.data.newId(),
      userId: widget.data.currentUser?.id ?? 'lifter_local',
      mealType: _selectedMealType,
      foodId: food.id,
      foodName: food.name,
      quantity: grams,
      calories: food.calories * factor,
      protein: food.protein * factor,
      carbs: food.carbs * factor,
      fat: food.fat * factor,
      date: widget.date,
      createdAt: DateTime.now(),
    );
    widget.data.addMeal(entry);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Logged ${entry.foodName} (${grams.toInt()}g) to ${_selectedMealType.toUpperCase()}'),
        backgroundColor: AppTheme.cardColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final foodList = widget.data.foodLibrary.where((food) {
      final matchesSearch = food.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCat = _selectedCategory == 'All' || food.category == _selectedCategory;
      return matchesSearch && matchesCat;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Log Food & Nutrition',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Meal Type Selector Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _MealTypeChip(
                  label: 'Breakfast',
                  selected: _selectedMealType == 'breakfast',
                  onTap: () => setState(() => _selectedMealType = 'breakfast'),
                ),
                const SizedBox(width: 6),
                _MealTypeChip(
                  label: 'Lunch',
                  selected: _selectedMealType == 'lunch',
                  onTap: () => setState(() => _selectedMealType = 'lunch'),
                ),
                const SizedBox(width: 6),
                _MealTypeChip(
                  label: 'Dinner',
                  selected: _selectedMealType == 'dinner',
                  onTap: () => setState(() => _selectedMealType = 'dinner'),
                ),
                const SizedBox(width: 6),
                _MealTypeChip(
                  label: 'Snacks',
                  selected: _selectedMealType == 'snack',
                  onTap: () => setState(() => _selectedMealType = 'snack'),
                ),
              ],
            ),
          ),

          TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.textSecondary,
            tabs: const [
              Tab(text: 'Verified Food Library (USDA)'),
              Tab(text: 'Quick Add Custom'),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: SEARCH VERIFIED FOODS
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                      child: TextField(
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                          hintText: 'Search whole foods, meats, grains...',
                          filled: true,
                          fillColor: AppTheme.cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.borderColor),
                          ),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    // Category filter row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          'All',
                          'Poultry & Meat',
                          'Fish & Seafood',
                          'Eggs & Dairy',
                          'Grains & Carbs',
                          'Fruits & Veggies',
                          'Fats & Nuts',
                          'Supplements',
                        ].map((cat) {
                          final isSel = _selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(cat, style: TextStyle(fontSize: 11, color: isSel ? AppTheme.backgroundColor : AppTheme.textPrimary)),
                              selected: isSel,
                              selectedColor: AppTheme.primaryColor,
                              backgroundColor: AppTheme.cardColor,
                              onSelected: (_) => setState(() => _selectedCategory = cat),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    Expanded(
                      child: foodList.isEmpty
                          ? const Center(
                              child: Text(
                                'No matching verified foods found.',
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: foodList.length,
                              separatorBuilder: (_, _) => const Divider(color: AppTheme.borderColor, height: 1),
                              itemBuilder: (ctx, i) {
                                final food = foodList[i];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          food.name,
                                          style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      if (food.isVerified)
                                        const Tooltip(
                                          message: 'Verified Nutritional Data (USDA/Open Food Facts)',
                                          child: Icon(Icons.verified, size: 16, color: AppTheme.primaryColor),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${food.calories.toInt()} kcal per 100g • ${food.protein.toStringAsFixed(1)}g P / ${food.carbs.toStringAsFixed(1)}g C / ${food.fat.toStringAsFixed(1)}g F\n${food.source}',
                                    style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                                  ),
                                  trailing: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      minimumSize: Size.zero,
                                    ),
                                    onPressed: () => _showPortionDialog(food),
                                    child: const Text('Log', style: TextStyle(fontSize: 12)),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),

                // TAB 2: QUICK ADD CUSTOM FOOD
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create & Log Custom Food',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Values will be stored locally and available in your food library.',
                        style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _customNameCtrl,
                        decoration: const InputDecoration(labelText: 'Food or Meal Name (e.g. Grandma Beef Stew)'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customCalCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Calories (kcal / 100g)'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _customProtCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Protein (g / 100g)'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customCarbsCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Carbohydrates (g / 100g)'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _customFatCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Fat (g / 100g)'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Save & Choose Portion'),
                          onPressed: () {
                            final name = _customNameCtrl.text.trim();
                            if (name.isEmpty) return;
                            final customFood = FoodItem(
                              id: widget.data.newId(),
                              name: name,
                              calories: double.tryParse(_customCalCtrl.text) ?? 200,
                              protein: double.tryParse(_customProtCtrl.text) ?? 20,
                              carbs: double.tryParse(_customCarbsCtrl.text) ?? 20,
                              fat: double.tryParse(_customFatCtrl.text) ?? 5,
                              category: 'Custom Lifter Entry',
                              isVerified: false,
                              source: 'User Entry',
                            );
                            widget.data.addCustomFood(customFood);
                            _showPortionDialog(customFood);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPortionDialog(FoodItem food) {
    final portionCtrl = TextEditingController(text: '150');
    double currentPortion = 150.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final factor = currentPortion / 100.0;
          final cals = (food.calories * factor).toInt();
          final prot = (food.protein * factor).toStringAsFixed(1);
          final carbs = (food.carbs * factor).toStringAsFixed(1);
          final fat = (food.fat * factor).toStringAsFixed(1);

          return AlertDialog(
            backgroundColor: AppTheme.surfaceColor,
            title: Text('Portion Size: ${food.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: portionCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Serving Quantity (Grams)',
                    suffixText: 'g',
                  ),
                  onChanged: (val) {
                    final p = double.tryParse(val);
                    if (p != null) {
                      setDialogState(() => currentPortion = p);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$cals kcal',
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$prot g Protein  •  $carbs g Carbs  •  $fat g Fat',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _logFoodItem(food, currentPortion);
                },
                child: const Text('Log Meal'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MealTypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MealTypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryColor : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppTheme.primaryColor : AppTheme.borderColor,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppTheme.backgroundColor : AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}
