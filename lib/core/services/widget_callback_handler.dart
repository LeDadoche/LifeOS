import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/supabase_auth.dart';

/// Background entry point for widget callbacks.
/// This is called when user interacts with the widget while the app is not running.
@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  debugPrint('🔙 =============================================');
  debugPrint('🔙 [WidgetCallback] CALLBACK TRIGGERED!');
  debugPrint('🔙 =============================================');
  
  if (uri == null) {
    debugPrint('🔙 [WidgetCallback] URI is null, aborting');
    return;
  }

  debugPrint('🔙 [WidgetCallback] Full URI: $uri');
  debugPrint('🔙 [WidgetCallback] Scheme: ${uri.scheme}');
  debugPrint('🔙 [WidgetCallback] Host: ${uri.host}');
  debugPrint('🔙 [WidgetCallback] Path: ${uri.path}');
  debugPrint('🔙 [WidgetCallback] Query: ${uri.queryParameters}');

  try {
    // Initialize Supabase in background
    debugPrint('🔙 [WidgetCallback] Initializing Supabase...');
    await _initializeSupabaseBackground();
    debugPrint('🔙 [WidgetCallback] Supabase initialized');

    final host = uri.host;
    final path = uri.path;
    final queryParams = uri.queryParameters;

    debugPrint('🔙 [WidgetCallback] Processing - Host: $host, Path: $path');

    switch (host) {
      case 'tasks':
        debugPrint('🔙 [WidgetCallback] Routing to tasks handler...');
        await _handleTasksCallback(path, queryParams);
        break;
      case 'agenda':
        debugPrint('🔙 [WidgetCallback] Routing to agenda handler...');
        await _handleAgendaCallback(path, queryParams);
        break;
      default:
        debugPrint('🔙 [WidgetCallback] Unknown host: $host');
    }
    
    debugPrint('🔙 [WidgetCallback] Callback completed successfully');
  } catch (e, stack) {
    debugPrint('❌ [WidgetCallback] Error: $e');
    debugPrint('❌ [WidgetCallback] Stack: $stack');
  }
}

/// Initialize Supabase for background operations
Future<void> _initializeSupabaseBackground() async {
  try {
    // Check if already initialized
    final client = Supabase.instance.client;
    debugPrint('🔙 [WidgetCallback] Supabase already initialized');
    debugPrint('🔙 [WidgetCallback] Current user: ${client.auth.currentUser?.id ?? "NULL"}');
  } catch (e) {
    // Not initialized, initialize now
    debugPrint('🔙 [WidgetCallback] Initializing Supabase from scratch...');
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
    final client = Supabase.instance.client;
    debugPrint('🔙 [WidgetCallback] After init - Current user: ${client.auth.currentUser?.id ?? "NULL"}');
  }
}

/// Handle tasks widget callbacks
Future<void> _handleTasksCallback(String path, Map<String, String> params) async {
  debugPrint('📋 [WidgetCallback] _handleTasksCallback called');
  debugPrint('📋 [WidgetCallback] Path: "$path"');
  debugPrint('📋 [WidgetCallback] Params: $params');
  
  final taskId = int.tryParse(params['id'] ?? '');
  debugPrint('📋 [WidgetCallback] Parsed taskId: $taskId');
  
  switch (path) {
    case '/complete':
      debugPrint('📋 [WidgetCallback] ACTION: Complete task');
      if (taskId != null) {
        await _completeTask(taskId);
        await _updateTasksWidget();
      } else {
        debugPrint('❌ [WidgetCallback] Missing task ID for complete');
      }
      break;
    case '/star':
      debugPrint('📋 [WidgetCallback] ACTION: Toggle star');
      if (taskId != null) {
        await _toggleTaskStar(taskId);
        await _updateTasksWidget();
      } else {
        debugPrint('❌ [WidgetCallback] Missing task ID for star');
      }
      break;
    case '/refresh':
      debugPrint('📋 [WidgetCallback] ACTION: Refresh widget');
      await _updateTasksWidget();
      break;
    default:
      debugPrint('❌ [WidgetCallback] Unknown path: $path');
  }
}

