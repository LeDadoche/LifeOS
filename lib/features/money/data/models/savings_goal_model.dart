/// Modèle pour les objectifs d'épargne
/// Stocké dans la table 'savings_goals' de Supabase
class SavingsGoal {
  final int? id;
  final String userId;
  final String title;
  final String? description;
  final double targetAmount; // Montant cible
  final double currentAmount; // Montant actuel épargné
  final DateTime? targetDate; // Date cible (optionnelle)
  final String? iconName; // Nom de l'icône Material
  final String? color; // Couleur en hex (ex: #FF5733)
  final bool isCompleted;
  final DateTime? createdAt;
  final DateTime? completedAt;

  SavingsGoal({
    this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.targetAmount,
    this.currentAmount = 0.0,
    this.targetDate,
    this.iconName,
    this.color,
    this.isCompleted = false,
    this.createdAt,
    this.completedAt,
  });

  /// Pourcentage de progression (0.0 à 1.0)
  double get progressRatio {
    if (targetAmount <= 0) return 0.0;
    return (currentAmount / targetAmount).clamp(0.0, 1.0);
  }

  /// Pourcentage de progression (0 à 100)
  int get progressPercent => (progressRatio * 100).round();

  /// Montant restant à épargner
  double get remainingAmount => (targetAmount - currentAmount).clamp(0.0, double.infinity);

  /// Vérifie si l'objectif est atteint
  bool get isGoalReached => currentAmount >= targetAmount;

  factory SavingsGoal.fromJson(Map<String, dynamic> json) {
    return SavingsGoal(
      id: json['id'] as int?,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      targetAmount: (json['target_amount'] as num).toDouble(),
      currentAmount: (json['current_amount'] as num?)?.toDouble() ?? 0.0,
      targetDate: json['target_date'] != null
          ? DateTime.parse(json['target_date'] as String)
          : null,
      iconName: json['icon_name'] as String?,
      color: json['color'] as String?,
      isCompleted: json['is_completed'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'target_date': targetDate?.toIso8601String(),
      'icon_name': iconName,
      'color': color,
      'is_completed': isCompleted,
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
    };
  }

  SavingsGoal copyWith({
    int? id,
    String? userId,
    String? title,
    String? description,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    String? iconName,
    String? color,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      iconName: iconName ?? this.iconName,
      color: color ?? this.color,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
