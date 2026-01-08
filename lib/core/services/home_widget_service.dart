import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/agenda/data/event_model.dart';
import '../../features/tasks/data/task_model.dart';

/// App Group ID for iOS widget sharing (à configurer dans Xcode)
const String _appGroupId = 'group.com.lifeos.widget';

/// Android widget names
const String _tasksWidgetAndroid = 'TasksWidgetProvider';
const String _agendaWidgetAndroid = 'AgendaWidgetProvider';

/// iOS widget names
const String _tasksWidgetIOS = 'TasksWidget';
const String _agendaWidgetIOS = 'AgendaWidget';

/// Service pour gérer les widgets de l'écran d'accueil (Android/iOS)
///
/// Ce service utilise le package home_widget pour afficher des widgets
/// sur l'écran d'accueil du téléphone, permettant un accès rapide aux
/// informations clés de LifeOS (agenda, tâches, etc.)
class HomeWidgetService {
  static final HomeWidgetService _instance = HomeWidgetService._internal();
  factory HomeWidgetService() => _instance;
  HomeWidgetService._internal();

  bool _isInitialized = false;

  /// Vérifie si la plateforme supporte les widgets
  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  /// Initialise le service de widgets d'accueil
  Future<void> initialize() async {
    if (_isInitialized || !isSupported) return;

    try {
      debugPrint('🏠 [HomeWidget] Initialisation...');

      // Configure app group for iOS
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(_appGroupId);
      }

      // Note: Le callback est enregistré dans main.dart avec widgetBackgroundCallback

      _isInitialized = true;
      debugPrint('✅ [HomeWidget] Service initialisé');
    } catch (e) {
      debugPrint('❌ [HomeWidget] Erreur initialisation: $e');
    }
  }

  /// Met à jour le widget Tâches avec les tâches en cours
  Future<void> updateTasksWidget() async {
    if (!isSupported) return;

    try {
      debugPrint('📋 [HomeWidget] Mise à jour widget Tâches...');

      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null) {
        debugPrint('⚠️ [HomeWidget] Utilisateur non connecté');
        await _clearTasksData();
        return;
      }

      // Fetch pending tasks
      final response = await client
          .from('tasks')
          .select()
          .eq('user_id', user.id)
          .eq('is_completed', false)
          .order('is_starred', ascending: false)
          .order('due_date', ascending: true)
          .order('created_at')
          .limit(5);

      final tasks = (response as List).map((json) {
        final task = Task.fromJson(json as Map<String, dynamic>);
        return {
          'id': task.id,
          'title': task.title,
          'is_starred': task.isStarred,
          'has_reminder': task.hasReminder,
          'due_date': task.dueDate?.toIso8601String(),
        };
      }).toList();

      // Save to shared preferences
      await HomeWidget.saveWidgetData('tasks_data', jsonEncode(tasks));
      // Save timestamp for timeout detection
      await HomeWidget.saveWidgetData('tasks_last_update', DateTime.now().millisecondsSinceEpoch);
      debugPrint('📋 [HomeWidget] tasks_last_update saved: ${DateTime.now().millisecondsSinceEpoch}');

      // Update the widget
      if (Platform.isAndroid) {
        await HomeWidget.updateWidget(
          androidName: _tasksWidgetAndroid,
        );
      } else if (Platform.isIOS) {
        await HomeWidget.updateWidget(
          iOSName: _tasksWidgetIOS,
        );
      }

      debugPrint(
          '✅ [HomeWidget] Widget Tâches mis à jour (${tasks.length} tâches)');
    } catch (e) {
      debugPrint('❌ [HomeWidget] Erreur mise à jour Tâches: $e');
    }
  }

  /// Met à jour le widget Agenda avec les prochains événements
  Future<void> updateAgendaWidget() async {
    if (!isSupported) return;

    try {
      debugPrint('📅 [HomeWidget] Mise à jour widget Agenda...');

      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null) {
        debugPrint('⚠️ [HomeWidget] Utilisateur non connecté');
        await _clearAgendaData();
        return;
      }

      debugPrint('📅 [HomeWidget] User ID: ${user.id}');

      // Fetch upcoming events
      final now = DateTime.now().subtract(const Duration(minutes: 15));
      debugPrint(
          '📅 [HomeWidget] Fetching events after: ${now.toIso8601String()}');

      final response = await client
          .from('events')
          .select()
          .eq('user_id', user.id)
          .gte('date', now.toIso8601String())
          .order('date')
          .limit(3);

      debugPrint('📅 [HomeWidget] Raw response: $response');

      final events = (response as List).map((json) {
        final event = Event.fromJson(json as Map<String, dynamic>);
        debugPrint('📅 [HomeWidget] Event: ${event.title} at ${event.date}');
        return {
          'id': event.id,
          'title': event.title,
          'date': event.date.toIso8601String(),
          'is_all_day': event.isAllDay,
          'location': event.location,
        };
      }).toList();

      final jsonData = jsonEncode(events);
      debugPrint('📅 [HomeWidget] Saving events_data: $jsonData');

      // Save to shared preferences
      await HomeWidget.saveWidgetData('events_data', jsonData);
      // Save timestamp for timeout detection
      await HomeWidget.saveWidgetData('events_last_update', DateTime.now().millisecondsSinceEpoch);
      debugPrint('📅 [HomeWidget] events_last_update saved: ${DateTime.now().millisecondsSinceEpoch}');

      // Petit délai pour s'assurer que les SharedPreferences sont synchronisées
      await Future.delayed(const Duration(milliseconds: 100));

      // Update the widget
      if (Platform.isAndroid) {
        debugPrint('📅 [HomeWidget] Calling updateWidget for Android...');
        await HomeWidget.updateWidget(
          androidName: _agendaWidgetAndroid,
        );
        // Force un second update pour garantir le refresh de la ListView
        await Future.delayed(const Duration(milliseconds: 50));
        await HomeWidget.updateWidget(
          androidName: _agendaWidgetAndroid,
        );
      } else if (Platform.isIOS) {
        await HomeWidget.updateWidget(
          iOSName: _agendaWidgetIOS,
        );
      }

      debugPrint(
          '✅ [HomeWidget] Widget Agenda mis à jour (${events.length} événements)');
    } catch (e) {
      debugPrint('❌ [HomeWidget] Erreur mise à jour Agenda: $e');
    }
  }

  /// Rafraîchit tous les widgets de l'écran d'accueil
  Future<void> refreshAllWidgets() async {
    debugPrint('🔄 [HomeWidget] Rafraîchissement de tous les widgets...');
    await Future.wait([
      updateTasksWidget(),
      updateAgendaWidget(),
    ]);
  }

  /// Complete une tâche par son ID (appelé depuis le widget)
  Future<void> completeTask(int taskId) async {
    try {
      debugPrint('✅ [HomeWidget] Complétion tâche $taskId...');

      final client = Supabase.instance.client;
      await client.from('tasks').update({
        'is_completed': true,
      }).eq('id', taskId);

      // Refresh widget after completion
      await updateTasksWidget();

      debugPrint('✅ [HomeWidget] Tâche $taskId complétée');
    } catch (e) {
      debugPrint('❌ [HomeWidget] Erreur complétion tâche: $e');
    }
  }

  /// Efface les données du widget Tâches
  Future<void> _clearTasksData() async {
    await HomeWidget.saveWidgetData('tasks_data', '[]');
    if (Platform.isAndroid) {
      await HomeWidget.updateWidget(androidName: _tasksWidgetAndroid);
    } else if (Platform.isIOS) {
      await HomeWidget.updateWidget(iOSName: _tasksWidgetIOS);
    }
  }

  /// Efface les données du widget Agenda
  Future<void> _clearAgendaData() async {
    await HomeWidget.saveWidgetData('events_data', '[]');
    if (Platform.isAndroid) {
      await HomeWidget.updateWidget(androidName: _agendaWidgetAndroid);
    } else if (Platform.isIOS) {
      await HomeWidget.updateWidget(iOSName: _agendaWidgetIOS);
    }
  }

  /// Gère les interactions utilisateur depuis les widgets
  Future<void> handleWidgetAction(Uri? uri) async {
    if (uri == null) return;

    debugPrint('🔗 [HomeWidget] Action reçue: $uri');

    final host = uri.host;
    final path = uri.path;
    final queryParams = uri.queryParameters;

    switch (host) {
      case 'tasks':
        await _handleTasksAction(path, queryParams);
        break;
      case 'agenda':
        await _handleAgendaAction(path, queryParams);
        break;
      case 'settings':
        // Navigation vers les paramètres sera gérée par le router
        break;
    }
  }

  Future<void> _handleTasksAction(
      String path, Map<String, String> params) async {
    switch (path) {
      case '/complete':
        final taskId = int.tryParse(params['id'] ?? '');
        if (taskId != null) {
          await completeTask(taskId);
        }
        break;
      case '/refresh':
        await updateTasksWidget();
        break;
      case '/add':
        // Navigation vers l'ajout de tâche sera gérée par le router
        break;
    }
  }

  Future<void> _handleAgendaAction(
      String path, Map<String, String> params) async {
    switch (path) {
      case '/refresh':
        await updateAgendaWidget();
        break;
      case '/add':
      case '/event':
        // Navigation sera gérée par le router
        break;
    }
  }
}

/// Provider pour le service HomeWidget
final homeWidgetServiceProvider = Provider<HomeWidgetService>((ref) {
  return HomeWidgetService();
});
