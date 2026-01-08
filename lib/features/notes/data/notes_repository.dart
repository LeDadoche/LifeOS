import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'note_model.dart';

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository(Supabase.instance.client);
});

final notesProvider = StreamProvider<List<Note>>((ref) {
  return ref.watch(notesRepositoryProvider).watchAllNotes();
});

class NotesRepository {
  final SupabaseClient _client;
  
  // Flag pour savoir si les nouvelles colonnes existent
  bool _hasNewColumns = true;

  NotesRepository(this._client);

  Future<void> addNote(String title, String content, {
    bool isFavorite = false,
    NoteColor color = NoteColor.none,
    NoteTheme theme = NoteTheme.none,
    String? sketchData,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final data = <String, dynamic>{
      'title': title,
      'content': content,
      'user_id': user.id,
    };

    // Ajouter les nouveaux champs seulement si supportés
    if (_hasNewColumns) {
      data['is_favorite'] = isFavorite;
      data['color'] = color.name;
      data['theme'] = theme.name;
      if (sketchData != null) {
        data['sketch_data'] = sketchData;
      }
    }

    try {
      await _client.from('notes').insert(data);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST204' || e.message.contains('column')) {
        _hasNewColumns = false;
        // Réessayer sans les nouveaux champs
        await _client.from('notes').insert({
          'title': title,
          'content': content,
          'user_id': user.id,
        });
      } else {
        rethrow;
      }
    }
  }

  Future<void> updateNote(Note note) async {
    if (note.id == null) {
      debugPrint('⚠️ [NotesRepository] updateNote: ID is null, aborting');
      return;
    }

    debugPrint('📝 [NotesRepository] Updating note ID: ${note.id}');

    final data = <String, dynamic>{
      'title': note.title,
      'content': note.content,
    };

    if (_hasNewColumns) {
      data['is_favorite'] = note.isFavorite;
      data['color'] = note.color.name;
      data['theme'] = note.theme.name;
      if (note.sketchData != null) {
        data['sketch_data'] = note.sketchData;
      }
    }

    try {
      await _client.from('notes').update(data).eq('id', note.id!);
      debugPrint('✅ [NotesRepository] Note ${note.id} updated successfully');
    } on PostgrestException catch (e) {
      debugPrint('❌ [NotesRepository] PostgrestException: ${e.code} - ${e.message}');
      if (e.code == 'PGRST204' || e.message.contains('column')) {
        _hasNewColumns = false;
        // Réessayer sans les nouveaux champs
        await _client.from('notes').update({
          'title': note.title,
          'content': note.content,
        }).eq('id', note.id!);
        debugPrint('✅ [NotesRepository] Note ${note.id} updated (fallback mode)');
      } else {
        rethrow;
      }
    }
  }

  Future<void> toggleFavorite(Note note) async {
    if (note.id == null || !_hasNewColumns) return;
    
    try {
      await _client.from('notes').update({
        'is_favorite': !note.isFavorite,
      }).eq('id', note.id!);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST204' || e.message.contains('column')) {
        _hasNewColumns = false;
      } else {
        rethrow;
      }
    }
  }

  Future<void> updateAppearance(int noteId, NoteColor color, NoteTheme theme) async {
    if (!_hasNewColumns) return;
    
    try {
      await _client.from('notes').update({
        'color': color.name,
        'theme': theme.name,
      }).eq('id', noteId);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST204' || e.message.contains('column')) {
        _hasNewColumns = false;
      } else {
        rethrow;
      }
    }
  }

  Future<void> deleteNote(int id) async {
    await _client.from('notes').delete().eq('id', id);
  }

  String? get _currentUserId => _client.auth.currentUser?.id;

  Stream<List<Note>> watchAllNotes() {
    final userId = _currentUserId;
    if (userId == null) {
      debugPrint('⚠️ [Realtime] watchAllNotes: No user logged in');
      return Stream.value([]);
    }
    debugPrint('🔄 [Realtime] Initialisation stream NOTES pour user $userId');
    return _client
        .from('notes')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((data) {
          debugPrint('🔄 [Realtime] Nouvelle donnée reçue pour [notes] - ${data.length} éléments');
          final notes = data.map((json) => Note.fromJson(json)).toList();
          // Trier manuellement : favoris en premier (si le champ existe)
          notes.sort((a, b) {
            if (a.isFavorite && !b.isFavorite) return -1;
            if (!a.isFavorite && b.isFavorite) return 1;
            return b.createdAt.compareTo(a.createdAt);
          });
          return notes;
        });
  }
}

