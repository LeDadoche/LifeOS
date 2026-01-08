import 'package:flutter/material.dart';
import '../../data/money_repository.dart';
import '../../data/models/recurring_transaction_model.dart';

/// Widget pour confirmer rapidement les transactions permanentes en attente
/// Affiche des boutons "Loyer payé ? [OUI]" sans saisie manuelle
class QuickConfirmationCards extends StatelessWidget {
  final List<PendingRecurring> pendingRecurring;
  final Function(RecurringTransaction) onConfirm;

  const QuickConfirmationCards({
    super.key,
    required this.pendingRecurring,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    // Ne montrer que les transactions dont la date est passée ou aujourd'hui
    final dueTransactions = pendingRecurring.where((p) => p.isDue).toList();
    
    if (dueTransactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(
                Icons.notifications_active,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'À confirmer',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...dueTransactions.map((pending) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ConfirmationCard(
            pending: pending,
            onConfirm: () => onConfirm(pending.recurring),
          ),
        )),
      ],
    );
  }
}

class _ConfirmationCard extends StatelessWidget {
  final PendingRecurring pending;
  final VoidCallback onConfirm;

  const _ConfirmationCard({
    required this.pending,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final transaction = pending.recurring;
    final daysLate = DateTime.now().day - pending.scheduledDate.day;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icône
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              transaction.isExpense ? Icons.receipt_long : Icons.attach_money,
              color: colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          
          // Détails
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${transaction.amount.toStringAsFixed(0)}€',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: transaction.isExpense 
                            ? colorScheme.error 
                            : Colors.green,
                      ),
                    ),
                    Text(
                      ' • Prévu le ${pending.scheduledDate.day}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (daysLate > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '+$daysLate j',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Bouton de confirmation
          FilledButton.tonal(
            onPressed: onConfirm,
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, size: 18),
                SizedBox(width: 4),
                Text('OUI'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
