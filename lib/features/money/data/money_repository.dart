import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'transaction_model.dart';
import 'models/recurring_transaction_model.dart';
import 'models/financial_profile_model.dart';
import 'models/savings_goal_model.dart';
import 'models/budget_category_model.dart';

final moneyRepositoryProvider = Provider<MoneyRepository>((ref) {
  return MoneyRepository(Supabase.instance.client);
});

final transactionsProvider = StreamProvider<List<Transaction>>((ref) {
  return ref.watch(moneyRepositoryProvider).watchTransactions();
});

final recurringTransactionsProvider =
    StreamProvider<List<RecurringTransaction>>((ref) {
  return ref.watch(moneyRepositoryProvider).watchRecurringTransactions();
});

final financialProfileProvider = StreamProvider<FinancialProfile?>((ref) {
  return ref.watch(moneyRepositoryProvider).watchFinancialProfile();
});

final savingsGoalsProvider = StreamProvider<List<SavingsGoal>>((ref) {
  return ref.watch(moneyRepositoryProvider).watchSavingsGoals();
});

final budgetCategoriesProvider = StreamProvider<List<BudgetCategory>>((ref) {
  return ref.watch(moneyRepositoryProvider).watchBudgetCategories();
});

/// Provider pour le calcul du "Reste à vivre"
final remainingBudgetProvider = Provider<double>((ref) {
  final transactionsAsync = ref.watch(transactionsProvider);
  final recurringAsync = ref.watch(recurringTransactionsProvider);
  final profileAsync = ref.watch(financialProfileProvider);

  return transactionsAsync.maybeWhen(
    data: (transactions) {
      final now = DateTime.now();
      final nextMonth = DateTime(now.year, now.month + 1, 1);

      // Calculer le solde actuel
      double balance = 0;
      for (var t in transactions) {
        if (t.isExpense) {
          balance -= t.amount;
        } else {
          balance += t.amount;
        }
      }

      // Calculer les transactions récurrentes non encore passées ce mois
      final recurring = recurringAsync.maybeWhen(
        data: (list) => list,
        orElse: () => <RecurringTransaction>[],
      );

      double pendingExpenses = 0;
      for (var r in recurring) {
        if (r.isExpense && r.isActive) {
          final scheduledDate = DateTime(now.year, now.month, r.dayOfMonth);
          // Si la date n'est pas encore passée ce mois
          if (scheduledDate.isAfter(now) && scheduledDate.isBefore(nextMonth)) {
            // Vérifier si cette transaction n'a pas déjà été générée
            final alreadyGenerated = transactions.any((t) =>
                t.recurringTransactionId == r.id &&
                t.date.month == now.month &&
                t.date.year == now.year);
            if (!alreadyGenerated) {
              pendingExpenses += r.amount;
            }
          }
        }
      }

      // Soustraire le forfait variable du profil
      final variableBudget = profileAsync.maybeWhen(
        data: (profile) => profile?.variableBudget ?? 0.0,
        orElse: () => 0.0,
      );

      return balance - pendingExpenses - variableBudget;
    },
    orElse: () => 0.0,
  );
});

/// Calcule le nombre de semaines restantes dans le mois (incluant la semaine courante)
int _getRemainingWeeksInMonth() {
  final now = DateTime.now();
  final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
  final daysRemaining = lastDayOfMonth.day - now.day + 1;
  // Arrondir vers le haut pour inclure la semaine partielle
  return (daysRemaining / 7).ceil().clamp(1, 5);
}

