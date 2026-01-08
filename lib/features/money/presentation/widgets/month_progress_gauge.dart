import 'package:flutter/material.dart';
import '../../data/money_repository.dart';

/// Jauge de progression simple du mois en cours
/// Remplace les graphiques complexes quand pas de données manuelles
class MonthProgressGauge extends StatelessWidget {
  final SerenityData serenity;
  final bool isPrivacyMode;

  const MonthProgressGauge({
    super.key,
    required this.serenity,
    this.isPrivacyMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final dayProgress = now.day / daysInMonth;
    
    // Progression basée sur les charges fixes payées
    final progress = serenity.monthProgress;
    
    // Couleur basée sur la synchronisation jour/paiements
    final isOnTrack = progress >= dayProgress - 0.1;
    final progressColor = isOnTrack ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Progression du mois',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Jauge principale
          _buildMainGauge(context, colorScheme, progress, dayProgress, progressColor),
          const SizedBox(height: 20),

          // Statistiques
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  'Charges payées',
                  serenity.paidFixedExpenses,
                  serenity.totalFixedExpenses,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Reste à payer',
                  serenity.remainingFixedExpenses,
                  serenity.totalFixedExpenses,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainGauge(
    BuildContext context,
    ColorScheme colorScheme,
    double progress,
    double dayProgress,
    Color progressColor,
  ) {
    return Column(
      children: [
        // Barre de progression avec indicateur du jour
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Fond de la jauge
            Container(
              height: 24,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            // Progression des paiements
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                height: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [progressColor.shade300, progressColor],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: progressColor.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            // Marqueur du jour actuel
            Positioned(
              left: (dayProgress.clamp(0.0, 1.0) * (MediaQuery.of(context).size.width - 80)) - 8,
              top: -8,
              child: Container(
                width: 16,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${DateTime.now().day}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Légende
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '1er',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: progressColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}% payé',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Text(
              '${DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    double value,
    double total,
    Color color,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final percentage = total > 0 ? (value / total * 100).toStringAsFixed(0) : '0';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                isPrivacyMode ? '***€' : '${value.toStringAsFixed(0)}€',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$percentage%',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension on Color {
  Color get shade300 => HSLColor.fromColor(this)
      .withLightness((HSLColor.fromColor(this).lightness + 0.2).clamp(0.0, 1.0))
      .toColor();
}
