import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/home_widget_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../data/task_model.dart';
import '../../data/tasks_repository.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTask() {
    final title = _controller.text.trim();
    if (title.isNotEmpty) {
      _showAddTaskDialog(title);
      _controller.clear();
    }
  }

  Future<void> _showAddTaskDialog(String title) async {
    DateTime? dueDate;
    bool isStarred = false;
    TaskReminderOption reminderOption = TaskReminderOption.none;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nouvelle tâche'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),

                // Due Date
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.calendar_today,
                      color: dueDate != null
                          ? Theme.of(context).colorScheme.primary
                          : null),
                  title: Text(dueDate != null
                      ? DateFormat('EEE d MMM yyyy, HH:mm', 'fr_FR')
                          .format(dueDate!)
                      : 'Ajouter une échéance'),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: dueDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 2)),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime:
                            TimeOfDay.fromDateTime(dueDate ?? DateTime.now()),
                      );
                      setDialogState(() {
                        if (time != null) {
                          dueDate = DateTime(date.year, date.month, date.day,
                              time.hour, time.minute);
                        } else {
                          dueDate =
                              DateTime(date.year, date.month, date.day, 23, 59);
                        }
                      });
                    }
                  },
                  trailing: dueDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setDialogState(() => dueDate = null),
                        )
                      : null,
                ),

                // Reminder (only if due date is set)
                if (dueDate != null) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.notifications_outlined,
                        color: reminderOption != TaskReminderOption.none
                            ? Theme.of(context).colorScheme.primary
                            : null),
                    title: Text(reminderOption.label),
                    onTap: () async {
                      final selected = await showDialog<TaskReminderOption>(
                        context: context,
                        builder: (ctx) => SimpleDialog(
                          title: const Text('Rappel'),
                          children: TaskReminderOption.values
                              .map(
                                (option) => SimpleDialogOption(
                                  onPressed: () => Navigator.pop(ctx, option),
                                  child: Row(
                                    children: [
                                      Icon(option.icon),
                                      const SizedBox(width: 12),
                                      Text(option.label),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      );
                      if (selected != null) {
                        setDialogState(() => reminderOption = selected);
                      }
                    },
                  ),
                ],

                // Starred
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(isStarred ? Icons.star : Icons.star_border,
                      color: isStarred ? Colors.amber : null),
                  title: const Text('Important'),
                  value: isStarred,
                  onChanged: (value) => setDialogState(() => isStarred = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final taskId = await ref.read(tasksRepositoryProvider).addTask(
            title,
            dueDate: dueDate,
            isStarred: isStarred,
            reminderMinutes: reminderOption.minutes,
          );

      // Schedule notification if reminder is set
      if (taskId != null &&
          reminderOption != TaskReminderOption.none &&
          dueDate != null) {
        final task = await ref.read(tasksRepositoryProvider).getTask(taskId);
        if (task != null) {
          await NotificationService().scheduleTaskReminder(task);
        }
      }

      // Update widget
      HomeWidgetService().updateTasksWidget();
    }
  }

  Future<void> _showEditTaskDialog(Task task) async {
    DateTime? dueDate = task.dueDate;
    bool isStarred = task.isStarred;
    TaskReminderOption reminderOption = task.reminderOption;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(task.title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Due Date
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.calendar_today,
                      color: dueDate != null
                          ? Theme.of(context).colorScheme.primary
                          : null),
                  title: Text(dueDate != null
                      ? DateFormat('EEE d MMM yyyy, HH:mm', 'fr_FR')
                          .format(dueDate!)
                      : 'Ajouter une échéance'),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: dueDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 2)),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime:
                            TimeOfDay.fromDateTime(dueDate ?? DateTime.now()),
                      );
                      setDialogState(() {
                        if (time != null) {
                          dueDate = DateTime(date.year, date.month, date.day,
                              time.hour, time.minute);
                        } else {
                          dueDate =
                              DateTime(date.year, date.month, date.day, 23, 59);
                        }
                      });
                    }
                  },
                  trailing: dueDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setDialogState(() => dueDate = null),
                        )
                      : null,
                ),

                // Reminder
                if (dueDate != null) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.notifications_outlined,
                        color: reminderOption != TaskReminderOption.none
                            ? Theme.of(context).colorScheme.primary
                            : null),
                    title: Text(reminderOption.label),
                    onTap: () async {
                      final selected = await showDialog<TaskReminderOption>(
                        context: context,
                        builder: (ctx) => SimpleDialog(
                          title: const Text('Rappel'),
                          children: TaskReminderOption.values
                              .map(
                                (option) => SimpleDialogOption(
                                  onPressed: () => Navigator.pop(ctx, option),
                                  child: Row(
                                    children: [
                                      Icon(option.icon),
                                      const SizedBox(width: 12),
                                      Text(option.label),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      );
                      if (selected != null) {
                        setDialogState(() => reminderOption = selected);
                      }
                    },
                  ),
                ],

                // Starred
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(isStarred ? Icons.star : Icons.star_border,
                      color: isStarred ? Colors.amber : null),
                  title: const Text('Important'),
                  value: isStarred,
                  onChanged: (value) => setDialogState(() => isStarred = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final updatedTask = task.copyWith(
        dueDate: () => dueDate,
        isStarred: isStarred,
        reminderMinutes: () => reminderOption.minutes,
      );

      await ref.read(tasksRepositoryProvider).updateTask(updatedTask);

      // Update notification
      if (task.id != null) {
        await NotificationService().cancelTaskReminder(task.id!);
        if (updatedTask.shouldScheduleNotification) {
          await NotificationService().scheduleTaskReminder(updatedTask);
        }
      }

      // Update widget
      HomeWidgetService().updateTasksWidget();
    }
  }

  /// Delete a task with SnackBar undo option
  Future<void> _deleteTaskWithUndo(Task task) async {
    if (task.id == null) return;

    // Cancel any scheduled notification
    await NotificationService().cancelTaskReminder(task.id!);

    // Delete the task
    await ref.read(tasksRepositoryProvider).deleteTask(task.id!);

    // Update widget
    HomeWidgetService().updateTasksWidget();

    // Show SnackBar with undo option
    if (!mounted) return;

    SnackBarUtils.show(
      context,
      message: '« ${task.title} » supprimée',
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'Annuler',
        onPressed: () async {
          // Restore the task
          await ref.read(tasksRepositoryProvider).addTask(
            task.title,
            dueDate: task.dueDate,
            isStarred: task.isStarred,
            reminderMinutes: task.reminderMinutes,
          );

          // Update widget
          HomeWidgetService().updateTasksWidget();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Mes Tâches'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => HomeWidgetService().updateTasksWidget(),
            tooltip: 'Rafraîchir widget',
          ),
        ],
      ),
      body: Column(
        children: [
          // Zone de saisie isolée avec RepaintBoundary pour éviter les rebuilds MIUI
          RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Ajouter une tâche...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addTask(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton.filled(
                    onPressed: _addTask,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ),
          // Liste des tâches dans un Consumer séparé pour isoler les rebuilds
          Expanded(
            child: _TasksListView(
              onToggle: (task) async {
                await ref.read(tasksRepositoryProvider).toggleTask(task);
                if (!task.isCompleted && task.id != null) {
                  await NotificationService().cancelTaskReminder(task.id!);
                }
                HomeWidgetService().updateTasksWidget();
              },
              onToggleStar: (task) async {
                await ref.read(tasksRepositoryProvider).toggleStar(task);
                HomeWidgetService().updateTasksWidget();
              },
              onTap: _showEditTaskDialog,
              onDelete: _deleteTaskWithUndo,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget isolé pour la liste des tâches - évite les rebuilds du TextField sur MIUI
class _TasksListView extends ConsumerWidget {
  final Future<void> Function(Task) onToggle;
  final Future<void> Function(Task) onToggleStar;
  final void Function(Task) onTap;
  final void Function(Task) onDelete;

  const _TasksListView({
    required this.onToggle,
    required this.onToggleStar,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return tasksAsync.when(
      data: (tasks) {
        if (tasks.isEmpty) {
          return Center(
            child: Text('Aucune tâche pour le moment 🎉',
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
          );
        }

        // Sort: starred first, then by due date
        final sortedTasks = List.of(tasks)
          ..sort((a, b) {
            // Completed tasks last
            if (a.isCompleted != b.isCompleted) {
              return a.isCompleted ? 1 : -1;
            }
            // Starred first
            if (a.isStarred != b.isStarred) {
              return a.isStarred ? -1 : 1;
            }
            // Then by due date
            if (a.dueDate != null && b.dueDate != null) {
              return a.dueDate!.compareTo(b.dueDate!);
            }
            if (a.dueDate != null) return -1;
            if (b.dueDate != null) return 1;
            return 0;
          });

        return ListView.builder(
          itemCount: sortedTasks.length,
          itemBuilder: (context, index) {
            final task = sortedTasks[index];
            return _TaskListItem(
              task: task,
              onToggle: () => onToggle(task),
              onToggleStar: () => onToggleStar(task),
              onTap: () => onTap(task),
              onDelete: () => onDelete(task),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Erreur: $error')),
    );
  }
}

class _TaskListItem extends StatelessWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onToggleStar;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TaskListItem({
    required this.task,
    required this.onToggle,
    required this.onToggleStar,
    required this.onTap,
    required this.onDelete,
  });

  /// Formate la date de manière lisible ("Hier", "Aujourd'hui", "Demain", ou "Mar. 24 déc.")
  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final difference = dateOnly.difference(today).inDays;

    if (difference == 0) {
      return 'Aujourd\'hui';
    } else if (difference == -1) {
      return 'Hier';
    } else if (difference == 1) {
      return 'Demain';
    } else if (difference == -2) {
      return 'Avant-hier';
    } else {
      // Format: "Mar. 24 déc."
      return DateFormat('EEE d MMM', 'fr_FR').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOverdue = task.isOverdue;

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        // Laisser l'animation se terminer AVANT que le stream ne mette à jour
        // pour éviter l'erreur "A dismissed Dismissible widget is still part of the tree"
        onDelete();
        return true; // Retourner true permet l'animation complète avant rebuild
      },
      background: Container(
        color: colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Icon(Icons.delete, color: colorScheme.onError),
      ),
      child: GestureDetector(
        onSecondaryTapDown: (details) {
          _showContextMenu(context, details.globalPosition);
        },
        onLongPressStart: (details) {
          HapticFeedback.mediumImpact();
          _showContextMenu(context, details.globalPosition);
        },
        child: ListTile(
          leading: IconButton(
            icon: Icon(
              task.isCompleted
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: task.isCompleted ? colorScheme.primary : null,
            ),
            onPressed: onToggle,
          ),
          title: Text(
            task.title,
            style: TextStyle(
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              color: task.isCompleted
                  ? colorScheme.onSurface.withOpacity(0.5)
                  : colorScheme.onSurface,
            ),
          ),
          subtitle: task.dueDate != null
              ? Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 12,
                        color: isOverdue
                            ? Colors.red.shade600
                            : colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      _formatDueDate(task.dueDate!),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isOverdue ? FontWeight.w600 : null,
                        color: isOverdue
                            ? Colors.red.shade600
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (task.hasReminder) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.notifications_outlined,
                          size: 12, color: colorScheme.onSurfaceVariant),
                    ],
                  ],
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  task.isStarred ? Icons.star : Icons.star_border,
                  color: task.isStarred ? Colors.amber : null,
                ),
                onPressed: onToggleStar,
              ),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }

  /// Affiche le menu contextuel à la position donnée
  void _showContextMenu(BuildContext context, Offset position) {
    final colorScheme = Theme.of(context).colorScheme;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 20, color: colorScheme.onSurface),
              const SizedBox(width: 12),
              const Text('Modifier'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'star',
          child: Row(
            children: [
              Icon(
                task.isStarred ? Icons.star : Icons.star_border,
                size: 20,
                color: task.isStarred ? Colors.amber : colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Text(task.isStarred
                  ? 'Retirer des importants'
                  : 'Marquer important'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'complete',
          child: Row(
            children: [
              Icon(
                task.isCompleted
                    ? Icons.radio_button_unchecked
                    : Icons.check_circle,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(task.isCompleted
                  ? 'Marquer non terminée'
                  : 'Marquer terminée'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 20, color: colorScheme.error),
              const SizedBox(width: 12),
              Text('Supprimer', style: TextStyle(color: colorScheme.error)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;

      switch (value) {
        case 'edit':
          onTap();
          break;
        case 'star':
          onToggleStar();
          break;
        case 'complete':
          onToggle();
          break;
        case 'delete':
          onDelete();
          break;
      }
    });
  }
}
