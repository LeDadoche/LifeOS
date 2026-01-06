import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../data/transaction_model.dart';

class MoneyStatsWidget extends StatelessWidget {
  final List<Transaction> transactions;

  const MoneyStatsWidget({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    double income = 0;
    double expense = 0;

    for (var t in transactions) {
      if (t.isExpense) {
        expense += t.amount;
      } else {
        income += t.amount;
      }
    }

    final double balance = income - expense;
    final bool hasData = income > 0 || expense > 0;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Balance Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Flexible(
                    child: _buildStatItem(
                        context, 'Revenus', income, Colors.green)),
                Flexible(
                    child: _buildStatItem(
                        context, 'Dépenses', expense, colorScheme.error)),
                Flexible(
                    child: _buildStatItem(
                        context, 'Solde', balance, colorScheme.onSurface)),
              ],
            ),
            const SizedBox(height: 16),

            // Chart - hauteur réduite et flexible
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 150, minHeight: 100),
              child: hasData
                  ? PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: [
                          if (income > 0)
                            PieChartSectionData(
                              color: Colors.green,
                              value: income,
                              title:
                                  '${((income / (income + expense)) * 100).toStringAsFixed(0)}%',
                              radius: 50,
                              titleStyle: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                          if (expense > 0)
                            PieChartSectionData(
                              color: colorScheme.error,
                              value: expense,
                              title:
                                  '${((expense / (income + expense)) * 100).toStringAsFixed(0)}%',
                              radius: 50,
                              titleStyle: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onError,
                              ),
                            ),
                        ],
                      ),
                    )
                  : Center(
                      child: Text(
                        'Aucune donnée',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      BuildContext context, String label, double value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${value.toStringAsFixed(2)} €',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
    );
  }
}
