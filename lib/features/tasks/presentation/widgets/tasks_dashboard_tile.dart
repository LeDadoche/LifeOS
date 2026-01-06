import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/tasks_repository.dart';
import '../../../settings/presentation/providers/widget_style_provider.dart';

class TasksDashboardTile extends ConsumerWidget {
  const TasksDashboardTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);
    final style = ref.watch(widgetStyleProvider((
      type: 'tasks',
      defaultColor: Colors.orange,
      defaultIcon: Icons.check_circle_outline,
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
        onTap: () => context.push('/tasks'),
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
              return tasksAsync.when(
                data: (tasks) {
                  final pendingTasks =
                      tasks.where((t) => !t.isCompleted).length;

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
                              'Tâches',
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
                          '$pendingTasks',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      Text(
                        pendingTasks == 0 ? 'Tout est propre ! 🎉' : 'à faire',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: onContainerColor.withOpacity(0.8),
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                    child: Text('Erreur',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
              );
            },
          ),
        ),
      ),
    );
  }
}
