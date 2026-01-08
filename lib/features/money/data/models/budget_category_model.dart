import 'package:flutter/material.dart';

/// Modèle pour les budgets par catégorie
/// Stocké dans la table 'budget_categories' de Supabase
class BudgetCategory {
  final int? id;
  final String userId;
  final String name;
  final double budgetLimit; // Plafond mensuel
  final String? iconName;
  final String? color; // Couleur en hex
  final bool isDefault; // Catégorie par défaut du système
  final DateTime? createdAt;

  BudgetCategory({
    this.id,
    required this.userId,
    required this.name,
    this.budgetLimit = 0.0,
    this.iconName,
    this.color,
    this.isDefault = false,
    this.createdAt,
  });

  factory BudgetCategory.fromJson(Map<String, dynamic> json) {
    return BudgetCategory(
      id: json['id'] as int?,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      budgetLimit: (json['budget_limit'] as num?)?.toDouble() ?? 0.0,
      iconName: json['icon_name'] as String?,
      color: json['color'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'budget_limit': budgetLimit,
      'icon_name': iconName,
      'color': color,
      'is_default': isDefault,
    };
  }

  BudgetCategory copyWith({
    int? id,
    String? userId,
    String? name,
    double? budgetLimit,
    String? iconName,
    String? color,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return BudgetCategory(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      budgetLimit: budgetLimit ?? this.budgetLimit,
      iconName: iconName ?? this.iconName,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Convertit le nom d'icône en IconData
  IconData get icon {
    return _iconMap[iconName] ?? Icons.category;
  }

  /// Convertit la couleur hex en Color
  Color get colorValue {
    if (color == null || color!.isEmpty) return Colors.grey;
    try {
      return Color(int.parse(color!.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }
}

/// Catégories par défaut avec leurs propriétés
class DefaultCategories {
  static const List<Map<String, dynamic>> categories = [
    {
      'name': 'Logement',
      'icon_name': 'home',
      'color': '#4CAF50',
    },
    {
      'name': 'Alimentaire',
      'icon_name': 'restaurant',
      'color': '#FF9800',
    },
    {
      'name': 'Transport',
      'icon_name': 'directions_car',
      'color': '#2196F3',
    },
    {
      'name': 'Santé',
      'icon_name': 'health_and_safety',
      'color': '#F44336',
    },
    {
      'name': 'Loisirs',
      'icon_name': 'sports_esports',
      'color': '#9C27B0',
    },
    {
      'name': 'Abonnements',
      'icon_name': 'subscriptions',
      'color': '#00BCD4',
    },
    {
      'name': 'Épargne',
      'icon_name': 'savings',
      'color': '#8BC34A',
    },
    {
      'name': 'Shopping',
      'icon_name': 'shopping_bag',
      'color': '#E91E63',
    },
    {
      'name': 'Éducation',
      'icon_name': 'school',
      'color': '#3F51B5',
    },
    {
      'name': 'Autre',
      'icon_name': 'more_horiz',
      'color': '#607D8B',
    },
  ];

  static List<String> get categoryNames =>
      categories.map((c) => c['name'] as String).toList();
}

/// Map des icônes Material par nom
const Map<String, IconData> _iconMap = {
  'home': Icons.home,
  'restaurant': Icons.restaurant,
  'directions_car': Icons.directions_car,
  'health_and_safety': Icons.health_and_safety,
  'sports_esports': Icons.sports_esports,
  'subscriptions': Icons.subscriptions,
  'savings': Icons.savings,
  'shopping_bag': Icons.shopping_bag,
  'school': Icons.school,
  'more_horiz': Icons.more_horiz,
  'category': Icons.category,
  'euro': Icons.euro,
  'flight': Icons.flight,
  'beach_access': Icons.beach_access,
  'child_care': Icons.child_care,
  'pets': Icons.pets,
  'fitness_center': Icons.fitness_center,
};

/// Helper pour obtenir une icône par nom
IconData getIconByName(String? iconName) {
  return _iconMap[iconName] ?? Icons.category;
}

/// Helper pour obtenir une couleur par hex
Color getColorFromHex(String? hexColor) {
  if (hexColor == null || hexColor.isEmpty) return Colors.grey;
  try {
    return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
  } catch (_) {
    return Colors.grey;
  }
}
