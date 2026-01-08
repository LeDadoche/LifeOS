import 'package:flutter/material.dart';
import '../../data/models/financial_profile_model.dart';
import '../../data/privacy_provider.dart';

/// Widget affichant l'indicateur de santé financière
/// Couleur basée sur le ratio solde/salaire
class FinancialHealthIndicator extends StatelessWidget {
  final double balance;
  final FinancialProfile? profile;
  final double remainingBudget;
  final bool isPrivacyMode;

  const FinancialHealthIndicator({
    super.key,
    required this.balance,
    this.profile,
    this.remainingBudget = 0,
    this.isPrivacyMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final status = profile?.getStatus(balance) ?? FinancialStatus.unknown;
    final securityThreshold = profile?.getSecurityThreshold(balance) ?? balance;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: _getBackgroundColor(status, colorScheme),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: _getStatusColor(status).withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Titre avec icône de statut
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getStatusIcon(status),
                  color: _getStatusColor(status),
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  'Situation Financière',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Solde actuel avec grande typographie
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _getStatusColor(status).withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Solde Actuel',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatAmount(balance, isPrivacyMode),
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(status),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Indicateurs secondaires
            Row(
              children: [
                Expanded(
                  child: _buildSecondaryIndicator(
                    context,
                    'Plafond de sécurité',
                    formatAmount(securityThreshold, isPrivacyMode),
                    Icons.shield_outlined,
                    colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSecondaryIndicator(
                    context,
                    'Reste à vivre',
                    formatAmount(remainingBudget, isPrivacyMode),
                    Icons.account_balance_wallet_outlined,
                    remainingBudget >= 0 ? Colors.green : colorScheme.error,
                  ),
                ),
              ],
            ),

            // Objectif Remontée (si solde négatif)
            if (balance < 0) ...[
              const SizedBox(height: 16),
              _buildObjectifRemontee(context, balance, profile, isPrivacyMode),
            ] else ...[
              // Message de statut normal
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getStatusMessage(status),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _getStatusColor(status),
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryIndicator(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }

  /// Widget "Objectif Remontée" avec jauge de progression vers 0€
  /// Affiche un message positif et encourageant au lieu de "Découvert"
  Widget _buildObjectifRemontee(
    BuildContext context,
    double balance,
    FinancialProfile? profile,
    bool isPrivate,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final overdraftLimit = profile?.overdraftLimit ?? 0;

    // Calculer la progression: de -overdraftLimit à 0
    // Plus on se rapproche de 0, plus la barre est remplie
    final absBalance = balance.abs();
    final maxDebt = overdraftLimit > 0 ? overdraftLimit : absBalance + 500;
    final progress = ((maxDebt - absBalance) / maxDebt).clamp(0.0, 1.0);

    // Couleur dynamique basée sur la progression
    final progressColor = Color.lerp(
      Colors.red.shade400,
      Colors.green.shade500,
      progress,
    )!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            progressColor.withValues(alpha: 0.1),
            colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: progressColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.trending_up,
                  color: progressColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎯 Objectif Remontée',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPrivate
                          ? 'Plus que ***€ pour atteindre l\'équilibre !'
                          : 'Plus que ${absBalance.toStringAsFixed(0)}€ pour atteindre l\'équilibre !',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Jauge de progression
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isPrivate ? '-***€' : '-${maxDebt.toStringAsFixed(0)}€',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.red.shade400,
                        ),
                  ),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: progressColor,
                        ),
                  ),
                  Text(
                    '0€ 🎉',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.green.shade500,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Stack(
                children: [
                  // Fond de la jauge
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  // Progression
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    height: 12,
                    width: double.infinity,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red.shade400, progressColor],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: progressColor.withValues(alpha: 0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(
            _getEncouragementMessage(progress),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: progressColor,
                  fontWeight: FontWeight.w500,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getEncouragementMessage(double progress) {
    if (progress >= 0.9) {
      return '🌟 Presque ! Encore un petit effort !';
    } else if (progress >= 0.7) {
      return '💪 Super progression, continuez !';
    } else if (progress >= 0.5) {
      return '👏 Vous êtes à mi-chemin, courage !';
    } else if (progress >= 0.25) {
      return '🚀 Bon début, restez motivé !';
    } else {
      return '💡 Chaque euro compte, vous y arriverez !';
    }
  }

  Color _getStatusColor(FinancialStatus status) {
    switch (status) {
      case FinancialStatus.healthy:
        return Colors.green;
      case FinancialStatus.warning:
        return Colors.orange;
      case FinancialStatus.critical:
        return Colors.deepOrange;
      case FinancialStatus.overdraft:
        return Colors.red.shade700;
      case FinancialStatus.unknown:
        return Colors.grey;
    }
  }

  Color _getBackgroundColor(FinancialStatus status, ColorScheme colorScheme) {
    return _getStatusColor(status).withValues(alpha: 0.05);
  }

  IconData _getStatusIcon(FinancialStatus status) {
    switch (status) {
      case FinancialStatus.healthy:
        return Icons.sentiment_very_satisfied;
      case FinancialStatus.warning:
        return Icons.sentiment_neutral;
      case FinancialStatus.critical:
        return Icons.sentiment_dissatisfied;
      case FinancialStatus.overdraft:
        return Icons.warning_amber_rounded;
      case FinancialStatus.unknown:
        return Icons.help_outline;
    }
  }

  String _getStatusMessage(FinancialStatus status) {
    switch (status) {
      case FinancialStatus.healthy:
        return '✨ Excellent ! Vos finances sont saines';
      case FinancialStatus.warning:
        return '⚠️ Attention, votre solde diminue';
      case FinancialStatus.critical:
        return '🚨 Alerte ! Solde critique';
      case FinancialStatus.overdraft:
        return '❌ Découvert dépassé !';
      case FinancialStatus.unknown:
        return 'ℹ️ Configurez votre profil financier';
    }
  }
}
