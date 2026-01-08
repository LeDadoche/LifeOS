/// Statut d'une transaction
enum TransactionStatus {
  completed, // Transaction passée/effectuée
  scheduled, // Transaction prévue (pas encore passée)
  pending, // En attente de confirmation
}

class Transaction {
  final int? id;
  final String title;
  final double amount;
  final DateTime date;
  final bool isExpense;
  final String? category;
  final String userId;
  final TransactionStatus status;
  final int?
      recurringTransactionId; // Lien vers la transaction récurrente source
  final String? notes;

  Transaction({
    this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.isExpense,
    this.category,
    required this.userId,
    this.status = TransactionStatus.completed,
    this.recurringTransactionId,
    this.notes,
  });

  /// Vérifie si la transaction est prévue (dans le futur)
  bool get isScheduled => status == TransactionStatus.scheduled;

  /// Vérifie si la transaction est passée
  bool get isPast => date.isBefore(DateTime.now());

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as int?,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      isExpense: json['is_expense'] as bool,
      category: json['category'] as String?,
      userId: json['user_id'] as String,
      status: _parseStatus(json['status'] as String?),
      recurringTransactionId: json['recurring_transaction_id'] as int?,
      notes: json['notes'] as String?,
    );
  }

  static TransactionStatus _parseStatus(String? status) {
    switch (status) {
      case 'scheduled':
        return TransactionStatus.scheduled;
      case 'pending':
        return TransactionStatus.pending;
      default:
        return TransactionStatus.completed;
    }
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
      'status': status.name,
      if (recurringTransactionId != null)
        'recurring_transaction_id': recurringTransactionId,
      if (notes != null) 'notes': notes,
    };
  }

  Transaction copyWith({
    int? id,
    String? title,
    double? amount,
    DateTime? date,
    bool? isExpense,
    String? category,
    String? userId,
    TransactionStatus? status,
    int? recurringTransactionId,
    String? notes,
  }) {
    return Transaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      isExpense: isExpense ?? this.isExpense,
      category: category ?? this.category,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      recurringTransactionId:
          recurringTransactionId ?? this.recurringTransactionId,
      notes: notes ?? this.notes,
    );
  }
}
