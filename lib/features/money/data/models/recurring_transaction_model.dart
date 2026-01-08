/// Modèle pour les transactions récurrentes (permanentes)
/// Stocké dans la table 'recurring_transactions' de Supabase
class RecurringTransaction {
  final int? id;
  final String title;
  final double amount;
  final String category;
  final int dayOfMonth; // Jour du mois où la transaction se produit (1-31)
  final bool isExpense; // true = dépense, false = revenu
  final String userId;
  final bool isActive;
  final DateTime? createdAt;

  RecurringTransaction({
    this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.dayOfMonth,
    required this.isExpense,
    required this.userId,
    this.isActive = true,
    this.createdAt,
  });

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) {
    return RecurringTransaction(
      id: json['id'] as int?,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String,
      dayOfMonth: json['day_of_month'] as int,
      isExpense: json['is_expense'] as bool,
      userId: json['user_id'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'day_of_month': dayOfMonth,
      'is_expense': isExpense,
      'is_active': isActive,
    };
  }

  RecurringTransaction copyWith({
    int? id,
    String? title,
    double? amount,
    String? category,
    int? dayOfMonth,
    bool? isExpense,
    String? userId,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      isExpense: isExpense ?? this.isExpense,
      userId: userId ?? this.userId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
