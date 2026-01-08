import 'package:flutter/material.dart';
import '../../data/models/budget_category_model.dart';

/// Widget affichant les barres de progression des budgets par catégorie
class BudgetProgressBars extends StatelessWidget {
  final Map<String, double> categoryExpenses;
  final List<BudgetCategory> categories;
  final bool isPrivacyMode;

  const BudgetProgressBars({
    super.key,
    required this.categoryExpenses,
    required this.categories,
    this.isPrivacyMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Filtrer les catégories avec un budget défini
    final categoriesWithBudget =
        categories.where((c) => c.budgetLimit > 0).toList();

    if (categoriesWithBudget.isEmpty) {
      return Card(
        elevation: 0,
        color: colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.bar_chart,
                size: 48,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Aucun budget défini',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Définissez des plafonds pour vos catégories',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Suivi des budgets',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...categoriesWithBudget.map((category) {
              final spent = categoryExpenses[category.name] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _BudgetProgressBar(
                  category: category.name,
                  spent: spent,
                  limit: category.budgetLimit,
                  color: category.colorValue,
                  icon: category.icon,
                  isPrivacyMode: isPrivacyMode,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _BudgetProgressBar extends StatelessWidget {
  final String category;
  final double spent;
  final double limit;
  final Color color;
  final IconData icon;
  final bool isPrivacyMode;

  const _BudgetProgressBar({
    required this.category,
    required this.spent,
    required this.limit,
    required this.color,
    required this.icon,
    this.isPrivacyMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ratio = limit > 0 ? (spent / limit).clamp(0.0, 1.5) : 0.0;
    final percentage = (ratio * 100).clamp(0.0, 150.0);
    final isOverBudget = spent > limit;
    final isNearLimit = ratio >= 0.8 && !isOverBudget;

    final progressColor = isOverBudget
        ? colorScheme.error
        : isNearLimit
            ? Colors.orange
            : color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête avec icône, nom et montants
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                category,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            Text(
              isPrivacyMode
                  ? '*** / ***€'
                  : '${spent.toStringAsFixed(0)} / ${limit.toStringAsFixed(0)} €',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isOverBudget
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                    fontWeight:
                        isOverBudget ? FontWeight.bold : FontWeight.normal,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Barre de progression
        Stack(
          children: [
            // Fond de la barre
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            // Progression
            FractionallySizedBox(
              widthFactor: ratio.clamp(0.0, 1.0),
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isOverBudget
                        ? [Colors.orange, colorScheme.error]
                        : [color.withValues(alpha: 0.7), color],
                  ),
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: [
                    BoxShadow(
                      color: progressColor.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Indicateur de dépassement
        if (isOverBudget)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: colorScheme.error,
                ),
                const SizedBox(width: 4),
                Text(
                  'Dépassé de ${(spent - limit).toStringAsFixed(0)} €',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),

        // Indicateur proche de la limite
        if (isNearLimit)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  '${percentage.toStringAsFixed(0)}% utilisé',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
