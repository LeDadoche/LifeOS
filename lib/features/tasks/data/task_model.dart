import 'package:flutter/material.dart';

/// Options de rappel disponibles (en minutes avant l'échéance)
enum TaskReminderOption {
  none(null, 'Aucun', Icons.notifications_off_outlined),
  atTime(0, 'À l\'heure dite', Icons.alarm),
  fiveMinutes(5, '5 min avant', Icons.timer),
  fifteenMinutes(15, '15 min avant', Icons.timer),
  thirtyMinutes(30, '30 min avant', Icons.timer),
  oneHour(60, '1h avant', Icons.schedule),
  oneDay(1440, '1 jour avant', Icons.calendar_today);

  final int? minutes;
  final String label;
  final IconData icon;

  const TaskReminderOption(this.minutes, this.label, this.icon);

  static TaskReminderOption fromMinutes(int? minutes) {
    return TaskReminderOption.values.firstWhere(
      (option) => option.minutes == minutes,
      orElse: () => TaskReminderOption.none,
    );
  }
}

class Task {
  final int? id;
  final String title;
  final bool isCompleted;
  final String userId;
  final DateTime? createdAt;
  final DateTime? dueDate;
  final bool isStarred;
  final int? reminderMinutes; // null = pas de rappel

  Task({
    this.id,
    required this.title,
    required this.isCompleted,
    required this.userId,
    this.createdAt,
    this.dueDate,
    this.isStarred = false,
    this.reminderMinutes,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as int?,
      title: json['title'] as String,
      isCompleted: json['is_completed'] as bool? ?? false,
      userId: json['user_id'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      isStarred: json['is_starred'] as bool? ?? false,
      reminderMinutes: json['reminder_minutes'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'is_completed': isCompleted,
      'user_id': userId,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (dueDate != null) 'due_date': dueDate!.toIso8601String(),
      'is_starred': isStarred,
      'reminder_minutes': reminderMinutes,
    };
  }

  Task copyWith({
    int? id,
    String? title,
    bool? isCompleted,
    String? userId,
    DateTime? createdAt,
    DateTime? Function()? dueDate,
    bool? isStarred,
    int? Function()? reminderMinutes,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate != null ? dueDate() : this.dueDate,
      isStarred: isStarred ?? this.isStarred,
      reminderMinutes:
          reminderMinutes != null ? reminderMinutes() : this.reminderMinutes,
    );
  }

  /// Retourne l'option de rappel correspondante
  TaskReminderOption get reminderOption =>
      TaskReminderOption.fromMinutes(reminderMinutes);

  /// Calcule l'heure de notification (basée sur dueDate si elle existe)
  DateTime? get notificationTime {
    if (reminderMinutes == null || dueDate == null) return null;
    return dueDate!.subtract(Duration(minutes: reminderMinutes!));
  }

  /// Vérifie si la notification doit être programmée (dans le futur)
  bool get shouldScheduleNotification {
    if (reminderMinutes == null || dueDate == null) return false;
    final notifTime = notificationTime;
    return notifTime != null && notifTime.isAfter(DateTime.now());
  }

  /// Vérifie si la tâche est en retard
  bool get isOverdue {
    if (dueDate == null || isCompleted) return false;
    return dueDate!.isBefore(DateTime.now());
  }

  /// Vérifie si la tâche a un rappel configuré
  bool get hasReminder => reminderMinutes != null;
}
