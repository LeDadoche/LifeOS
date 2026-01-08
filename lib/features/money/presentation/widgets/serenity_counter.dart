import 'package:flutter/material.dart';
import '../../data/money_repository.dart';
import '../../data/privacy_provider.dart';

/// Widget principal du mode "Pas de stress"
/// Affiche un gros compteur "Sérénité : Il te reste X€"
class SerenityCounter extends StatelessWidget {
  final SerenityData serenity;
  final bool isPrivacyMode;

  const SerenityCounter({
    super.key,
    required this.serenity,
    this.isPrivacyMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final amount = serenity.serenityAmount;
    
    // Déterminer la couleur selon le montant
    final Color statusColor;
    final IconData statusIcon;
    final String statusMessage;
    
    if (amount >= 500) {
      statusColor = Colors.green;
      statusIcon = Icons.sentiment_very_satisfied;
      statusMessage = 'Tu es tranquille ! 😊';
    } else if (amount >= 100) {
      statusColor = Colors.orange;
      statusIcon = Icons.sentiment_neutral;
      statusMessage = 'Attention aux dépenses 🤔';
    } else if (amount >= 0) {
      statusColor = Colors.deepOrange;
      statusIcon = Icons.sentiment_dissatisfied;
      statusMessage = 'Budget serré ce mois-ci 😬';
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.warning_amber_rounded;
      statusMessage = 'Objectif remontée ! 💪';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusColor.withValues(alpha: 0.15),
            colorScheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Icône de statut
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              statusIcon,
              size: 48,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 16),

          // Titre "Sérénité"
          Text(
            '✨ Sérénité ✨',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),

          // Gros compteur
          Text(
            'Il te reste',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatAmount(amount, isPrivacyMode, decimals: 0),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: statusColor,
              fontSize: 56,
            ),
          ),
          const SizedBox(height: 8),

          // Message de statut
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Détails du calcul (collapsible)
          _buildCalculationDetails(context, colorScheme),
        ],
      ),
    );
  }

  Widget _buildCalculationDetails(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            context,
            'Solde actuel',
            serenity.currentBalance,
            Icons.account_balance_wallet,
            serenity.currentBalance >= 0 ? Colors.green : Colors.red,
          ),
          if (serenity.pendingSalary > 0) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              context,
              'Salaire à venir',
              serenity.pendingSalary,
              Icons.add_circle_outline,
              Colors.blue,
              prefix: '+',
            ),
          ],
          const SizedBox(height: 8),
          _buildDetailRow(
            context,
            'Charges fixes restantes',
            -serenity.remainingFixedExpenses,
            Icons.receipt_long,
            Colors.orange,
          ),
          if (serenity.variableBudget > 0) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              context,
              'Budget variable (réservé)',
              -serenity.variableBudget,
              Icons.shopping_cart,
              Colors.purple,
            ),
          ],
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
        Icon(icon, size: 18, color: color),
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
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
