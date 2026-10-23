class FoodItem {
  final String id;
  final String name;
  final double calories; // per 100g
  final double protein; // per 100g
  final double carbs; // per 100g
  final double fat; // per 100g
  final double fiber; // per 100g

  FoodItem({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0,
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
