class FoodItem {
  final String id;
  final String name;
  final double calories; // per 100g
  final double protein; // per 100g
  final double carbs; // per 100g
  final double fat; // per 100g
  final double fiber; // per 100g
  final String servingSize;
  final String category;
  final bool isVerified;
  final String source;

  FoodItem({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0,
    this.servingSize = '100g',
    this.category = 'General',
    this.isVerified = true,
    this.source = 'USDA FoodData Central',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'servingSize': servingSize,
      'category': category,
      'isVerified': isVerified,
      'source': source,
    };
  }

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      calories: map['calories']?.toDouble() ?? 0,
      protein: map['protein']?.toDouble() ?? 0,
      carbs: map['carbs']?.toDouble() ?? 0,
      fat: map['fat']?.toDouble() ?? 0,
      fiber: map['fiber']?.toDouble() ?? 0,
      servingSize: map['servingSize'] ?? '100g',
      category: map['category'] ?? 'General',
      isVerified: map['isVerified'] ?? true,
      source: map['source'] ?? 'USDA FoodData Central',
    );
  }
}

class MealEntry {
  final String id;
  final String userId;
  final String mealType; // breakfast, lunch, dinner, snack
  final String foodId;
  final String foodName;
  final double quantity; // in grams
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final DateTime date;
  final DateTime createdAt;