/// Provider "Solde Estimé" - Calcul simplifié pour le mode prédiction
/// Solde actuel + Salaire (si pas encore reçu) - Charges fixes restantes - (Budget hebdo × semaines restantes)
final estimatedBalanceProvider = Provider<EstimatedBalanceData>((ref) {
  final transactionsAsync = ref.watch(transactionsProvider);
  final recurringAsync = ref.watch(recurringTransactionsProvider);
  final profileAsync = ref.watch(financialProfileProvider);

  return transactionsAsync.maybeWhen(
    data: (transactions) {
      final now = DateTime.now();

      // Calculer le solde actuel
      double balance = 0;
      for (var t in transactions) {
        if (t.isExpense) {
          balance -= t.amount;
        } else {
          balance += t.amount;
        }
      }

      final profile = profileAsync.maybeWhen(
        data: (p) => p,
        orElse: () => null,
      );

      final recurring = recurringAsync.maybeWhen(
        data: (list) => list,
        orElse: () => <RecurringTransaction>[],
      );

      // Salaire prévu si pas encore reçu ce mois
      double pendingSalary = 0;
      if (profile != null && profile.averageSalary > 0) {
        final payDay = profile.payDay;
        if (now.day < payDay) {
          // Le salaire n'est pas encore arrivé ce mois
          final salaryAlreadyReceived = transactions.any((t) =>
              !t.isExpense &&
              t.date.month == now.month &&
              t.date.year == now.year &&
              t.amount >= profile.averageSalary * 0.8);
          if (!salaryAlreadyReceived) {
            pendingSalary = profile.averageSalary;
          }
        }
      }

      // Total des charges fixes du mois (toutes les récurrentes dépenses)
      double totalFixedExpenses = 0;
      double paidFixedExpenses = 0;
      List<PendingRecurring> pendingRecurring = [];

      for (var r in recurring) {
        if (r.isExpense && r.isActive) {
          totalFixedExpenses += r.amount;

          // Vérifier si déjà payé ce mois
          final alreadyPaid = transactions.any((t) =>
              t.recurringTransactionId == r.id &&
              t.date.month == now.month &&
              t.date.year == now.year);

          if (alreadyPaid) {
            paidFixedExpenses += r.amount;
          } else {
            // Vérifier si la date est passée ou aujourd'hui
            final scheduledDate = DateTime(now.year, now.month, r.dayOfMonth);
            final isDue = scheduledDate.day <= now.day;
            pendingRecurring.add(PendingRecurring(
              recurring: r,
              isDue: isDue,
              scheduledDate: scheduledDate,
            ));
          }
        }
      }

      final remainingFixedExpenses = totalFixedExpenses - paidFixedExpenses;

      // Budget courses hebdomadaire × semaines restantes
      final weeklyBudget = profile?.weeklyGroceryBudget ?? 0;
      final remainingWeeks = _getRemainingWeeksInMonth();
      final groceryBudgetRemaining = weeklyBudget * remainingWeeks;

      // Solde Estimé = Solde + Salaire à venir - Fixes restantes - Budget courses
      final estimatedBalance = balance +
          pendingSalary -
          remainingFixedExpenses -
          groceryBudgetRemaining;

      // Progression du mois (basée sur les fixes payées)
      final monthProgress = totalFixedExpenses > 0
          ? (paidFixedExpenses / totalFixedExpenses).clamp(0.0, 1.0)
          : (now.day / DateTime(now.year, now.month + 1, 0).day);

      return EstimatedBalanceData(
        estimatedBalance: estimatedBalance,
        currentBalance: balance,
        pendingSalary: pendingSalary,
        totalFixedExpenses: totalFixedExpenses,
        paidFixedExpenses: paidFixedExpenses,
        remainingFixedExpenses: remainingFixedExpenses,
        weeklyGroceryBudget: weeklyBudget,
        remainingWeeks: remainingWeeks,
        groceryBudgetRemaining: groceryBudgetRemaining,
        monthProgress: monthProgress,
        pendingRecurring: pendingRecurring,
      );
    },
    orElse: () => EstimatedBalanceData.empty(),
  );
});

// Alias pour rétrocompatibilité
final serenityProvider = estimatedBalanceProvider;
typedef SerenityData = EstimatedBalanceData;

/// Données de solde estimé calculées
class EstimatedBalanceData {
  final double estimatedBalance;
  final double currentBalance;
  final double pendingSalary;
  final double totalFixedExpenses;
  final double paidFixedExpenses;
  final double remainingFixedExpenses;
  final double weeklyGroceryBudget;
  final int remainingWeeks;
  final double groceryBudgetRemaining;
  final double monthProgress;
  final List<PendingRecurring> pendingRecurring;

  // Alias pour rétrocompatibilité
  double get serenityAmount => estimatedBalance;
  double get variableBudget => groceryBudgetRemaining;

