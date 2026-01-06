import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import '../../data/notes_repository.dart';
import '../../data/note_model.dart';

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  void _showAddNoteDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                hintText: 'Titre',
                border: InputBorder.none,
                hintStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(
                hintText: 'Contenu de la note...',
                border: InputBorder.none,
              ),
              maxLines: 5,
              minLines: 1,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () {
                    if (titleController.text.isNotEmpty ||
                        contentController.text.isNotEmpty) {
                      ref.read(notesRepositoryProvider).addNote(
                            titleController.text,
                            contentController.text,
                          );
                      context.pop();
                    }
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Notes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: notesAsync.when(
        data: (notes) {
          if (notes.isEmpty) {
            return const Center(
              child: Text('Aucune note pour le moment 📝'),
            );
          }
          return MasonryGridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return _NoteCard(note: note);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Erreur: $error', style: TextStyle(color: colorScheme.error))),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddNoteDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Carte de note avec support des couleurs et favoris
class _NoteCard extends ConsumerWidget {
  final Note note;

  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Déterminer les couleurs de fond et de texte
    final hasColor = note.color != NoteColor.none;
    final hasTheme = note.theme != NoteTheme.none;
    
    // Le thème a priorité sur la couleur
    Color backgroundColor;
    if (hasTheme) {
      backgroundColor = note.theme.backgroundColor;
    } else if (hasColor) {
      backgroundColor = note.color.color;
    } else {
      backgroundColor = colorScheme.surfaceContainer;
    }
    
    final textColor = note.getTextColor(context);
    final hintColor = note.getHintColor(context);

    Widget cardContent = Padding(
      padding: const EdgeInsets.all(16.0),
      child: Stack(
        children: [
          // Icône du thème en filigrane (si thème)
          if (hasTheme)
            Positioned(
              top: 0,
              right: 0,
              child: Icon(
                note.theme.icon,
                size: 48,
                color: note.theme.accentColor.withOpacity(0.15),
              ),
            ),
          // Contenu principal
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ligne du haut avec titre et étoile
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: note.title.isNotEmpty
                        ? Text(
                            note.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  // Icône favoris
                  GestureDetector(
                    onTap: () => ref.read(notesRepositoryProvider).toggleFavorite(note),
                    child: Icon(
                      note.isFavorite ? Icons.star : Icons.star_border,
                      color: note.isFavorite ? Colors.amber : hintColor,
                      size: 22,
                    ),
                  ),
                ],
              ),
              if (note.title.isNotEmpty && note.content.isNotEmpty)
                const SizedBox(height: 8),
              if (note.content.isNotEmpty)
                Text(
                  note.content,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: hintColor,
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    return Card(
      color: backgroundColor,
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      child: InkWell(
        onTap: () => context.push('/notes/detail', extra: note),
        onLongPress: () {
          _showDeleteDialog(context, ref, note);
        },
        child: cardContent,
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, Note note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette note ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              if (note.id != null) {
                ref.read(notesRepositoryProvider).deleteNote(note.id!);
              }
              Navigator.pop(context);
            },
            child: Text('Supprimer', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}
