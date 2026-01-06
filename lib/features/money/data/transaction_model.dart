class Transaction {
  final int? id;
  final String title;
  final double amount;
  final DateTime date;
  final bool isExpense;
  final String? category;
  final String userId;

  Transaction({
    this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.isExpense,
    this.category,
    required this.userId,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as int?,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      isExpense: json['is_expense'] as bool,
      category: json['category'] as String?,
      userId: json['user_id'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'is_expense': isExpense,
      'category': category,
      'user_id': userId,
    };
  }
}
