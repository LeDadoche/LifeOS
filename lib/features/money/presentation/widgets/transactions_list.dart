import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/transaction_model.dart';
import '../../data/models/budget_category_model.dart';

/// Widget affichant la liste des transactions avec un design premium
class TransactionsList extends StatelessWidget {
  final List<Transaction> transactions;
  final Function(Transaction)? onTransactionTap;
  final Function(Transaction)? onTransactionDelete;
  final bool showScheduledFirst;
  final bool isPrivacyMode;

  const TransactionsList({
    super.key,
    required this.transactions,
    this.onTransactionTap,
    this.onTransactionDelete,
    this.showScheduledFirst = true,
    this.isPrivacyMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 64,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Aucune transaction',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ajoutez votre première transaction',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // Séparer les transactions prévues des transactions passées
    final scheduled = transactions.where((t) => t.isScheduled).toList();
    final completed = transactions.where((t) => !t.isScheduled).toList();

    // Grouper par date
    final groupedCompleted = _groupByDate(completed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Transactions prévues
        if (scheduled.isNotEmpty && showScheduledFirst) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Transactions prévues',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          ...scheduled.map((t) => _TransactionTile(
                transaction: t,
                isPrivacyMode: isPrivacyMode,
                onTap: onTransactionTap != null
                    ? () => onTransactionTap!(t)
                    : null,
                onDelete: onTransactionDelete != null
                    ? () => onTransactionDelete!(t)
                    : null,
              )),
          const Divider(height: 32),
        ],

        // Transactions passées groupées par date
        ...groupedCompleted.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  entry.key,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
              ...entry.value.map((t) => _TransactionTile(
                    transaction: t,
                    isPrivacyMode: isPrivacyMode,
                    onTap: onTransactionTap != null
                        ? () => onTransactionTap!(t)
                        : null,
                    onDelete: onTransactionDelete != null
                        ? () => onTransactionDelete!(t)
                        : null,
                  )),
            ],
          );
        }),
      ],
    );
  }

  Map<String, List<Transaction>> _groupByDate(List<Transaction> transactions) {
    final grouped = <String, List<Transaction>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var t in transactions) {
      final date = DateTime(t.date.year, t.date.month, t.date.day);
      String label;

      if (date == today) {
        label = "Aujourd'hui";
      } else if (date == yesterday) {
        label = 'Hier';
      } else if (date.isAfter(today.subtract(const Duration(days: 7)))) {
        label = DateFormat('EEEE', 'fr_FR').format(date);
        label = label[0].toUpperCase() + label.substring(1);
      } else {
        label = DateFormat('d MMMM yyyy', 'fr_FR').format(date);
      }

      grouped.putIfAbsent(label, () => []).add(t);
    }

    return grouped;
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool isPrivacyMode;

  const _TransactionTile({
    required this.transaction,
    this.onTap,
    this.onDelete,
    this.isPrivacyMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isExpense = transaction.isExpense;
    final isScheduled = transaction.isScheduled;

    final amountColor = isExpense ? colorScheme.error : Colors.green;
    final categoryColor = _getCategoryColor(transaction.category);
    final categoryIcon = _getCategoryIcon(transaction.category);

    return Dismissible(
      key: Key('transaction_${transaction.id}'),
      direction: onDelete != null
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: colorScheme.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Supprimer'),
                content: Text('Supprimer "${transaction.title}" ?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(
                        foregroundColor: colorScheme.error),
                    child: const Text('Supprimer'),
                  ),
                ],
              ),
            ) ??
            false;
        
        // Si confirmé, supprimer IMMÉDIATEMENT avant que l'animation ne se termine
        // pour éviter l'erreur "A dismissed Dismissible widget is still part of the tree"
        if (confirmed) {
          onDelete?.call();
        }
        return false; // On retourne toujours false car la suppression est gérée par le stream
      },
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: (isScheduled ? Colors.grey : categoryColor)
                .withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isScheduled ? Icons.schedule : categoryIcon,
            color: isScheduled ? Colors.grey : categoryColor,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                transaction.title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isScheduled
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.onSurface,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isScheduled)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Prévue',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            if (transaction.category != null) ...[
              Text(
                transaction.category!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              Text(
                ' • ',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
            Text(
              DateFormat('dd/MM').format(transaction.date),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            if (transaction.recurringTransactionId != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.repeat,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
        trailing: Text(
          isPrivacyMode
              ? '***€'
              : '${isExpense ? '-' : '+'}${transaction.amount.toStringAsFixed(2)} €',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isScheduled ? Colors.grey : amountColor,
              ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String? category) {
    if (category == null) return Colors.grey;

    final defaultCat = DefaultCategories.categories.firstWhere(
      (c) => c['name'] == category,
      orElse: () => {'color': '#607D8B'},
    );
    return getColorFromHex(defaultCat['color'] as String);
  }

  IconData _getCategoryIcon(String? category) {
    if (category == null) return Icons.receipt;

    final defaultCat = DefaultCategories.categories.firstWhere(
      (c) => c['name'] == category,
      orElse: () => {'icon_name': 'receipt'},
    );
    return getIconByName(defaultCat['icon_name'] as String?);
  }
}
