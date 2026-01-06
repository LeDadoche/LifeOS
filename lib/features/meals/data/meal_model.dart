class Meal {
  final int? id;
  final DateTime date;
  final String mealType; // 'lunch' or 'dinner'
  final String description;
  final String userId;

  Meal({
    this.id,
    required this.date,
    required this.mealType,
    required this.description,
    required this.userId,
  });

  bool get isLunch => mealType == 'lunch';

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      id: json['id'] as int?,
      date: DateTime.parse(json['date'] as String),
      mealType: json['meal_type'] as String,
      description: json['description'] as String,
      userId: json['user_id'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'date': date.toIso8601String(),
      'meal_type': mealType,
      'description': description,
      'user_id': userId,
    };
  }
}

class ShoppingItem {
  final int? id;
  final String name;
  final bool isBought;
  final String? quantity;
  final String userId;

  ShoppingItem({
    this.id,
    required this.name,
    required this.isBought,
    this.quantity,
    required this.userId,
  });

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      id: json['id'] as int?,
      name: json['name'] as String,
      isBought: json['is_bought'] as bool? ?? false,
      quantity: json['quantity'] as String?,
      userId: json['user_id'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'is_bought': isBought,
      'quantity': quantity,
      'user_id': userId,
    };
  }
}
