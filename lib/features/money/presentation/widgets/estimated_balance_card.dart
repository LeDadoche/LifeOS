import 'package:flutter/material.dart';
import '../../data/money_repository.dart';
import '../../data/privacy_provider.dart';

/// Widget principal - Affiche le "Solde Estimé" de manière sobre et professionnelle
class EstimatedBalanceCard extends StatelessWidget {
  final EstimatedBalanceData data;
  final bool isPrivacyMode;

  const EstimatedBalanceCard({
    super.key,
    required this.data,
    this.isPrivacyMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final amount = data.estimatedBalance;

    // Couleurs neutres basées sur le statut
    final Color statusColor;
    final IconData statusIcon;
    final String statusMessage;

    if (amount >= 500) {
      statusColor = Colors.green.shade700;
      statusIcon = Icons.check_circle_outline;
      statusMessage = 'Prévision à l\'équilibre';
    } else if (amount >= 100) {
      statusColor = Colors.orange.shade700;
      statusIcon = Icons.info_outline;
      statusMessage = 'Marge de sécurité réduite';
    } else if (amount >= 0) {
      statusColor = Colors.deepOrange.shade700;
      statusIcon = Icons.warning_amber_outlined;
      statusMessage = 'Vigilance recommandée';
    } else {
      statusColor = Colors.red.shade700;
      statusIcon = Icons.trending_down;
      statusMessage = 'Écart à combler : ${(-amount).toStringAsFixed(0)}€';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec icône de statut
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Solde Estimé',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      amount >= 0 ? 'OK' : 'ALERTE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Montant principal
          Center(
            child: Column(
              children: [
                Text(
                  'Disponibilité Réelle',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatAmount(amount, isPrivacyMode, decimals: 0),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  statusMessage,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: statusColor,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Détails du calcul
          _buildCalculationDetails(context, colorScheme),

          // Jauge Budget Courses Hebdomadaire
          if (data.weeklyGroceryBudget > 0) ...[
            const SizedBox(height: 16),
            _buildWeeklyGroceryGauge(context, colorScheme),
          ],
        ],
      ),
    );
  }

  Widget _buildCalculationDetails(
      BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            context,
            'Solde actuel',
            data.currentBalance,
            Icons.account_balance,
            data.currentBalance >= 0
                ? Colors.green.shade700
                : Colors.red.shade700,
          ),
          if (data.pendingSalary > 0) ...[
            const SizedBox(height: 6),
            _buildDetailRow(
              context,
              'Revenus à percevoir',
              data.pendingSalary,
              Icons.arrow_upward,
              Colors.blue.shade700,
              prefix: '+',
            ),
          ],
          const SizedBox(height: 6),
          _buildDetailRow(
            context,
            'Charges fixes restantes',
            -data.remainingFixedExpenses,
            Icons.receipt_long,
            Colors.orange.shade700,
          ),
          if (data.groceryBudgetRemaining > 0) ...[
            const SizedBox(height: 6),
            _buildDetailRow(
              context,
              'Courses (${data.remainingWeeks} sem. × ${data.weeklyGroceryBudget.toStringAsFixed(0)}€)',
              -data.groceryBudgetRemaining,
              Icons.shopping_cart_outlined,
              Colors.purple.shade700,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeeklyGroceryGauge(
      BuildContext context, ColorScheme colorScheme) {
    final weeklyBudget = data.weeklyGroceryBudget;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shopping_basket,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Budget Courses Semaine',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Text(
                isPrivacyMode ? '***€' : '${weeklyBudget.toStringAsFixed(0)}€',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Barre de progression simple
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 1.0, // Budget alloué à 100%
              backgroundColor: colorScheme.surfaceContainerHighest,
              color: colorScheme.primary,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${data.remainingWeeks} semaine${data.remainingWeeks > 1 ? 's' : ''} restante${data.remainingWeeks > 1 ? 's' : ''} = ${data.groceryBudgetRemaining.toStringAsFixed(0)}€ réservés',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    double amount,
    IconData icon,
    Color color, {
    String prefix = '',
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Text(
          isPrivacyMode ? '***€' : '$prefix${amount.toStringAsFixed(0)}€',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
        ),
      ],
    );
  }
}
