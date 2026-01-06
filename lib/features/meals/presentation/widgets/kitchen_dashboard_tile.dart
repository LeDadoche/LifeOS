import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/kitchen_repository.dart';
import '../../../settings/presentation/providers/widget_style_provider.dart';

class KitchenDashboardTile extends ConsumerWidget {
  const KitchenDashboardTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(mealsForWeekProvider);
    final shoppingListAsync = ref.watch(shoppingListProvider);
    final style = ref.watch(widgetStyleProvider((
      type: 'kitchen',
      defaultColor: Colors.pinkAccent,
      defaultIcon: Icons.restaurant_menu,
    )));

    final primaryColor = style.color;
    final colorScheme = Theme.of(context).colorScheme;
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
        onTap: () => context.push('/kitchen'),
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
          padding: const EdgeInsets.all(10.0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180, maxHeight: 200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // En-tête avec icône
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(style.icon, size: 18, color: primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        'Cuisine',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: onContainerColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Repas du créneau actuel
                  mealsAsync.when(
                    data: (meals) {
                      final now = DateTime.now();
                      final showLunch = now.hour < 15;

                      final todayMeals = meals.where((m) =>
                          m.date.year == now.year &&
                          m.date.month == now.month &&
                          m.date.day == now.day);

                      final currentMeal = todayMeals
                          .where((m) => m.isLunch == showLunch)
                          .firstOrNull;
                      final hasMeal = currentMeal != null &&
                          currentMeal.description.isNotEmpty;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Badge créneau
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (showLunch ? Colors.orange : Colors.indigo)
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  showLunch
                                      ? Icons.wb_sunny
                                      : Icons.nightlight_round,
                                  size: 10,
                                  color:
                                      showLunch ? Colors.orange : Colors.indigo,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  showLunch ? 'Déj' : 'Dîn',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: showLunch
                                        ? Colors.orange.shade700
                                        : Colors.indigo.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Description
                          Text(
                            hasMeal ? currentMeal.description : 'Rien de prévu',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: hasMeal
                                          ? onContainerColor
                                          : onContainerColor.withOpacity(0.6),
                                      fontWeight: hasMeal
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontStyle: hasMeal
                                          ? FontStyle.normal
                                          : FontStyle.italic,
                                    ),
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    error: (_, __) => Icon(Icons.error,
                        size: 16, color: Theme.of(context).colorScheme.error),
                  ),

                  const SizedBox(height: 4),

                  // Compteur de courses
                  shoppingListAsync.when(
                    data: (items) {
                      final count = items.where((i) => !i.isBought).length;
                      if (count == 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shopping_cart_outlined,
                                size: 10, color: primaryColor),
                            const SizedBox(width: 2),
                            Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 10,
                                color: primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
