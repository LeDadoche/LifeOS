/// Modèle pour le profil financier de l'utilisateur
/// Stocké dans la table 'financial_profile' de Supabase
class FinancialProfile {
  final int? id;
  final String userId;
  final double averageSalary; // Salaire moyen mensuel
  final int payDay; // Jour de paie (1-31)
  final double overdraftLimit; // Plafond de découvert autorisé
  final double savingsGoal; // Objectif d'épargne mensuel
  final double variableBudget; // Budget estimé (Courses/Divers) - DEPRECATED, use weeklyGroceryBudget
  final double weeklyGroceryBudget; // Budget courses hebdomadaire (famille)
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FinancialProfile({
    this.id,
    required this.userId,
    this.averageSalary = 0.0,
    this.payDay = 1,
    this.overdraftLimit = 0.0,
    this.savingsGoal = 0.0,
    this.variableBudget = 0.0,
    this.weeklyGroceryBudget = 0.0,
    this.createdAt,
    this.updatedAt,
  });

  /// Calcule le plafond de sécurité (solde disponible + découvert)
  double getSecurityThreshold(double currentBalance) {
    return currentBalance + overdraftLimit;
  }

  /// Détermine le statut financier basé sur le solde actuel
  FinancialStatus getStatus(double currentBalance) {
    if (averageSalary <= 0) return FinancialStatus.unknown;
    
    final ratio = currentBalance / averageSalary;
    
    if (currentBalance < 0) {
      return FinancialStatus.overdraft;
    } else if (ratio < 0.1) {
      return FinancialStatus.critical;
    } else if (ratio < 0.2) {
      return FinancialStatus.warning;
    } else {
      return FinancialStatus.healthy;
    }
  }

  factory FinancialProfile.fromJson(Map<String, dynamic> json) {
    return FinancialProfile(
      id: json['id'] as int?,
      userId: json['user_id'] as String,
      averageSalary: (json['average_salary'] as num?)?.toDouble() ?? 0.0,
      payDay: json['pay_day'] as int? ?? 1,
      overdraftLimit: (json['overdraft_limit'] as num?)?.toDouble() ?? 0.0,
      savingsGoal: (json['savings_goal'] as num?)?.toDouble() ?? 0.0,
      variableBudget: (json['variable_budget'] as num?)?.toDouble() ?? 0.0,
      weeklyGroceryBudget: (json['weekly_grocery_budget'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'average_salary': averageSalary,
      'pay_day': payDay,
      'overdraft_limit': overdraftLimit,
      'savings_goal': savingsGoal,
      'variable_budget': variableBudget,
      'weekly_grocery_budget': weeklyGroceryBudget,
    };
  }

  FinancialProfile copyWith({
    int? id,
    String? userId,
    double? averageSalary,
    int? payDay,
    double? overdraftLimit,
    double? savingsGoal,
    double? variableBudget,
    double? weeklyGroceryBudget,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinancialProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      averageSalary: averageSalary ?? this.averageSalary,
      payDay: payDay ?? this.payDay,
      overdraftLimit: overdraftLimit ?? this.overdraftLimit,
      savingsGoal: savingsGoal ?? this.savingsGoal,
      variableBudget: variableBudget ?? this.variableBudget,
      weeklyGroceryBudget: weeklyGroceryBudget ?? this.weeklyGroceryBudget,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Statut financier de l'utilisateur
enum FinancialStatus {
  healthy,   // Vert : solde > 20% du salaire
  warning,   // Orange : solde entre 10% et 20% du salaire
  critical,  // Rouge : solde < 10% du salaire
  overdraft, // Rouge foncé : en découvert
  unknown,   // Gris : pas assez de données
}