  EstimatedBalanceData({
    required this.estimatedBalance,
    required this.currentBalance,
    required this.pendingSalary,
    required this.totalFixedExpenses,
    required this.paidFixedExpenses,
    required this.remainingFixedExpenses,
    required this.weeklyGroceryBudget,
    required this.remainingWeeks,
    required this.groceryBudgetRemaining,
    required this.monthProgress,
    required this.pendingRecurring,
  });

  factory EstimatedBalanceData.empty() => EstimatedBalanceData(
        estimatedBalance: 0,
        currentBalance: 0,
        pendingSalary: 0,
        totalFixedExpenses: 0,
        paidFixedExpenses: 0,
        remainingFixedExpenses: 0,
        weeklyGroceryBudget: 0,
        remainingWeeks: 1,
        groceryBudgetRemaining: 0,
        monthProgress: 0,
        pendingRecurring: [],
      );

  /// Transactions en attente de confirmation (date passée mais pas confirmées)
  List<PendingRecurring> get dueForConfirmation =>
      pendingRecurring.where((p) => p.isDue).toList();
}

/// Transaction récurrente en attente
class PendingRecurring {
  final RecurringTransaction recurring;
  final bool isDue;
  final DateTime scheduledDate;

  PendingRecurring({
    required this.recurring,
    required this.isDue,
    required this.scheduledDate,
  });
}

/// Provider pour les statistiques mensuelles par catégorie
final monthlyCategoryStatsProvider = Provider<Map<String, double>>((ref) {
  final transactionsAsync = ref.watch(transactionsProvider);

  return transactionsAsync.maybeWhen(
    data: (transactions) {
      final now = DateTime.now();
      final stats = <String, double>{};

      for (var t in transactions) {
        if (t.isExpense &&
            t.date.month == now.month &&
            t.date.year == now.year) {
          final category = t.category ?? 'Autre';
          stats[category] = (stats[category] ?? 0) + t.amount;
        }
      }

      return stats;
    },
    orElse: () => <String, double>{},
  );
});

class MoneyRepository {
  final SupabaseClient _client;

  MoneyRepository(this._client);

  String? get _currentUserId => _client.auth.currentUser?.id;

  // ============ TRANSACTIONS ============

  Stream<List<Transaction>> watchTransactions() {
    final userId = _currentUserId;
    if (userId == null) {
      debugPrint('⚠️ [Realtime] watchTransactions: No user logged in');
      return Stream.value([]);
    }
    debugPrint('🔄 [Realtime] Initialisation stream TRANSACTIONS pour user $userId');
    return _client
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('date', ascending: false)
        .map((data) {
          debugPrint('🔄 [Realtime] Nouvelle donnée reçue pour [transactions] - ${data.length} éléments');
          return data.map((json) => Transaction.fromJson(json)).toList();
        });
  }

