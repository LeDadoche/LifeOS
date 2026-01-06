import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../features/agenda/data/event_model.dart';
import '../../features/tasks/data/task_model.dart';

/// Provider pour le service de notifications
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Canal de notification Android pour les événements
const AndroidNotificationChannel _agendaChannel = AndroidNotificationChannel(
  'agenda_reminders', // id
  'Rappels d\'événements', // title
  description: 'Notifications pour les rappels d\'événements de l\'agenda',
  importance: Importance.max, // IMPORTANT: max pour heads-up
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

/// Canal de notification Android pour les tâches
const AndroidNotificationChannel _tasksChannel = AndroidNotificationChannel(
  'task_reminders', // id
  'Rappels de tâches', // title
  description: 'Notifications pour les rappels de tâches',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

/// Service de gestion des notifications locales
/// Utilise zonedSchedule pour respecter les fuseaux horaires
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FlutterLocalNotificationsPlugin? _notifications;

  bool _isInitialized = false;

  /// Vérifie si la plateforme supporte les notifications natives
  bool get _isSupported =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isLinux;

  /// Initialise le service de notifications
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Windows n'est pas supporté par flutter_local_notifications
    if (!_isSupported) {
      debugPrint(
          '⚠️ NotificationService: Plateforme non supportée (${Platform.operatingSystem})');
      _isInitialized = true;
      return;
    }

    try {
      debugPrint('🔔 [NOTIF] Début initialisation...');

      // 1. Initialiser les timezones AVANT tout
      tz.initializeTimeZones();
      final localTz = _getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz));
      debugPrint('🔔 [NOTIF] Timezone configuré: $localTz');

      // 2. Créer le plugin
      _notifications = FlutterLocalNotificationsPlugin();

      // 3. Configuration Android avec canal explicite
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // 4. Créer les canaux Android EXPLICITEMENT
      if (Platform.isAndroid) {
        final androidPlugin = _notifications!
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidPlugin != null) {
          // Créer le canal agenda avec importance MAX
          await androidPlugin.createNotificationChannel(_agendaChannel);
          debugPrint('🔔 [NOTIF] Canal Agenda créé: ${_agendaChannel.id}');

          // Créer le canal tâches avec importance MAX
          await androidPlugin.createNotificationChannel(_tasksChannel);
          debugPrint('🔔 [NOTIF] Canal Tâches créé: ${_tasksChannel.id}');

          // Demander permission EXACT_ALARM pour Android 12+
          final exactAlarmGranted =
              await androidPlugin.requestExactAlarmsPermission();
          debugPrint('🔔 [NOTIF] Permission EXACT_ALARM: $exactAlarmGranted');
        }
      }

      // 5. Configuration iOS/macOS
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // 6. Configuration Linux
      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open',
      );

      // 7. Initialiser le plugin
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
      );

      final initialized = await _notifications!.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
        onDidReceiveBackgroundNotificationResponse:
            _onBackgroundNotificationTapped,
      );

      debugPrint('🔔 [NOTIF] Plugin initialisé: $initialized');

      _isInitialized = true;
      debugPrint('✅ [NOTIF] NotificationService prêt !');
    } catch (e, stack) {
      debugPrint('❌ [NOTIF] Erreur initialisation: $e');
      debugPrint('❌ [NOTIF] Stack: $stack');
      _isInitialized = true; // Marquer comme initialisé pour éviter les retry
    }
  }

  /// Retourne le timezone local
  String _getLocalTimezone() {
    return 'Europe/Paris';
  }

  /// Callback quand une notification est tappée (foreground)
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 [NOTIF] Notification tappée: ${response.payload}');
  }

  /// Callback quand une notification est tappée (background)
  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
    debugPrint(
        '🔔 [NOTIF] Background notification tappée: ${response.payload}');
  }

  /// Demande les permissions de notifications (iOS/Android 13+)
  Future<bool> requestPermissions() async {
    if (!_isSupported || _notifications == null) {
      debugPrint('⚠️ [NOTIF] Permissions ignorées - non supporté');
      return true;
    }

    try {
      if (Platform.isAndroid) {
        final androidPlugin = _notifications!
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidPlugin != null) {
          // Demander permission POST_NOTIFICATIONS pour Android 13+
          final notifGranted =
              await androidPlugin.requestNotificationsPermission();
          debugPrint('🔔 [NOTIF] Permission POST_NOTIFICATIONS: $notifGranted');

          return notifGranted ?? false;
        }
      } else if (Platform.isIOS || Platform.isMacOS) {
        final darwinPlugin = _notifications!
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        final granted = await darwinPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('🔔 [NOTIF] Permission iOS: $granted');
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('❌ [NOTIF] Erreur demande permissions: $e');
    }
    return true;
  }

  /// Programme une notification pour un événement
  /// Utilise zonedSchedule pour respecter les fuseaux horaires
  Future<void> scheduleEventReminder(Event event) async {
    debugPrint(
        '--- [NOTIF] scheduleEventReminder appelé pour: ${event.title} ---');

    if (!_isSupported || _notifications == null) {
      debugPrint(
          '⚠️ [NOTIF] Notifications non supportées sur cette plateforme');
      return;
    }

    if (!event.shouldScheduleNotification) {
      debugPrint(
          '⏭️ [NOTIF] Pas de notification à programmer (shouldSchedule=false)');
      return;
    }

    final notificationTime = event.notificationTime!;
    final now = DateTime.now();

    debugPrint('🔔 [NOTIF] Heure actuelle: $now');
    debugPrint('🔔 [NOTIF] Heure notification prévue: $notificationTime');

    // Vérifier que la date est dans le futur
    if (notificationTime.isBefore(now)) {
      debugPrint('⚠️ [NOTIF] Date dans le passé ! Notification ignorée.');
      return;
    }

    final tzNotificationTime = tz.TZDateTime.from(notificationTime, tz.local);
    debugPrint('🔔 [NOTIF] TZDateTime: $tzNotificationTime');

    // Générer un ID unique basé sur l'ID de l'événement
    final notificationId = _generateNotificationId(event.id!);

    // Construire le corps de la notification
    final reminderText = event.reminderOption.label;
    final timeText = _formatTime(event.date);
    final body = event.location != null && event.location!.isNotEmpty
        ? '$reminderText • $timeText\n📍 ${event.location}'
        : '$reminderText • $timeText';

    // Détails de la notification Android - UTILISER LE CANAL
    const androidDetails = AndroidNotificationDetails(
      'agenda_reminders', // DOIT correspondre au channel ID
      'Rappels d\'événements',
      channelDescription:
          'Notifications pour les rappels d\'événements de l\'agenda',
      importance: Importance.max, // MAX pour heads-up
      priority: Priority.max, // MAX pour heads-up
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      fullScreenIntent: true, // Pour réveiller l'écran
    );

    // Détails iOS
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      debugPrint(
          '--- SCHEDULING NOTIFICATION ID: $notificationId AT $tzNotificationTime ---');

      await _notifications!.zonedSchedule(
        notificationId,
        '📅 ${event.title}',
        body,
        tzNotificationTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'event_${event.id}',
      );

      debugPrint('✅ [NOTIF] Notification programmée avec succès !');
      debugPrint('   - ID: $notificationId');
      debugPrint('   - Titre: ${event.title}');
      debugPrint('   - Heure: $tzNotificationTime');

      // Vérifier que la notification est bien programmée
      final pending = await _notifications!.pendingNotificationRequests();
      debugPrint('🔔 [NOTIF] Notifications en attente: ${pending.length}');
      for (final p in pending) {
        debugPrint('   - ID: ${p.id}, Titre: ${p.title}');
      }
    } catch (e, stack) {
      debugPrint('❌ [NOTIF] Erreur programmation notification: $e');
      debugPrint('❌ [NOTIF] Stack: $stack');
    }
  }

  /// Annule la notification d'un événement
  Future<void> cancelEventReminder(int eventId) async {
    if (!_isSupported || _notifications == null) {
      debugPrint('⚠️ [NOTIF] Annulation ignorée - non supporté');
      return;
    }

    try {
      final notificationId = _generateNotificationId(eventId);
      await _notifications!.cancel(notificationId);
      debugPrint(
          '🗑️ [NOTIF] Notification annulée: event=$eventId, notifId=$notificationId');
    } catch (e) {
      debugPrint('❌ [NOTIF] Erreur annulation notification: $e');
    }
  }

  /// Met à jour la notification d'un événement
  Future<void> updateEventReminder(Event event) async {
    if (event.id == null) return;

    await cancelEventReminder(event.id!);
    await scheduleEventReminder(event);
  }

  /// Génère un ID de notification unique à partir de l'ID de l'événement
  int _generateNotificationId(int eventId) {
    return eventId.hashCode.abs() % 2147483647;
  }

  /// Formate l'heure pour l'affichage
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Affiche une notification immédiate (pour les tests)
  Future<void> showTestNotification() async {
    if (!_isSupported || _notifications == null) {
      debugPrint('⚠️ [NOTIF] Test ignoré - non supporté');
      return;
    }

    debugPrint('🔔 [NOTIF] Envoi notification de test...');

    const androidDetails = AndroidNotificationDetails(
      'agenda_reminders',
      'Rappels d\'événements',
      channelDescription: 'Test',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _notifications!.show(
        999,
        '🔔 Test Notification',
        'Le système de notifications fonctionne !',
        details,
      );
      debugPrint('✅ [NOTIF] Notification de test envoyée !');
    } catch (e) {
      debugPrint('❌ [NOTIF] Erreur test notification: $e');
    }
  }

  // ============== TASK REMINDERS ==============

  /// Programme une notification pour une tâche
  Future<void> scheduleTaskReminder(Task task) async {
    debugPrint(
        '--- [NOTIF] scheduleTaskReminder appelé pour: ${task.title} ---');

    if (!_isSupported || _notifications == null) {
      debugPrint(
          '⚠️ [NOTIF] Notifications non supportées sur cette plateforme');
      return;
    }

    if (!task.shouldScheduleNotification) {
      debugPrint(
          '⏭️ [NOTIF] Pas de notification à programmer (shouldSchedule=false)');
      return;
    }

    final notificationTime = task.notificationTime!;
    final now = DateTime.now();

    debugPrint('📋 [NOTIF] Heure actuelle: $now');
    debugPrint('📋 [NOTIF] Heure notification prévue: $notificationTime');

    if (notificationTime.isBefore(now)) {
      debugPrint('⚠️ [NOTIF] Date dans le passé ! Notification ignorée.');
      return;
    }

    final tzNotificationTime = tz.TZDateTime.from(notificationTime, tz.local);
    final notificationId = _generateTaskNotificationId(task.id!);

    final reminderText = task.reminderOption.label;
    final dueDateText = _formatDate(task.dueDate!);
    final body = '$reminderText\n📅 Échéance: $dueDateText';

    const androidDetails = AndroidNotificationDetails(
      'task_reminders',
      'Rappels de tâches',
      channelDescription: 'Notifications pour les rappels de tâches',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      enableVibration: true,
      playSound: true,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _notifications!.zonedSchedule(
        notificationId,
        '✅ ${task.title}',
        body,
        tzNotificationTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'task_${task.id}',
      );

      debugPrint('✅ [NOTIF] Notification tâche programmée !');
      debugPrint('   - ID: $notificationId');
      debugPrint('   - Titre: ${task.title}');
      debugPrint('   - Heure: $tzNotificationTime');
    } catch (e, stack) {
      debugPrint('❌ [NOTIF] Erreur programmation notification tâche: $e');
      debugPrint('❌ [NOTIF] Stack: $stack');
    }
  }

  /// Annule la notification d'une tâche
  Future<void> cancelTaskReminder(int taskId) async {
    if (!_isSupported || _notifications == null) return;

    try {
      final notificationId = _generateTaskNotificationId(taskId);
      await _notifications!.cancel(notificationId);
      debugPrint('🗑️ [NOTIF] Notification tâche annulée: task=$taskId');
    } catch (e) {
      debugPrint('❌ [NOTIF] Erreur annulation notification tâche: $e');
    }
  }

  /// Met à jour la notification d'une tâche
  Future<void> updateTaskReminder(Task task) async {
    if (task.id == null) return;

    await cancelTaskReminder(task.id!);
    await scheduleTaskReminder(task);
  }

  /// Génère un ID de notification unique pour les tâches
  /// Utilise un offset pour éviter les collisions avec les événements
  int _generateTaskNotificationId(int taskId) {
    return (taskId.hashCode.abs() + 1000000000) % 2147483647;
  }

  /// Formate une date pour l'affichage
  String _formatDate(DateTime dateTime) {
    final weekdays = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
    final months = [
      'jan.',
      'fév.',
      'mar.',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sep.',
      'oct.',
      'nov.',
      'déc.'
    ];

    final weekday = weekdays[dateTime.weekday - 1];
    final day = dateTime.day;
    final month = months[dateTime.month - 1];
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$weekday $day $month à $hour:$minute';
  }

  // ============== END TASK REMINDERS ==============

  /// Annule toutes les notifications
  Future<void> cancelAll() async {
    if (!_isSupported || _notifications == null) return;

    try {
      await _notifications!.cancelAll();
      debugPrint('🗑️ [NOTIF] Toutes les notifications annulées');
    } catch (e) {
      debugPrint('❌ [NOTIF] Erreur annulation: $e');
    }
  }

  /// Liste les notifications programmées (debug)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_isSupported || _notifications == null) return [];

    try {
      final pending = await _notifications!.pendingNotificationRequests();
      debugPrint('🔔 [NOTIF] ${pending.length} notifications en attente');
      return pending;
    } catch (e) {
      debugPrint('❌ [NOTIF] Erreur récupération: $e');
      return [];
    }
  }
}
