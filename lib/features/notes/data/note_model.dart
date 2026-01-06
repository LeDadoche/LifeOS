import 'package:flutter/material.dart';

/// Couleurs pastels disponibles pour les notes
enum NoteColor {
  none,    // Pas de couleur (défaut)
  yellow,  // Jaune pastel
  blue,    // Bleu pastel
  green,   // Vert pastel
  pink,    // Rose pastel
  purple,  // Violet pastel
  grey,    // Gris pastel
}

/// Thèmes visuels avec images de fond
enum NoteTheme {
  none,      // Pas de thème
  mountain,  // Montagne
  sakura,    // Sakura (cerisiers)
  beach,     // Plage
  autumn,    // Automne
}

extension NoteColorExtension on NoteColor {
  Color get color {
    switch (this) {
      case NoteColor.none:
        return Colors.transparent;
      case NoteColor.yellow:
        return const Color(0xFFFFF9C4); // Yellow 100
      case NoteColor.blue:
        return const Color(0xFFBBDEFB); // Blue 100
      case NoteColor.green:
        return const Color(0xFFC8E6C9); // Green 100
      case NoteColor.pink:
        return const Color(0xFFF8BBD0); // Pink 100
      case NoteColor.purple:
        return const Color(0xFFE1BEE7); // Purple 100
      case NoteColor.grey:
        return const Color(0xFFECEFF1); // Blue Grey 50
    }
  }

  Color get darkColor {
    switch (this) {
      case NoteColor.none:
        return Colors.transparent;
      case NoteColor.yellow:
        return const Color(0xFF3E2723); // Brown dark
      case NoteColor.blue:
        return const Color(0xFF0D47A1); // Blue dark
      case NoteColor.green:
        return const Color(0xFF1B5E20); // Green dark
      case NoteColor.pink:
        return const Color(0xFF880E4F); // Pink dark
      case NoteColor.purple:
        return const Color(0xFF4A148C); // Purple dark
      case NoteColor.grey:
        return const Color(0xFF37474F); // Blue Grey dark
    }
  }

  /// Détermine si le texte doit être clair ou sombre sur cette couleur
  bool get needsDarkText => this != NoteColor.none;
}

extension NoteThemeExtension on NoteTheme {
  /// Couleur de fond pastel pour le thème
  Color get backgroundColor {
    switch (this) {
      case NoteTheme.none:
        return Colors.transparent;
      case NoteTheme.mountain:
        return const Color(0xFFE3F2FD); // Bleu très pâle (ciel)
      case NoteTheme.sakura:
        return const Color(0xFFFCE4EC); // Rose très pâle
      case NoteTheme.beach:
        return const Color(0xFFFFFDE7); // Jaune sable très pâle
      case NoteTheme.autumn:
        return const Color(0xFFFBE9E7); // Orange/beige très pâle
    }
  }

  /// Icône représentant le thème (style Xiaomi - filigrane élégant)
  IconData get icon {
    switch (this) {
      case NoteTheme.none:
        return Icons.block;
      case NoteTheme.mountain:
        return Icons.landscape;
      case NoteTheme.sakura:
        return Icons.local_florist;
      case NoteTheme.beach:
        return Icons.beach_access;
      case NoteTheme.autumn:
        return Icons.eco;
    }
  }

  /// Couleur de l'icône/accent du thème
  Color get accentColor {
    switch (this) {
      case NoteTheme.none:
        return Colors.grey;
      case NoteTheme.mountain:
        return const Color(0xFF5C6BC0); // Indigo
      case NoteTheme.sakura:
        return const Color(0xFFF48FB1); // Rose
      case NoteTheme.beach:
        return const Color(0xFF4DD0E1); // Cyan
      case NoteTheme.autumn:
        return const Color(0xFFFF8A65); // Orange
    }
  }

  String get label {
    switch (this) {
      case NoteTheme.none:
        return 'Aucun';
      case NoteTheme.mountain:
        return 'Montagne';
      case NoteTheme.sakura:
        return 'Sakura';
      case NoteTheme.beach:
        return 'Plage';
      case NoteTheme.autumn:
        return 'Automne';
    }
  }

  /// Les thèmes utilisent un texte sombre sur fond pastel clair
  bool get needsDarkText => this != NoteTheme.none;
}

class Note {
  final int? id;
  final String title;
  final String content;
  final DateTime createdAt;
  final String userId;
  final bool isFavorite;
  final NoteColor color;
  final NoteTheme theme;

  Note({
    this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.userId,
    this.isFavorite = false,
    this.color = NoteColor.none,
    this.theme = NoteTheme.none,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as int?,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      userId: json['user_id'] as String,
      isFavorite: json['is_favorite'] as bool? ?? false,
      color: NoteColor.values.firstWhere(
        (c) => c.name == (json['color'] as String?),
        orElse: () => NoteColor.none,
      ),
      theme: NoteTheme.values.firstWhere(
        (t) => t.name == (json['theme'] as String?),
        orElse: () => NoteTheme.none,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'user_id': userId,
      'is_favorite': isFavorite,
      'color': color.name,
      'theme': theme.name,
    };
  }

  Note copyWith({
    int? id,
    String? title,
    String? content,
    DateTime? createdAt,
    String? userId,
    bool? isFavorite,
    NoteColor? color,
    NoteTheme? theme,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      isFavorite: isFavorite ?? this.isFavorite,
      color: color ?? this.color,
      theme: theme ?? this.theme,
    );
  }

  /// Détermine la couleur du texte en fonction du fond
  Color getTextColor(BuildContext context) {
    if (theme != NoteTheme.none) {
      return Colors.black87; // Texte sombre sur fond pastel clair
    }
    if (color != NoteColor.none) {
      return Colors.black87; // Texte sombre sur couleur pastel
    }
    return Theme.of(context).colorScheme.onSurface;
  }

  /// Détermine la couleur du hint en fonction du fond
  Color getHintColor(BuildContext context) {
    if (theme != NoteTheme.none) {
      return Colors.black45;
    }
    if (color != NoteColor.none) {
      return Colors.black54;
    }
    return Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5);
  }
}