  MealEntry({
    required this.id,
    required this.userId,
    required this.mealType,
    required this.foodId,
    required this.foodName,
    required this.quantity,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.date,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'mealType': mealType,
      'foodId': foodId,
      'foodName': foodName,
      'quantity': quantity,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MealEntry.fromMap(Map<String, dynamic> map) {
    return MealEntry(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      mealType: map['mealType'] ?? '',
      foodId: map['foodId'] ?? '',
      foodName: map['foodName'] ?? '',
      quantity: map['quantity']?.toDouble() ?? 0,
      calories: map['calories']?.toDouble() ?? 0,
      protein: map['protein']?.toDouble() ?? 0,
      carbs: map['carbs']?.toDouble() ?? 0,
      fat: map['fat']?.toDouble() ?? 0,
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class NutritionTargets {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double waterMl;

  const NutritionTargets({
    this.calories = 2650,
    this.protein = 185,
    this.carbs = 310,
    this.fat = 75,
    this.waterMl = 3500,
  });

  NutritionTargets copyWith({
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? waterMl,
  }) {
    return NutritionTargets(
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      waterMl: waterMl ?? this.waterMl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'waterMl': waterMl,
    };
  }

  factory NutritionTargets.fromMap(Map<String, dynamic> map) {
    return NutritionTargets(
      calories: (map['calories'] as num?)?.toDouble() ?? 2650,
      protein: (map['protein'] as num?)?.toDouble() ?? 185,
      carbs: (map['carbs'] as num?)?.toDouble() ?? 310,
      fat: (map['fat'] as num?)?.toDouble() ?? 75,
      waterMl: (map['waterMl'] as num?)?.toDouble() ?? 3500,
    );
  }
}

/// Curated reference database of verified whole foods and fitness staples
/// derived from USDA FoodData Central and Open Food Facts.
class VerifiedFoodCatalog {
  static final List<FoodItem> verifiedStaples = [
    // Poultry & Meats
    FoodItem(
      id: 'usda_chicken_breast_raw',
      name: 'Chicken Breast (Boneless, Skinless, Raw)',
      calories: 120,
      protein: 22.5,
      carbs: 0.0,
      fat: 2.6,
      category: 'Poultry & Meat',
      source: 'USDA FoodData Central #171077',
    ),
    FoodItem(
      id: 'usda_chicken_breast_grilled',
      name: 'Chicken Breast (Grilled / Roasted)',
      calories: 165,
      protein: 31.0,
      carbs: 0.0,
      fat: 3.6,
      category: 'Poultry & Meat',
      source: 'USDA FoodData Central #171477',
    ),
    FoodItem(
      id: 'usda_beef_lean_93_7',
      name: 'Lean Ground Beef (93/7 Raw)',
      calories: 152,
      protein: 21.4,
      carbs: 0.0,
      fat: 7.3,
      category: 'Poultry & Meat',
      source: 'USDA FoodData Central #174036',
    ),
    FoodItem(
      id: 'usda_beef_sirloin',
      name: 'Beef Top Sirloin Steak (Trimmed)',
      calories: 183,
      protein: 30.4,
      carbs: 0.0,
      fat: 6.8,
      category: 'Poultry & Meat',
      source: 'USDA FoodData Central #173295',
    ),
    FoodItem(
      id: 'usda_ground_turkey_93_7',
      name: 'Ground Turkey (93% Lean)',
      calories: 150,
      protein: 20.0,
      carbs: 0.0,
      fat: 8.0,
      category: 'Poultry & Meat',
      source: 'USDA FoodData Central #171116',
    ),

    // Seafood & Fish
    FoodItem(
      id: 'usda_atlantic_salmon_raw',
      name: 'Atlantic Salmon (Raw Fillet)',
      calories: 208,
      protein: 20.4,
      carbs: 0.0,
      fat: 13.4,
      category: 'Fish & Seafood',
      source: 'USDA FoodData Central #175167',
    ),
    FoodItem(
      id: 'usda_tuna_canned_water',
      name: 'Canned Chunk Light Tuna in Water (Drained)',
      calories: 116,
      protein: 25.5,
      carbs: 0.0,
      fat: 0.8,
      category: 'Fish & Seafood',
      source: 'USDA FoodData Central #171986',
    ),
    FoodItem(
      id: 'usda_tilapia_cooked',
      name: 'Tilapia Fillet (Cooked)',
      calories: 128,
      protein: 26.2,
      carbs: 0.0,
      fat: 2.7,
      category: 'Fish & Seafood',
      source: 'USDA FoodData Central #174227',
    ),

    // Eggs & Dairy
    FoodItem(
      id: 'usda_large_egg_whole',
      name: 'Whole Large Egg',
      servingSize: '1 egg (~50g)',
      calories: 143,
      protein: 12.6,
      carbs: 0.7,
      fat: 9.5,
      category: 'Eggs & Dairy',
      source: 'USDA FoodData Central #171287',
    ),
    FoodItem(
      id: 'usda_egg_whites_liquid',
      name: 'Liquid Egg Whites',
      calories: 52,
      protein: 10.9,
      carbs: 0.7,
      fat: 0.2,
      category: 'Eggs & Dairy',
      source: 'USDA FoodData Central #172183',
    ),
    FoodItem(
      id: 'usda_greek_yogurt_nonfat',
      name: 'Plain Greek Yogurt (0% Fat)',
      calories: 59,
      protein: 10.3,
      carbs: 3.6,
      fat: 0.4,
      category: 'Eggs & Dairy',
      source: 'USDA FoodData Central #170903',
    ),
    FoodItem(
      id: 'usda_cottage_cheese_lowfat',
      name: 'Low-Fat Cottage Cheese (2% Milkfat)',
      calories: 81,
      protein: 11.0,
      carbs: 4.7,
      fat: 2.3,
      category: 'Eggs & Dairy',
      source: 'USDA FoodData Central #173418',
    ),
    FoodItem(
      id: 'off_whey_protein_isolate',
      name: 'Whey Protein Isolate (100% Unflavored)',
      servingSize: '1 scoop (30g)',
      calories: 370,
      protein: 88.0,
      carbs: 2.0,
      fat: 1.0,
      category: 'Supplements',
      source: 'Open Food Facts #0001002345',
    ),

    // Grains & Complex Carbs
    FoodItem(
      id: 'usda_rolled_oats_dry',
      name: 'Rolled Oats (Old Fashioned Dry)',
      calories: 379,
      protein: 13.2,
      carbs: 67.7,
      fat: 6.5,
      fiber: 10.1,
      category: 'Grains & Carbs',
      source: 'USDA FoodData Central #173904',
    ),
    FoodItem(
      id: 'usda_white_rice_cooked',
      name: 'White Jasmine Rice (Cooked)',
      calories: 130,
      protein: 2.7,
      carbs: 28.2,
      fat: 0.3,
      category: 'Grains & Carbs',
      source: 'USDA FoodData Central #168878',
    ),
    FoodItem(
      id: 'usda_brown_rice_cooked',
      name: 'Brown Long-Grain Rice (Cooked)',
      calories: 123,
      protein: 2.7,
      carbs: 25.6,
      fat: 1.0,
      fiber: 1.6,
      category: 'Grains & Carbs',
      source: 'USDA FoodData Central #169704',
    ),
    FoodItem(
      id: 'usda_sweet_potato_baked',
      name: 'Sweet Potato (Baked with Skin)',
      calories: 90,
      protein: 2.0,
      carbs: 20.7,
      fat: 0.2,
      fiber: 3.3,
      category: 'Grains & Carbs',
      source: 'USDA FoodData Central #168483',
    ),
    FoodItem(
      id: 'usda_whole_wheat_bread',
      name: '100% Whole Wheat Bread',
      servingSize: '1 slice (~43g)',
      calories: 247,
      protein: 13.0,
      carbs: 41.3,
      fat: 3.4,
      fiber: 6.0,
      category: 'Grains & Carbs',
      source: 'USDA FoodData Central #172688',
    ),

    // Fruits & Vegetables
    FoodItem(
      id: 'usda_banana_raw',
      name: 'Fresh Banana',
      servingSize: '1 medium (~118g)',
      calories: 89,
      protein: 1.1,
      carbs: 22.8,
      fat: 0.3,
      fiber: 2.6,
      category: 'Fruits & Veggies',
      source: 'USDA FoodData Central #173944',
    ),
    FoodItem(
      id: 'usda_blueberries_raw',
      name: 'Wild Blueberries (Raw)',
      calories: 57,
      protein: 0.7,
      carbs: 14.5,
      fat: 0.3,
      fiber: 2.4,
      category: 'Fruits & Veggies',
      source: 'USDA FoodData Central #171711',
    ),
    FoodItem(
      id: 'usda_apple_fuji',
      name: 'Fresh Fuji Apple with Peel',
      calories: 52,
      protein: 0.3,
      carbs: 13.8,
      fat: 0.2,
      fiber: 2.4,
      category: 'Fruits & Veggies',
      source: 'USDA FoodData Central #171688',
    ),
    FoodItem(
      id: 'usda_broccoli_raw',
      name: 'Fresh Broccoli Florets (Raw)',
      calories: 34,
      protein: 2.8,
      carbs: 6.6,
      fat: 0.4,
      fiber: 2.6,
      category: 'Fruits & Veggies',
      source: 'USDA FoodData Central #170379',
    ),
    FoodItem(
      id: 'usda_spinach_raw',
      name: 'Fresh Baby Spinach Leaves',
      calories: 23,
      protein: 2.9,
      carbs: 3.6,
      fat: 0.4,
      fiber: 2.2,
      category: 'Fruits & Veggies',
      source: 'USDA FoodData Central #168462',
    ),

    // Healthy Fats & Nuts
    FoodItem(
      id: 'usda_peanut_butter_natural',
      name: 'Natural Peanut Butter (Peanuts & Salt)',
      calories: 588,
      protein: 25.1,
      carbs: 20.0,
      fat: 50.4,
      fiber: 8.0,
      category: 'Fats & Nuts',
      source: 'USDA FoodData Central #172470',
    ),
    FoodItem(
      id: 'usda_almonds_raw',
      name: 'Raw Whole Almonds',
      calories: 579,
      protein: 21.2,
      carbs: 21.6,
      fat: 49.9,
      fiber: 12.5,
      category: 'Fats & Nuts',
      source: 'USDA FoodData Central #170567',
    ),
    FoodItem(
      id: 'usda_olive_oil_extra_virgin',
      name: 'Extra Virgin Olive Oil (Cold Pressed)',
      calories: 884,
      protein: 0.0,
      carbs: 0.0,
      fat: 100.0,
      category: 'Fats & Nuts',
      source: 'USDA FoodData Central #171413',
    ),
    FoodItem(
      id: 'usda_avocado_hass',
      name: 'Hass Avocado (Raw Flesh)',
      calories: 160,
      protein: 2.0,
      carbs: 8.5,
      fat: 14.7,
      fiber: 6.7,
      category: 'Fats & Nuts',
      source: 'USDA FoodData Central #171705',
    ),

    // Plant Proteins & Legumes
    FoodItem(
      id: 'usda_black_beans_cooked',
      name: 'Black Beans (Boiled / Cooked)',
      calories: 132,
      protein: 8.9,
      carbs: 23.7,
      fat: 0.5,
      fiber: 8.7,
      category: 'Legumes & Plant',
      source: 'USDA FoodData Central #173735',
    ),
    FoodItem(
      id: 'usda_firm_tofu',
      name: 'Firm Tofu (Prepared with Calcium Sulfate)',
      calories: 83,
      protein: 10.0,
      carbs: 1.2,
      fat: 5.3,
      category: 'Legumes & Plant',
      source: 'USDA FoodData Central #172448',
    ),
  ];
}
