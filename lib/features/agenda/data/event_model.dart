import 'package:flutter/material.dart';

/// Options de rappel disponibles (en minutes avant l'événement)
enum ReminderOption {
  none(null, 'Aucun', Icons.notifications_off_outlined),
  atTime(0, 'À l\'heure dite', Icons.alarm),
  fiveMinutes(5, '5 min avant', Icons.timer),
  fifteenMinutes(15, '15 min avant', Icons.timer),
  thirtyMinutes(30, '30 min avant', Icons.timer),
  oneHour(60, '1h avant', Icons.schedule);

  final int? minutes;
  final String label;
  final IconData icon;

  const ReminderOption(this.minutes, this.label, this.icon);

  static ReminderOption fromMinutes(int? minutes) {
    return ReminderOption.values.firstWhere(
      (option) => option.minutes == minutes,
      orElse: () => ReminderOption.none,
    );
  }
}

class Event {
  final int? id;
  final String title;
  final String? description;
  final DateTime date;
  final DateTime? endTime; // Heure de fin optionnelle
  final bool isAllDay;
  final String? location;
  final String userId;
  final int?
      reminderMinutes; // null = pas de rappel, 0 = à l'heure, 5/15/30/60 = avant

  Event({
    this.id,
    required this.title,
    this.description,
    required this.date,
    this.endTime,
    this.isAllDay = false,
    this.location,
    required this.userId,
    this.reminderMinutes,
  });

  /// Copie avec modifications
  Event copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? date,
    DateTime? Function()? endTime,
    bool? isAllDay,
    String? location,
    String? userId,
    int? Function()? reminderMinutes,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      endTime: endTime != null ? endTime() : this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      location: location ?? this.location,
      userId: userId ?? this.userId,
      reminderMinutes:
          reminderMinutes != null ? reminderMinutes() : this.reminderMinutes,
    );
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as int?,
      title: json['title'] as String,
      description: json['description'] as String?,
      date: DateTime.parse(json['date'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      isAllDay: json['is_all_day'] as bool? ?? false,
      location: json['location'] as String?,
      userId: json['user_id'] as String,
      // Compatibilité : lit reminder_minutes seulement si présent
      reminderMinutes: json.containsKey('reminder_minutes')
          ? json['reminder_minutes'] as int?
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      if (endTime != null) 'end_time': endTime!.toIso8601String(),
      'is_all_day': isAllDay,
      'location': location,
      'user_id': userId,
      // Compatibilité : n'inclut pas reminder_minutes pour éviter erreur Supabase
      // Décommente la ligne suivante après avoir ajouté la colonne dans Supabase:
      'reminder_minutes': reminderMinutes,
    };
  }

  /// Retourne l'option de rappel correspondante
  ReminderOption get reminderOption =>
      ReminderOption.fromMinutes(reminderMinutes);

  /// Formate la plage horaire (ex: "14:00 - 15:00")
  String get timeRangeFormatted {
    final startFormatted =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (endTime == null) {
      return startFormatted;
    }
    final endFormatted =
        '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}';
    return '$startFormatted - $endFormatted';
  }

  /// Calcule l'heure de notification
  DateTime? get notificationTime {
    if (reminderMinutes == null) return null;
    return date.subtract(Duration(minutes: reminderMinutes!));
  }

  /// Vérifie si la notification doit être programmée (dans le futur)
  bool get shouldScheduleNotification {
    if (reminderMinutes == null) return false;
    final notifTime = notificationTime;
    return notifTime != null && notifTime.isAfter(DateTime.now());
  }
}
