import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/money_repository.dart';
import '../widgets/money_stats_widget.dart';

class MoneyScreen extends ConsumerWidget {
  const MoneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Finances'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: MoneyStatsWidget(transactions: transactions),
                ),
                // Liste des transactions
                if (transactions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text('Aucune transaction',
                        style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  )
                else
                  ...transactions.map((transaction) => ListTile(
                        leading: Icon(
                          transaction.isExpense
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: transaction.isExpense
                              ? colorScheme.error
                              : Colors.green,
                        ),
                        title: Text(transaction.title,
                            style: TextStyle(color: colorScheme.onSurface)),
                        subtitle: Text(
                            DateFormat('dd-MM-yyyy').format(transaction.date),
                            style:
                                TextStyle(color: colorScheme.onSurfaceVariant)),
                        trailing: Text(
                          '${transaction.isExpense ? "-" : "+"}${transaction.amount.toStringAsFixed(2)} €',
                          style: TextStyle(
                            color: transaction.isExpense
                                ? colorScheme.error
                                : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onLongPress: () {
                          if (transaction.id != null) {
                            ref
                                .read(moneyRepositoryProvider)
                                .deleteTransaction(transaction.id!);
                          }
                        },
                      )),
                const SizedBox(height: 80), // Espace pour le FAB
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
            child: Text('Erreur: $error',
                style: TextStyle(color: colorScheme.error))),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/money/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
