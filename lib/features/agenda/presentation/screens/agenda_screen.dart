import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/services/home_widget_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../data/agenda_repository.dart';
import '../../data/event_model.dart';
import '../widgets/reminder_picker.dart';

class AgendaScreen extends ConsumerStatefulWidget {
  final bool openAddDialog;
  final int? highlightEventId;

  const AgendaScreen({
    super.key,
    this.openAddDialog = false,
    this.highlightEventId,
  });

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime? _lastClickTime;
  bool _dialogOpened = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;

    // Ouvrir le dialog d'ajout si demandé (depuis deep link)
    if (widget.openAddDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_dialogOpened) {
          _dialogOpened = true;
          _showAddEventDialog(context);
        }
      });
    }

    // TODO: Si highlightEventId est fourni, naviguer vers cet événement
    if (widget.highlightEventId != null) {
      debugPrint('📅 [Agenda] Highlight event ID: ${widget.highlightEventId}');
    }
  }

  void _showAddEventDialog(BuildContext context, {Event? existingEvent}) {
    final titleController =
        TextEditingController(text: existingEvent?.title ?? '');
    TimeOfDay selectedTime = existingEvent != null
        ? TimeOfDay.fromDateTime(existingEvent.date)
        : TimeOfDay.now();
    TimeOfDay? selectedEndTime = existingEvent?.endTime != null
        ? TimeOfDay.fromDateTime(existingEvent!.endTime!)
        : null;
    ReminderOption selectedReminder =
        existingEvent?.reminderOption ?? ReminderOption.none;
    final isEditing = existingEvent != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final colorScheme = Theme.of(context).colorScheme;
          // Utiliser viewInsetsOf pour éviter les rebuilds excessifs sur MIUI
          final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
          final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;

          return Container(
            margin: const EdgeInsets.all(16),
            padding: EdgeInsets.only(bottom: bottomInset),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // En-tête
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isEditing
                                ? Icons.edit_calendar
                                : Icons.event_available,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isEditing
                                ? 'Modifier l\'événement'
                                : 'Nouvel événement',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Date sélectionnée
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today,
                              size: 16, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('EEEE d MMMM yyyy', 'fr_FR')
                                .format(_selectedDay ?? DateTime.now()),
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Champ titre
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Titre de l\'événement',
                        hintText: 'Ex: Réunion, Rendez-vous...',
                        prefixIcon: const Icon(Icons.title),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest
                            .withOpacity(0.5),
                      ),
                      autofocus: !isEditing,
                      textCapitalization: TextCapitalization.sentences,
                    ),

                    const SizedBox(height: 16),

                    // Sélecteur d'heure de début
                    Semantics(
                      label: 'Sélectionner l\'heure de début',
                      button: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          final TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (picked != null && picked != selectedTime) {
                            setState(() => selectedTime = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: colorScheme.outline.withOpacity(0.5)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time,
                                  size: 20, color: colorScheme.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Heure de début',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colorScheme.outline,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      selectedTime.format(context),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right,
                                  color: colorScheme.outline),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Sélecteur d'heure de fin (optionnel)
                    Semantics(
                      label: 'Sélectionner l\'heure de fin (optionnel)',
                      button: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          final TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: selectedEndTime ??
                                TimeOfDay(
                                    hour: selectedTime.hour + 1,
                                    minute: selectedTime.minute),
                          );
                          if (picked != null) {
                            setState(() => selectedEndTime = picked);
                          }
                        },
                        onLongPress: () {
                          // Long press pour supprimer l'heure de fin
                          if (selectedEndTime != null) {
                            HapticFeedback.mediumImpact();
                            setState(() => selectedEndTime = null);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: colorScheme.outline.withOpacity(0.3)),
                            color: selectedEndTime != null
                                ? colorScheme.primaryContainer.withOpacity(0.3)
                                : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selectedEndTime != null
                                    ? Icons.timelapse
                                    : Icons.more_time,
                                size: 20,
                                color: selectedEndTime != null
                                    ? colorScheme.primary
                                    : colorScheme.outline,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Heure de fin (optionnel)',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colorScheme.outline,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      selectedEndTime?.format(context) ??
                                          'Non définie',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: selectedEndTime != null
                                                ? null
                                                : colorScheme.outline,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selectedEndTime != null)
                                IconButton(
                                  icon: Icon(Icons.clear,
                                      size: 18, color: colorScheme.outline),
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => selectedEndTime = null);
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                )
                              else
                                Icon(Icons.chevron_right,
                                    color: colorScheme.outline),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Sélecteur de rappel
                    ReminderPicker(
                      selectedOption: selectedReminder,
                      onChanged: (option) {
                        setState(() => selectedReminder = option);
                      },
                    ),

                    const SizedBox(height: 24),

                    // Boutons d'action
                    Row(
                      children: [
                        if (isEditing)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                HapticFeedback.mediumImpact();
                                if (existingEvent.id != null) {
                                  // Annuler la notification
                                  await ref
                                      .read(notificationServiceProvider)
                                      .cancelEventReminder(existingEvent.id!);
                                  // Supprimer l'événement
                                  await ref
                                      .read(agendaRepositoryProvider)
                                      .deleteEvent(existingEvent.id!);
                                  // Forcer le refresh des providers
                                  ref.invalidate(eventsForDayProvider(
                                      _selectedDay ?? DateTime.now()));
                                  ref.invalidate(
                                      eventsForMonthProvider(_focusedDay));
                                  // Synchroniser le widget
                                  await ref
                                      .read(homeWidgetServiceProvider)
                                      .updateAgendaWidget();
                                }
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Supprimer'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colorScheme.error,
                                side: BorderSide(color: colorScheme.error),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        if (isEditing) const SizedBox(width: 12),
                        Expanded(
                          flex: isEditing ? 2 : 1,
                          child: FilledButton.icon(
                            onPressed: () async {
                              if (titleController.text.isEmpty) {
                                HapticFeedback.heavyImpact();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Veuillez entrer un titre'),
                                      duration: Duration(seconds: 4)),
                                );
                                return;
                              }

                              HapticFeedback.mediumImpact();

                              final eventDate = DateTime(
                                _selectedDay!.year,
                                _selectedDay!.month,
                                _selectedDay!.day,
                                selectedTime.hour,
                                selectedTime.minute,
                              );

                              // Calculer l'heure de fin si définie
                              DateTime? eventEndTime;
                              if (selectedEndTime != null) {
                                eventEndTime = DateTime(
                                  _selectedDay!.year,
                                  _selectedDay!.month,
                                  _selectedDay!.day,
                                  selectedEndTime!.hour,
                                  selectedEndTime!.minute,
                                );
                              }

                              final userId = Supabase
                                      .instance.client.auth.currentUser?.id ??
                                  '';

                              final event = Event(
                                id: existingEvent?.id,
                                title: titleController.text,
                                date: eventDate,
                                endTime: eventEndTime,
                                isAllDay: false,
                                userId: userId,
                                reminderMinutes: selectedReminder.minutes,
                              );

                              final notificationService =
                                  ref.read(notificationServiceProvider);

                              // Validation: userId ne doit pas être vide
                              if (userId.isEmpty) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Erreur: Utilisateur non connecté'),
                                        duration: Duration(seconds: 4)),
                                  );
                                }
                                return;
                              }

                              try {
                                if (isEditing && existingEvent.id != null) {
                                  // Annuler l'ancienne notification
                                  await notificationService
                                      .cancelEventReminder(existingEvent.id!);
                                  // Mettre à jour l'événement
                                  await ref
                                      .read(agendaRepositoryProvider)
                                      .updateEvent(event);
                                } else {
                                  // Créer l'événement
                                  final newId = await ref
                                      .read(agendaRepositoryProvider)
                                      .addEvent(event);
                                  // Programmer la notification pour le nouvel événement
                                  if (newId != null &&
                                      selectedReminder != ReminderOption.none) {
                                    final eventWithId =
                                        event.copyWith(id: newId);
                                    await notificationService
                                        .scheduleEventReminder(eventWithId);
                                  }
                                }

                                // Forcer le refresh des providers pour mise à jour immédiate
                                ref.invalidate(eventsForDayProvider(
                                    _selectedDay ?? DateTime.now()));
                                ref.invalidate(
                                    eventsForMonthProvider(_focusedDay));

                                // Synchroniser le widget
                                await ref
                                    .read(homeWidgetServiceProvider)
                                    .updateAgendaWidget();

                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              } catch (e) {
                                debugPrint(
                                    '❌ [Agenda] Erreur ajout/modification: $e');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Erreur: $e'),
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: Icon(isEditing ? Icons.save : Icons.add),
                            label: Text(isEditing ? 'Enregistrer' : 'Créer'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomHeader() {
    final dateText = DateFormat.yMMMM('fr_FR').format(_focusedDay);
    final capitalizedDateText =
        dateText[0].toUpperCase() + dateText.substring(1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
              });
            },
          ),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _focusedDay,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                initialDatePickerMode: DatePickerMode.year,
                locale: const Locale('fr', 'FR'),
              );
              if (picked != null) {
                setState(() {
                  _focusedDay = picked;
                  _selectedDay = picked;
                });
              }
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Text(
                capitalizedDateText,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
              });
            },
          ),
        ],
      ),
    );
  }

  /// Construit la liste des événements
  Widget _buildEventsList(AsyncValue<List<Event>> eventsAsync) {
    final colorScheme = Theme.of(context).colorScheme;

    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Icon(
                  Icons.event_available,
                  size: 48,
                  color: colorScheme.outline.withOpacity(0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'Rien de prévu pour ce jour 🎉',
                  style: TextStyle(color: colorScheme.outline),
                ),
              ],
            ),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: events.map((event) {
            final hasReminder = event.reminderMinutes != null;
            final hasEndTime = event.endTime != null;

            return Semantics(
              label:
                  '${event.title} ${event.timeRangeFormatted}${hasReminder ? ', rappel programmé' : ''}',
              button: true,
              child: ListTile(
                dense: true,
                onTap: () {
                  HapticFeedback.selectionClick();
                  // Mettre à jour la date sélectionnée pour correspondre à l'événement
                  setState(() {
                    _selectedDay = event.date;
                  });
                  _showAddEventDialog(context, existingEvent: event);
                },
                leading: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(event.date),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                          fontSize: 12,
                        ),
                      ),
                      if (hasEndTime) ...[
                        Text(
                          '-',
                          style: TextStyle(
                            color: colorScheme.primary.withOpacity(0.5),
                            fontSize: 8,
                          ),
                        ),
                        Text(
                          DateFormat('HH:mm').format(event.endTime!),
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: colorScheme.primary.withOpacity(0.8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                title: Text(
                  event.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: hasReminder
                    ? Row(
                        children: [
                          Icon(
                            Icons.notifications_active,
                            size: 12,
                            color: colorScheme.tertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            event.reminderOption.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.tertiary,
                            ),
                          ),
                        ],
                      )
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasReminder)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.notifications_active,
                          size: 16,
                          color: colorScheme.tertiary,
                        ),
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: colorScheme.error.withOpacity(0.7),
                      ),
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        if (event.id != null) {
                          // Annuler la notification
                          await ref
                              .read(notificationServiceProvider)
                              .cancelEventReminder(event.id!);
                          // Supprimer l'événement
                          await ref
                              .read(agendaRepositoryProvider)
                              .deleteEvent(event.id!);
                          // Forcer le refresh des providers pour mise à jour immédiate
                          ref.invalidate(eventsForDayProvider(
                              _selectedDay ?? DateTime.now()));
                          ref.invalidate(eventsForMonthProvider(_focusedDay));
                          // Synchroniser le widget
                          await ref
                              .read(homeWidgetServiceProvider)
                              .updateAgendaWidget();
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(24.0),
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text('Erreur: $error'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync =
        ref.watch(eventsForDayProvider(_selectedDay ?? DateTime.now()));

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Mon Agenda'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Si on peut pop (venu d'une autre page), on pop
            // Sinon (venu d'un deep link widget), on va au dashboard
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          // Bouton de test des notifications (DEBUG)
          IconButton(
            icon: const Icon(Icons.notifications_active),
            tooltip: 'Test Notification',
            onPressed: () async {
              final notifService = ref.read(notificationServiceProvider);
              await notifService.showTestNotification();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🔔 Notification de test envoyée !'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Calculer une hauteur de calendrier adaptative
          final availableHeight = constraints.maxHeight;
          final calendarHeight = (availableHeight * 0.40).clamp(250.0, 350.0);

          // Récupérer les événements du mois pour les marqueurs
          final monthEventsAsync =
              ref.watch(eventsForMonthProvider(_focusedDay));
          final monthEvents = monthEventsAsync.valueOrNull ?? {};

          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCustomHeader(),
                // Calendrier avec hauteur adaptative
                SizedBox(
                  height: calendarHeight,
                  child: TableCalendar(
                    firstDay: DateTime.utc(2020, 10, 16),
                    lastDay: DateTime.utc(2030, 3, 14),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),

                    // Loader d'événements pour les marqueurs
                    eventLoader: (day) {
                      final dayKey = DateTime(day.year, day.month, day.day);
                      return monthEvents[dayKey] ?? [];
                    },

                    onDaySelected: (selectedDay, focusedDay) {
                      final now = DateTime.now();
                      if (_selectedDay != null &&
                          isSameDay(_selectedDay, selectedDay) &&
                          _lastClickTime != null &&
                          now.difference(_lastClickTime!) <
                              const Duration(milliseconds: 300)) {
                        _showAddEventDialog(context);
                      }

                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                        _lastClickTime = now;
                      });
                    },
                    onDayLongPressed: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                      _showAddEventDialog(context);
                    },
                    onPageChanged: (focusedDay) {
                      setState(() {
                        _focusedDay = focusedDay;
                      });
                    },
                    calendarFormat: CalendarFormat.month,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    headerVisible: false,
                    availableGestures: AvailableGestures.horizontalSwipe,
                    rowHeight: 42,
                    daysOfWeekHeight: 20,
                    daysOfWeekStyle: const DaysOfWeekStyle(
                      weekdayStyle:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      weekendStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.red),
                    ),

                    // Style des marqueurs d'événements (max 3 points)
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, events) {
                        if (events.isEmpty) return null;

                        final colorScheme = Theme.of(context).colorScheme;
                        final displayCount = events.length.clamp(0, 3);

                        return Positioned(
                          bottom: 2,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(displayCount, (index) {
                              return Container(
                                width: 5,
                                height: 5,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: index == 0
                                      ? colorScheme.primary
                                      : colorScheme.primary.withOpacity(0.5),
                                ),
                              );
                            }),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                // Liste des événements
                _buildEventsList(eventsAsync),
                const SizedBox(height: 80), // Espace pour le FAB
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEventDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
