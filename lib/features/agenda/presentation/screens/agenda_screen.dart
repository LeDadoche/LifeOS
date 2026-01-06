import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

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
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

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

                    // Sélecteur d'heure
                    Semantics(
                      label: 'Sélectionner l\'heure de l\'événement',
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
                                      'Heure',
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
                                          Text('Veuillez entrer un titre')),
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

                              final userId = Supabase
                                      .instance.client.auth.currentUser?.id ??
                                  '';

                              final event = Event(
                                id: existingEvent?.id,
                                title: titleController.text,
                                date: eventDate,
                                isAllDay: false,
                                userId: userId,
                                reminderMinutes: selectedReminder.minutes,
                              );

                              final notificationService =
                                  ref.read(notificationServiceProvider);

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
                                  final eventWithId = event.copyWith(id: newId);
                                  await notificationService
                                      .scheduleEventReminder(eventWithId);
                                }
                              }

                              if (context.mounted) Navigator.of(context).pop();
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

            return Semantics(
              label:
                  '${event.title} à ${DateFormat('HH:mm').format(event.date)}${hasReminder ? ', rappel programmé' : ''}',
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
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    DateFormat('HH:mm').format(event.date),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                      fontSize: 12,
                    ),
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
      appBar: AppBar(
        title: const Text('Mon Agenda'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
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
          final calendarHeight = (availableHeight * 0.35).clamp(200.0, 300.0);

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
                    calendarFormat: CalendarFormat.month,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    headerVisible: false,
                    availableGestures: AvailableGestures.none,
                    rowHeight: 32,
                    daysOfWeekHeight: 16,
                    daysOfWeekStyle: const DaysOfWeekStyle(
                      weekdayStyle:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      weekendStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
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
