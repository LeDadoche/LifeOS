import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/notes_repository.dart';
import '../../../settings/presentation/providers/widget_style_provider.dart';

class NotesDashboardTile extends ConsumerWidget {
  const NotesDashboardTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);
    final style = ref.watch(widgetStyleProvider((
      type: 'notes',
      defaultColor: Colors.purple,
      defaultIcon: Icons.note,
    )));

    final primaryColor = style.color;
    final colorScheme = Theme.of(context).colorScheme;
    // Glassmorphism: semi-transparent surfaceContainer with primary tint
    final containerColor = colorScheme.surfaceContainerHighest.withOpacity(0.7);
    final onContainerColor = primaryColor;

    return Card(
      elevation: 4,
      shadowColor: primaryColor.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      color: containerColor,
      child: InkWell(
        onTap: () => context.push('/notes'),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            border:
                Border.all(color: primaryColor.withOpacity(0.2), width: 1.5),
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor.withOpacity(0.08),
                primaryColor.withOpacity(0.02),
              ],
            ),
          ),
          padding: const EdgeInsets.all(16.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return notesAsync.when(
                data: (notes) {
                  final count = notes.length;
                  final lastNote = notes.isNotEmpty ? notes.first : null;
                  final lastNoteTitle = lastNote?.title ?? '';
                  final lastNoteHasSketch = lastNote?.hasSketch ?? false;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(style.icon, size: 24, color: primaryColor),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Notes',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: onContainerColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Aperçu du croquis si présent dans la dernière note
                      if (lastNoteHasSketch &&
                          lastNote?.sketchImageBase64 != null) ...[
                        Expanded(
                          flex: 2,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(lastNote!.sketchImageBase64!),
                              fit: BoxFit.contain,
                              width: double.infinity,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ] else ...[
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$count',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ],
                      if (lastNoteTitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            lastNoteHasSketch
                                ? lastNoteTitle
                                : 'Dernière : $lastNoteTitle',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: onContainerColor.withOpacity(0.8),
                                    ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const Spacer(),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                    child: Text('Erreur',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
              );
            },
          ),
        ),
      ),
    );
  }
}
