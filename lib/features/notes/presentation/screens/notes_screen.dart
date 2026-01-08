import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import '../../data/notes_repository.dart';
import '../../data/note_model.dart';
import 'sketch_screen.dart';

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  void _showAddNoteDialog(BuildContext context, WidgetRef ref,
      {String? initialSketchData}) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String? sketchData = initialSketchData;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Utiliser viewInsetsOf pour éviter les rebuilds excessifs sur MIUI
          final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
          
          return Padding(
            padding: EdgeInsets.only(
              bottom: bottomInset,
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
                    hintStyle:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  style:
                      const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                const SizedBox(height: 12),
                // Aperçu du croquis si présent
                if (sketchData != null) ...[
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(sketchData!),
                            fit: BoxFit.contain,
                            width: double.infinity,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton(
                            icon: Icon(Icons.close,
                                size: 18,
                                color: Theme.of(context).colorScheme.error),
                            onPressed: () => setState(() => sketchData = null),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.8),
                              padding: const EdgeInsets.all(4),
                              minimumSize: const Size(24, 24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // Bouton ajouter croquis
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.of(context).push<String?>(
                      MaterialPageRoute(
                        builder: (_) =>
                            SketchScreen(existingSketchData: sketchData),
                      ),
                    );
                    if (result != null) {
                      setState(() => sketchData = result);
                    }
                  },
                  icon: const Icon(Icons.brush, size: 18),
                  label: Text(sketchData != null
                      ? 'Modifier le croquis'
                      : 'Ajouter un croquis'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                  ),
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
                            contentController.text.isNotEmpty ||
                            sketchData != null) {
                          ref.read(notesRepositoryProvider).addNote(
                                titleController.text,
                                contentController.text,
                                sketchData: sketchData,
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
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: false,
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
        error: (error, stack) => Center(
            child: Text('Erreur: $error',
                style: TextStyle(color: colorScheme.error))),
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
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  // Icône favoris
                  GestureDetector(
                    onTap: () =>
                        ref.read(notesRepositoryProvider).toggleFavorite(note),
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
              // Aperçu du croquis si présent
              if (note.hasSketch && note.sketchImageBase64 != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.memory(
                    base64Decode(note.sketchImageBase64!),
                    height: 60,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    return Card(
      color: backgroundColor,
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      child: GestureDetector(
        onSecondaryTapDown: (details) {
          _showContextMenu(context, ref, note, details.globalPosition);
        },
        onLongPressStart: (details) {
          HapticFeedback.mediumImpact();
          _showContextMenu(context, ref, note, details.globalPosition);
        },
        child: InkWell(
          onTap: () => context.push('/notes/detail', extra: note),
          child: cardContent,
        ),
      ),
    );
  }

  /// Affiche le menu contextuel à une position donnée
  void _showContextMenu(
      BuildContext context, WidgetRef ref, Note note, Offset position) {
    final colorScheme = Theme.of(context).colorScheme;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 20, color: colorScheme.onSurface),
              const SizedBox(width: 12),
              const Text('Modifier'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'favorite',
          child: Row(
            children: [
              Icon(
                note.isFavorite ? Icons.star : Icons.star_border,
                size: 20,
                color: note.isFavorite ? Colors.amber : colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Text(note.isFavorite
                  ? 'Retirer des favoris'
                  : 'Ajouter aux favoris'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 20, color: colorScheme.error),
              const SizedBox(width: 12),
              Text('Supprimer', style: TextStyle(color: colorScheme.error)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;

      switch (value) {
        case 'edit':
          context.push('/notes/detail', extra: note);
          break;
        case 'favorite':
          ref.read(notesRepositoryProvider).toggleFavorite(note);
          break;
        case 'delete':
          _showDeleteDialog(context, ref, note);
          break;
      }
    });
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, Note note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.delete_outline,
            color: Theme.of(context).colorScheme.error),
        title: const Text('Supprimer cette note ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (note.id != null) {
                ref.read(notesRepositoryProvider).deleteNote(note.id!);
              }
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
