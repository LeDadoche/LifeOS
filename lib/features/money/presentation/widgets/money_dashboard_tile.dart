import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/money_repository.dart';
import '../../../settings/presentation/providers/widget_style_provider.dart';

class MoneyDashboardTile extends ConsumerWidget {
  const MoneyDashboardTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final style = ref.watch(widgetStyleProvider((
      type: 'money',
      defaultColor: Colors.green,
      defaultIcon: Icons.attach_money,
    )));

    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = style.color;
    // Glassmorphism: semi-transparent surfaceContainer with primary tint
    final containerColor = colorScheme.surfaceContainerHighest.withOpacity(0.7);
    final onContainerColor = primaryColor;

    return Card(
      elevation: 4,
      shadowColor: primaryColor.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      color: containerColor,
      child: InkWell(
        onTap: () => context.push('/money'),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            border:
                Border.all(color: primaryColor.withOpacity(0.2), width: 1.5),
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor.withOpacity(0.08),
                primaryColor.withOpacity(0.02),
              ],
            ),
          ),
          padding: const EdgeInsets.all(16.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return transactionsAsync.when(
                data: (transactions) {
                  double income = 0;
                  double expense = 0;
                  for (var t in transactions) {
                    if (t.isExpense) {
                      expense += t.amount;
                    } else {
                      income += t.amount;
                    }
                  }
                  final balance = income - expense;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(style.icon, size: 24, color: primaryColor),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Mon Solde',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: onContainerColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${balance.toStringAsFixed(2)} €',
                          maxLines: 1,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Cliquez pour détails',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: onContainerColor.withOpacity(0.8),
                            ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                    child: Text('Erreur',
                        style: TextStyle(color: colorScheme.error))),
              );
            },
          ),
        ),
      ),
    );
  }
}