  Future<List<Transaction>> getTransactionsForMonth(int year, int month) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0);

    final response = await _client
        .from('transactions')
        .select()
        .gte('date', startDate.toIso8601String())
        .lte('date', endDate.toIso8601String())
        .order('date', ascending: false);

    return (response as List)
        .map((json) => Transaction.fromJson(json))
        .toList();
  }

  Future<void> addTransaction(Transaction transaction) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final data = transaction.toJson();
    data['user_id'] = user.id;
    data.remove('id');

    await _client.from('transactions').insert(data);
  }

  Future<void> updateTransaction(Transaction transaction) async {
    if (transaction.id == null) return;

    await _client
        .from('transactions')
        .update(transaction.toJson())
        .eq('id', transaction.id!);
  }

  Future<void> deleteTransaction(int id) async {
    await _client.from('transactions').delete().eq('id', id);
  }

  // ============ RECURRING TRANSACTIONS ============

  Stream<List<RecurringTransaction>> watchRecurringTransactions() {
    final userId = _currentUserId;
    if (userId == null) {
      debugPrint('⚠️ [Realtime] watchRecurringTransactions: No user logged in');
      return Stream.value([]);
    }
    debugPrint('🔄 [Realtime] Initialisation stream RECURRING_TRANSACTIONS pour user $userId');
    return _client
        .from('recurring_transactions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('day_of_month', ascending: true)
        .map((data) {
          debugPrint('🔄 [Realtime] Nouvelle donnée reçue pour [recurring_transactions] - ${data.length} éléments');
          return data.map((json) => RecurringTransaction.fromJson(json)).toList();
        });
  }

  Future<void> addRecurringTransaction(RecurringTransaction transaction) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final data = transaction.toJson();
    data['user_id'] = user.id;
    data.remove('id');

    await _client.from('recurring_transactions').insert(data);
  }

  Future<void> updateRecurringTransaction(
      RecurringTransaction transaction) async {
    if (transaction.id == null) return;

    await _client
        .from('recurring_transactions')
        .update(transaction.toJson())
        .eq('id', transaction.id!);
  }

  Future<void> deleteRecurringTransaction(int id) async {
    await _client.from('recurring_transactions').delete().eq('id', id);
  }

  Future<void> toggleRecurringTransaction(int id, bool isActive) async {
    await _client
        .from('recurring_transactions')
        .update({'is_active': isActive}).eq('id', id);
  }

  // ============ FINANCIAL PROFILE ============

  Stream<FinancialProfile?> watchFinancialProfile() {
    debugPrint('🔄 [Realtime] Initialisation stream FINANCIAL_PROFILE');
    final userId = _currentUserId;
    if (userId == null) return Stream.value(null);

    return _client
        .from('financial_profile')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((data) {
          debugPrint('🔄 [Realtime] Nouvelle donnée reçue pour [financial_profile] - ${data.length} éléments');
          return data.isNotEmpty ? FinancialProfile.fromJson(data.first) : null;
        });
  }

  Future<FinancialProfile?> getFinancialProfile() async {
    final userId = _currentUserId;
    if (userId == null) return null;

    final response = await _client
        .from('financial_profile')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    return response != null ? FinancialProfile.fromJson(response) : null;
  }

  Future<void> saveFinancialProfile(FinancialProfile profile) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final data = profile.toJson();
    data['user_id'] = user.id;

    if (profile.id != null) {
      await _client
          .from('financial_profile')
          .update(data)
          .eq('id', profile.id!);
    } else {
      data.remove('id');
      await _client.from('financial_profile').insert(data);
    }
  }

  // ============ SAVINGS GOALS ============

  Stream<List<SavingsGoal>> watchSavingsGoals() {
    final userId = _currentUserId;
    if (userId == null) {
      debugPrint('⚠️ [Realtime] watchSavingsGoals: No user logged in');
      return Stream.value([]);
    }
    debugPrint('🔄 [Realtime] Initialisation stream SAVINGS_GOALS pour user $userId');
    return _client
        .from('savings_goals')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((data) {
          debugPrint('🔄 [Realtime] Nouvelle donnée reçue pour [savings_goals] - ${data.length} éléments');
          return data.map((json) => SavingsGoal.fromJson(json)).toList();
        });
  }

  Future<void> addSavingsGoal(SavingsGoal goal) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final data = goal.toJson();
    data['user_id'] = user.id;
    data.remove('id');

    await _client.from('savings_goals').insert(data);
  }

  Future<void> updateSavingsGoal(SavingsGoal goal) async {
    if (goal.id == null) return;

    await _client
        .from('savings_goals')
        .update(goal.toJson())
        .eq('id', goal.id!);
  }

  Future<void> addToSavingsGoal(int goalId, double amount) async {
    final response = await _client
        .from('savings_goals')
        .select('current_amount, target_amount')
        .eq('id', goalId)
        .single();

    final currentAmount = (response['current_amount'] as num).toDouble();
    final targetAmount = (response['target_amount'] as num).toDouble();
    final newAmount = currentAmount + amount;

    final updateData = <String, dynamic>{
      'current_amount': newAmount,
    };

    // Marquer comme complété si l'objectif est atteint
    if (newAmount >= targetAmount) {
      updateData['is_completed'] = true;
      updateData['completed_at'] = DateTime.now().toIso8601String();
    }

    await _client.from('savings_goals').update(updateData).eq('id', goalId);
  }

  Future<void> deleteSavingsGoal(int id) async {
    await _client.from('savings_goals').delete().eq('id', id);
  }

  // ============ BUDGET CATEGORIES ============

  Stream<List<BudgetCategory>> watchBudgetCategories() {
    final userId = _currentUserId;
    if (userId == null) {
      debugPrint('⚠️ [Realtime] watchBudgetCategories: No user logged in');
      return Stream.value([]);
    }
    debugPrint('🔄 [Realtime] Initialisation stream BUDGET_CATEGORIES pour user $userId');
    return _client
        .from('budget_categories')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('name', ascending: true)
        .map((data) {
          debugPrint('🔄 [Realtime] Nouvelle donnée reçue pour [budget_categories] - ${data.length} éléments');
          return data.map((json) => BudgetCategory.fromJson(json)).toList();
        });
  }

  Future<void> addBudgetCategory(BudgetCategory category) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final data = category.toJson();
    data['user_id'] = user.id;
    data.remove('id');

    await _client.from('budget_categories').insert(data);
  }

  Future<void> updateBudgetCategory(BudgetCategory category) async {
    if (category.id == null) return;

    await _client
        .from('budget_categories')
        .update(category.toJson())
        .eq('id', category.id!);
  }

  Future<void> deleteBudgetCategory(int id) async {
    await _client.from('budget_categories').delete().eq('id', id);
  }

  Future<void> initializeDefaultCategories() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    // Vérifier si des catégories existent déjà
    final existing = await _client
        .from('budget_categories')
        .select('id')
        .eq('user_id', user.id)
        .limit(1);

    if ((existing as List).isNotEmpty) return;

    // Créer les catégories par défaut
    final categories = DefaultCategories.categories
        .map((cat) => {
              ...cat,
              'user_id': user.id,
              'is_default': true,
              'budget_limit': 0.0,
            })
        .toList();

    await _client.from('budget_categories').insert(categories);
  }

  // ============ GÉNÉRATION TRANSACTIONS RÉCURRENTES ============

  /// Génère les transactions du mois à partir des transactions récurrentes
  Future<void> generateMonthlyTransactions({DateTime? forDate}) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final now = forDate ?? DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);

    // Récupérer toutes les transactions récurrentes actives
    final recurringResponse = await _client
        .from('recurring_transactions')
        .select()
        .eq('user_id', user.id)
        .eq('is_active', true);

    final recurring = (recurringResponse as List)
        .map((json) => RecurringTransaction.fromJson(json))
        .toList();

    // Vérifier les transactions déjà générées ce mois
    final existingResponse = await _client
        .from('transactions')
        .select('recurring_transaction_id')
        .eq('user_id', user.id)
        .not('recurring_transaction_id', 'is', null)
        .gte('date', currentMonth.toIso8601String())
        .lt('date', DateTime(now.year, now.month + 1, 1).toIso8601String());

    final existingIds = (existingResponse as List)
        .map((e) => e['recurring_transaction_id'] as int)
        .toSet();

    // Générer les transactions manquantes
    for (var r in recurring) {
      if (r.id != null && !existingIds.contains(r.id)) {
        // Calculer la date de la transaction pour ce mois
        final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
        final day =
            r.dayOfMonth > lastDayOfMonth ? lastDayOfMonth : r.dayOfMonth;
        final transactionDate = DateTime(now.year, now.month, day);

        // Déterminer le statut (prévue si dans le futur)
        final status = transactionDate.isAfter(now)
            ? TransactionStatus.scheduled
            : TransactionStatus.completed;

        final transaction = Transaction(
          title: r.title,
          amount: r.amount,
          date: transactionDate,
          isExpense: r.isExpense,
          category: r.category,
          userId: user.id,
          status: status,
          recurringTransactionId: r.id,
        );

        await addTransaction(transaction);
      }
    }
  }

  /// Met à jour le statut des transactions prévues devenues passées
  Future<void> updateScheduledTransactions() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();

    await _client
        .from('transactions')
        .update({'status': 'completed'})
        .eq('user_id', user.id)
        .eq('status', 'scheduled')
        .lte('date', now.toIso8601String());
  }
}
