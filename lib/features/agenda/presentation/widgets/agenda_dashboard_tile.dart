import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/agenda_repository.dart';
import '../../../settings/presentation/providers/widget_style_provider.dart';

class AgendaDashboardTile extends ConsumerWidget {
  const AgendaDashboardTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingEventsAsync = ref.watch(upcomingEventsProvider);
    final style = ref.watch(widgetStyleProvider((
      type: 'agenda',
      defaultColor: Colors.blueAccent,
      defaultIcon: Icons.calendar_today,
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
        onTap: () => context.push('/agenda'),
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
                          DateFormat('dd MMM').format(DateTime.now()),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: onContainerColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  upcomingEventsAsync.when(
                    data: (events) {
                      if (events.isEmpty) {
                        return Column(
                          children: [
                            Text(
                              'Rien de prévu',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              '🎉',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ],
                        );
                      }

                      final nextEvent = events.first;
                      return Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Prochain RDV :',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: onContainerColor.withOpacity(0.8),
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              nextEvent.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              DateFormat('HH:mm').format(nextEvent.date),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: onContainerColor,
                                  ),
                            ),
                          ],
                        ),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (err, stack) => Icon(Icons.error,
                        color: Theme.of(context).colorScheme.error),
                  ),
                  const Spacer(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
