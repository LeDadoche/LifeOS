import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'event_model.dart';

final agendaRepositoryProvider = Provider<AgendaRepository>((ref) {
  return AgendaRepository(Supabase.instance.client);
});

final eventsForDayProvider =
    StreamProvider.family<List<Event>, DateTime>((ref, day) {
  return ref.watch(agendaRepositoryProvider).watchEventsForDay(day);
});

/// Provider pour les événements d'un mois entier (pour les marqueurs du calendrier)
final eventsForMonthProvider =
    StreamProvider.family<Map<DateTime, List<Event>>, DateTime>((ref, month) {
  return ref.watch(agendaRepositoryProvider).watchEventsForMonth(month);
});

final upcomingEventsProvider = StreamProvider<List<Event>>((ref) {
  return ref.watch(agendaRepositoryProvider).watchUpcomingEvents();
});

class AgendaRepository {
  final SupabaseClient _client;

  AgendaRepository(this._client);

  /// Ajoute un événement et retourne son ID
  Future<int?> addEvent(Event event) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final data = event.toJson();
    data['user_id'] = user.id;
    data.remove('id');

    final response =
        await _client.from('events').insert(data).select('id').single();
    return response['id'] as int?;
  }

  /// Met à jour un événement existant
  Future<void> updateEvent(Event event) async {
    if (event.id == null) return;

    final user = _client.auth.currentUser;
    if (user == null) return;

    final data = event.toJson();
    data['user_id'] = user.id;

    await _client.from('events').update(data).eq('id', event.id!);
  }

  /// Récupère un événement par son ID
  Future<Event?> getEvent(int id) async {
    final response =
        await _client.from('events').select().eq('id', id).maybeSingle();

    if (response == null) return null;
    return Event.fromJson(response);
  }

  Stream<List<Event>> watchEventsForDay(DateTime day) {
    debugPrint('🔄 [Realtime] Initialisation stream EVENTS pour jour $day');
    final user = _client.auth.currentUser;
    if (user == null) {
      debugPrint('⚠️ [Agenda] watchEventsForDay: No user logged in');
      return Stream.value([]);
    }

    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _client
        .from('events')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('date')
        .map((data) {
          debugPrint('🔄 [Realtime] Nouvelle donnée reçue pour [events day] - ${data.length} éléments');
          final events = data.map((json) => Event.fromJson(json)).toList();
          // Filtrage local OBLIGATOIRE car .stream() ne supporte pas gte/lte
          return events
              .where((e) =>
                  e.date.isAfter(
                      startOfDay.subtract(const Duration(seconds: 1))) &&
                  e.date.isBefore(endOfDay))
              .toList();
        });
  }

  Stream<List<Event>> watchUpcomingEvents() {
    final user = _client.auth.currentUser;
    if (user == null) {
      debugPrint('⚠️ [Agenda] watchUpcomingEvents: No user logged in');
      return Stream.value([]);
    }

    final now = DateTime.now();
    debugPrint(
        '📅 [Agenda] watchUpcomingEvents: Starting stream for user ${user.id}');

    return _client
        .from('events')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('date')
        .map((data) {
          debugPrint('📅 [Agenda] Stream received ${data.length} total events');
          final events = data.map((json) => Event.fromJson(json)).toList();
          final filtered = events
              .where((e) => e.date.isAfter(now.subtract(
                  const Duration(minutes: 15)))) // Show current/upcoming
              .take(3)
              .toList();
          debugPrint(
              '📅 [Agenda] Filtered to ${filtered.length} upcoming events');
          return filtered;
        });
  }

  /// Récupère les événements d'un mois entier groupés par jour (pour les marqueurs)
  Stream<Map<DateTime, List<Event>>> watchEventsForMonth(DateTime month) {
    debugPrint('🔄 [Realtime] Initialisation stream EVENTS pour mois $month');
    final user = _client.auth.currentUser;
    if (user == null) {
      return Stream.value({});
    }

    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    return _client
        .from('events')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('date')
        .map((data) {
          debugPrint('🔄 [Realtime] Nouvelle donnée reçue pour [events month] - ${data.length} éléments');
          final events = data.map((json) => Event.fromJson(json)).toList();

          // Filtrer les événements du mois
          final monthEvents = events.where((e) =>
              e.date
                  .isAfter(startOfMonth.subtract(const Duration(seconds: 1))) &&
              e.date.isBefore(endOfMonth.add(const Duration(seconds: 1))));

          // Grouper par jour (normaliser la date sans l'heure)
          final Map<DateTime, List<Event>> grouped = {};
          for (final event in monthEvents) {
            final dayKey =
                DateTime(event.date.year, event.date.month, event.date.day);
            grouped.putIfAbsent(dayKey, () => []).add(event);
          }

          return grouped;
        });
  }

  Future<void> deleteEvent(int id) async {
    await _client.from('events').delete().eq('id', id);
  }
}
