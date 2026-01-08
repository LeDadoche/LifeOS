import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'task_model.dart';

// 1. Le Provider pour les ACTIONS (Ajouter, Supprimer)
final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepository();
});

// 2. Le Provider pour l'AFFICHAGE (La liste des tâches)
// L'interface écoute celui-ci pour dessiner la liste
final tasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(tasksRepositoryProvider).watchAllTasks();
});

// 3. Provider pour les tâches non complétées (pour widget)
final pendingTasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(tasksRepositoryProvider).watchPendingTasks();
});

class TasksRepository {
  final _client = Supabase.instance.client;

  String? get _currentUserId => _client.auth.currentUser?.id;

  // Lecture de toutes les tâches
  Stream<List<Task>> watchAllTasks() {
    final userId = _currentUserId;
    if (userId == null) {
      debugPrint('⚠️ [Realtime] watchAllTasks: No user logged in');
      return Stream.value([]);
    }
    debugPrint('🔄 [Realtime] Initialisation stream TASKS (all) pour user $userId');
    return _client
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at')
        .map((data) {
          debugPrint('🔄 [Realtime] Nouvelle donnée reçue pour [tasks] - ${data.length} éléments');
          return data.map((json) => Task.fromJson(json)).toList();
        });
  }

  // Lecture des tâches non complétées (pour widget)
  Stream<List<Task>> watchPendingTasks() {
    final userId = _currentUserId;
    if (userId == null) {
      debugPrint('⚠️ [Realtime] watchPendingTasks: No user logged in');
      return Stream.value([]);
    }
    debugPrint('🔄 [Realtime] Initialisation stream TASKS (pending) pour user $userId');
    return _client
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('due_date', ascending: true)
        .order('is_starred', ascending: false)
        .order('created_at')
        .map((data) {
          debugPrint('🔄 [Realtime] Nouvelle donnée reçue pour [tasks pending] - ${data.length} éléments');
          final tasks = data.map((json) => Task.fromJson(json)).toList();
          // Filtrer les tâches non complétées et trier
          return tasks.where((t) => !t.isCompleted).toList()
            ..sort((a, b) {
              // Starred first
              if (a.isStarred != b.isStarred) {
                return a.isStarred ? -1 : 1;
              }
              // Then by due date (null dates at the end)
              if (a.dueDate != null && b.dueDate != null) {
                return a.dueDate!.compareTo(b.dueDate!);
              }
              if (a.dueDate != null) return -1;
              if (b.dueDate != null) return 1;
              return 0;
            });
        });
  }

  // Récupérer les tâches non complétées (one-shot pour widget)
  Future<List<Task>> getPendingTasks({int limit = 5}) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final response = await _client
          .from('tasks')
          .select()
          .eq('user_id', user.id)
          .eq('is_completed', false)
          .order('is_starred', ascending: false)
          .order('due_date', ascending: true)
          .order('created_at')
          .limit(limit);

      return (response as List)
          .map((json) => Task.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ [TasksRepository] Erreur getPendingTasks: $e');
      return [];
    }
  }

  // Ajouter une tâche avec tous les champs
  Future<int?> addTask(
    String title, {
    DateTime? dueDate,
    bool isStarred = false,
    int? reminderMinutes,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final data = {
      'title': title,
      'user_id': user.id,
      'is_completed': false,
      'is_starred': isStarred,
      if (dueDate != null) 'due_date': dueDate.toIso8601String(),
      if (reminderMinutes != null) 'reminder_minutes': reminderMinutes,
    };

    try {
      final response =
          await _client.from('tasks').insert(data).select('id').single();
      return response['id'] as int?;
    } catch (e) {
      debugPrint('❌ [TasksRepository] Erreur addTask: $e');
      return null;
    }
  }

  // Modifier le statut complété
  Future<void> toggleTask(Task task) async {
    if (task.id == null) return;

    await _client.from('tasks').update({
      'is_completed': !task.isCompleted,
    }).eq('id', task.id!);
  }

  // Compléter une tâche par ID (pour widget)
  Future<void> completeTaskById(int taskId) async {
    try {
      await _client.from('tasks').update({
        'is_completed': true,
      }).eq('id', taskId);
      debugPrint('✅ [TasksRepository] Tâche $taskId complétée');
    } catch (e) {
      debugPrint('❌ [TasksRepository] Erreur completeTaskById: $e');
    }
  }

  // Modifier le statut étoile
  Future<void> toggleStar(Task task) async {
    if (task.id == null) return;

    await _client.from('tasks').update({
      'is_starred': !task.isStarred,
    }).eq('id', task.id!);
  }

  // Mettre à jour une tâche
  Future<void> updateTask(Task task) async {
    if (task.id == null) return;

    await _client.from('tasks').update(task.toJson()).eq('id', task.id!);
  }

  // Supprimer
  Future<void> deleteTask(int id) async {
    await _client.from('tasks').delete().eq('id', id);
  }

  // Récupérer une tâche par ID
  Future<Task?> getTask(int id) async {
    try {
      final response =
          await _client.from('tasks').select().eq('id', id).maybeSingle();

      if (response == null) return null;
      return Task.fromJson(response);
    } catch (e) {
      debugPrint('❌ [TasksRepository] Erreur getTask: $e');
      return null;
    }
  }
}
