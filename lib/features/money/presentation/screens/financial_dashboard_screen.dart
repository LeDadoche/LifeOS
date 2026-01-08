import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/money_repository.dart';
import '../../data/services/recurring_transaction_service.dart';
import '../../data/models/recurring_transaction_model.dart';
import '../../data/privacy_provider.dart';
import '../../data/transaction_model.dart';
import '../widgets/estimated_balance_card.dart';
import '../widgets/quick_confirmation_cards.dart';
import '../widgets/month_progress_gauge.dart';

class FinancialDashboardScreen extends ConsumerStatefulWidget {
  const FinancialDashboardScreen({super.key});

  @override
  ConsumerState<FinancialDashboardScreen> createState() =>
      _FinancialDashboardScreenState();
}

class _FinancialDashboardScreenState
    extends ConsumerState<FinancialDashboardScreen> {
  @override
  void initState() {
    super.initState();

    // Initialiser les catégories par défaut et générer les transactions récurrentes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(moneyRepositoryProvider).initializeDefaultCategories();
      ref
          .read(recurringTransactionServiceProvider)
          .checkAndGenerateTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final balanceData = ref.watch(estimatedBalanceProvider);
    final isPrivacyMode = ref.watch(privacyModeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finances'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Privacy mode toggle
          IconButton(
            icon: Icon(
              isPrivacyMode ? Icons.visibility_off : Icons.visibility,
              color: isPrivacyMode ? colorScheme.primary : null,
            ),
            tooltip: isPrivacyMode
                ? 'Afficher les montants'
                : 'Masquer les montants',
            onPressed: () => ref.read(privacyModeProvider.notifier).toggle(),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Paramètres',
            onPressed: () => context.push('/money/profile'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'recurring':
                  context.push('/money/recurring');
                  break;
                case 'categories':
                  context.push('/money/categories');
                  break;
                case 'goals':
                  context.push('/money/goals');
                  break;
                case 'transactions':
                  context.push('/money/add');
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'recurring',
                child: ListTile(
                  leading: Icon(Icons.repeat),
                  title: Text('Charges récurrentes'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'categories',
                child: ListTile(
                  leading: Icon(Icons.category),
                  title: Text('Catégories'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'goals',
                child: ListTile(
                  leading: Icon(Icons.savings),
                  title: Text('Objectifs'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'transactions',
                child: ListTile(
                  leading: Icon(Icons.add),
                  title: Text('Transaction manuelle'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(transactionsProvider);
          ref.invalidate(financialProfileProvider);
          ref.invalidate(recurringTransactionsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Carte Solde Estimé
              EstimatedBalanceCard(
                data: balanceData,
                isPrivacyMode: isPrivacyMode,
              ),
              const SizedBox(height: 20),

              // Boutons de confirmation rapide
              QuickConfirmationCards(
                pendingRecurring: balanceData.pendingRecurring,
                onConfirm: (recurring) => _confirmTransaction(recurring),
              ),

              // Espace si des confirmations sont affichées
              if (balanceData.dueForConfirmation.isNotEmpty)
                const SizedBox(height: 20),

              // Jauge de progression du mois
              MonthProgressGauge(
                serenity: balanceData,
                isPrivacyMode: isPrivacyMode,
              ),
              const SizedBox(height: 20),

              // Section "Prochaines échéances"
              _buildUpcomingSection(context, balanceData, colorScheme),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  /// Confirme une transaction permanente en créant la transaction réelle
  Future<void> _confirmTransaction(RecurringTransaction recurring) async {
    final now = DateTime.now();
    final scheduledDate = DateTime(now.year, now.month, recurring.dayOfMonth);

    final transaction = Transaction(
      title: recurring.title,
      amount: recurring.amount,
      date: scheduledDate.isAfter(now) ? now : scheduledDate,
      isExpense: recurring.isExpense,
      category: recurring.category,
      userId: recurring.userId,
      status: TransactionStatus.completed,
      recurringTransactionId: recurring.id,
    );

    await ref.read(moneyRepositoryProvider).addTransaction(transaction);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${recurring.title} confirmé'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildUpcomingSection(
    BuildContext context,
    EstimatedBalanceData balanceData,
    ColorScheme colorScheme,
  ) {
    // Transactions à venir (pas encore échues)
    final upcoming = balanceData.pendingRecurring
        .where((p) => !p.isDue)
        .toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

    if (upcoming.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(
                Icons.schedule,
                color: colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Prochaines échéances',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: upcoming.take(5).map((pending) {
              final r = pending.recurring;
              final daysUntil = pending.scheduledDate.day - DateTime.now().day;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${pending.scheduledDate.day}',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.title,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          Text(
                            'Dans $daysUntil jour${daysUntil > 1 ? 's' : ''}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${r.isExpense ? '-' : '+'}${r.amount.toStringAsFixed(0)}€',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                r.isExpense ? colorScheme.error : Colors.green,
                          ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
