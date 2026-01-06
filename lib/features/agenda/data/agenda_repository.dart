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
          final events = data.map((json) => Event.fromJson(json)).toList();
          // Filter locally because Supabase stream doesn't support complex filtering on the stream itself easily for ranges in all SDK versions,
          // but actually .stream() supports simple eq. For ranges, it's better to use .from().select() for one-time fetch or accept getting all events and filtering.
          // However, Supabase Realtime broadcasts ALL changes to the table by default (or filtered by row).
          // The .stream() method in Flutter SDK does allow some filtering but 'gte' and 'lt' might not be supported in the stream query builder in all versions.
          // Let's check the documentation or common patterns.
          // Actually, .stream() gets the whole table or a subset based on 'eq'. It doesn't support 'gte'/'lte'.
          // So we must filter locally in the map.
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
    debugPrint('📅 [Agenda] watchUpcomingEvents: Starting stream for user ${user.id}');
    
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
          debugPrint('📅 [Agenda] Filtered to ${filtered.length} upcoming events');
          return filtered;
        });
  }

  Future<void> deleteEvent(int id) async {
    await _client.from('events').delete().eq('id', id);
  }
}