/// Handle agenda widget callbacks
Future<void> _handleAgendaCallback(String path, Map<String, String> params) async {
  debugPrint('📅 [WidgetCallback] Agenda callback: path=$path');
  switch (path) {
    case '/refresh':
      debugPrint('📅 [WidgetCallback] Starting agenda refresh...');
      await _updateAgendaWidget();
      debugPrint('📅 [WidgetCallback] Agenda refresh completed');
      break;
    default:
      debugPrint('📅 [WidgetCallback] Unknown agenda path: $path');
  }
}

/// Complete a task in Supabase
Future<void> _completeTask(int taskId) async {
  try {
    final client = Supabase.instance.client;
    await client.from('tasks').update({
      'is_completed': true,
    }).eq('id', taskId);
    debugPrint('✅ [WidgetCallback] Task $taskId completed');
  } catch (e) {
    debugPrint('❌ [WidgetCallback] Error completing task: $e');
  }
}

/// Toggle star status of a task in Supabase
Future<void> _toggleTaskStar(int taskId) async {
  try {
    final client = Supabase.instance.client;
    
    // Get current star status
    final response = await client
        .from('tasks')
        .select('is_starred')
        .eq('id', taskId)
        .single();
    
    final currentStatus = response['is_starred'] as bool? ?? false;
    
    // Toggle it
    await client.from('tasks').update({
      'is_starred': !currentStatus,
    }).eq('id', taskId);
    
    debugPrint('✅ [WidgetCallback] Task $taskId star toggled to ${!currentStatus}');
  } catch (e) {
    debugPrint('❌ [WidgetCallback] Error toggling task star: $e');
  }
}

/// Update tasks widget data
Future<void> _updateTasksWidget() async {
  try {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      await HomeWidget.saveWidgetData('tasks_data', '[]');
      return;
    }

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
      return {
        'id': json['id'],
        'title': json['title'],
        'is_starred': json['is_starred'] ?? false,
        'has_reminder': json['reminder_minutes'] != null,
        'due_date': json['due_date'],
      };
    }).toList();

    await HomeWidget.saveWidgetData('tasks_data', jsonEncode(tasks));
    await HomeWidget.updateWidget(androidName: 'TasksWidgetProvider');

    debugPrint('✅ [WidgetCallback] Tasks widget updated');
  } catch (e) {
    debugPrint('❌ [WidgetCallback] Error updating tasks widget: $e');
  }
}

/// Update agenda widget data
Future<void> _updateAgendaWidget() async {
  try {
    debugPrint('📅 [WidgetCallback] _updateAgendaWidget starting...');
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      debugPrint('⚠️ [WidgetCallback] No user logged in for agenda');
      await HomeWidget.saveWidgetData('events_data', '[]');
      return;
    }

    debugPrint('📅 [WidgetCallback] User: ${user.id}');
    
    final now = DateTime.now().subtract(const Duration(minutes: 15));
    debugPrint('📅 [WidgetCallback] Fetching events after: $now');
    
    final response = await client
        .from('events')
        .select()
        .eq('user_id', user.id)
        .gte('date', now.toIso8601String())
        .order('date')
        .limit(3);

    debugPrint('📅 [WidgetCallback] Got ${(response as List).length} events');

    final events = (response).map((json) {
      debugPrint('📅 [WidgetCallback] Event: ${json['title']} - ${json['date']}');
      return {
        'id': json['id'],
        'title': json['title'],
        'date': json['date'],
        'is_all_day': json['is_all_day'] ?? false,
        'location': json['location'],
      };
    }).toList();

    final jsonData = jsonEncode(events);
    debugPrint('📅 [WidgetCallback] Saving: $jsonData');
    
    await HomeWidget.saveWidgetData('events_data', jsonData);
    await HomeWidget.updateWidget(androidName: 'AgendaWidgetProvider');

    debugPrint('✅ [WidgetCallback] Agenda widget updated');
  } catch (e, stack) {
    debugPrint('❌ [WidgetCallback] Error updating agenda widget: $e');
    debugPrint('❌ [WidgetCallback] Stack: $stack');
  }
}
