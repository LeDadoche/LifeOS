import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/note_model.dart';
import '../../data/notes_repository.dart';

class NoteDetailScreen extends ConsumerStatefulWidget {
  final Note note;

  const NoteDetailScreen({super.key, required this.note});

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  Timer? _debounce;
  bool _isSaving = false;
  late NotesRepository _notesRepository;
  
  // État local pour couleur et thème
  late NoteColor _currentColor;
  late NoteTheme _currentTheme;
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _notesRepository = ref.read(notesRepositoryProvider);
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);
    _currentColor = widget.note.color;
    _currentTheme = widget.note.theme;
    _isFavorite = widget.note.isFavorite;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _saveNoteImmediate();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onNoteChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    setState(() {
      _isSaving = true;
    });

    _debounce = Timer(const Duration(milliseconds: 1000), () {
      _saveNoteToCloud();
    });
  }

  Future<void> _saveNoteToCloud() async {
    final updatedNote = widget.note.copyWith(
      title: _titleController.text,
      content: _contentController.text,
      isFavorite: _isFavorite,
      color: _currentColor,
      theme: _currentTheme,
    );

    await _notesRepository.updateNote(updatedNote);

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _saveNoteImmediate() {
    final updatedNote = widget.note.copyWith(
      title: _titleController.text,
      content: _contentController.text,
      isFavorite: _isFavorite,
      color: _currentColor,
      theme: _currentTheme,
    );
    _notesRepository.updateNote(updatedNote);
  }

  void _saveAndExit() {
    _saveNoteImmediate();
    context.pop();
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorite = !_isFavorite;
    });
    _onNoteChanged();
  }

  void _deleteNote() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette note ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              if (widget.note.id != null) {
                _notesRepository.deleteNote(widget.note.id!);
              }
              context.pop(); // Close dialog
              context.pop(); // Go back to list
            },
            child: Text('Supprimer', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  void _showAppearanceSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _AppearanceSheet(
        currentColor: _currentColor,
        currentTheme: _currentTheme,
        onColorSelected: (color) {
          Navigator.pop(sheetContext); // Fermer d'abord
          setState(() {
            _currentColor = color;
            _currentTheme = NoteTheme.none;
          });
          _onNoteChanged();
        },
        onThemeSelected: (theme) {
          Navigator.pop(sheetContext); // Fermer d'abord
          setState(() {
            _currentTheme = theme;
            _currentColor = NoteColor.none;
          });
          _onNoteChanged();
        },
      ),
    );
  }

  // Détermine les couleurs en fonction de l'état actuel
  Color _getTextColor() {
    // Les thèmes ont maintenant des fonds pastels clairs → texte sombre
    if (_currentTheme != NoteTheme.none) {
      return Colors.black87;
    }
    if (_currentColor != NoteColor.none) {
      return Colors.black87;
    }
    return Theme.of(context).colorScheme.onSurface;
  }

  Color _getHintColor() {
    if (_currentTheme != NoteTheme.none) {
      return Colors.black45;
    }
    if (_currentColor != NoteColor.none) {
      return Colors.black54;
    }
    return Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5);
  }

  Color _getBackgroundColor() {
    // Priorité au thème, sinon couleur
    if (_currentTheme != NoteTheme.none) {
      return _currentTheme.backgroundColor;
    }
    if (_currentColor != NoteColor.none) {
      return _currentColor.color;
    }
    return Theme.of(context).colorScheme.surface;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final textColor = _getTextColor();
    final hintColor = _getHintColor();
    final backgroundColor = _getBackgroundColor();
    final hasTheme = _currentTheme != NoteTheme.none;

    // Widget des champs de texte (couche supérieure)
    Widget textFields = Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _titleController,
            onChanged: (_) => _onNoteChanged(),
            decoration: InputDecoration(
              hintText: 'Titre',
              border: InputBorder.none,
              hintStyle: textTheme.headlineMedium?.copyWith(
                color: hintColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TextField(
              controller: _contentController,
              onChanged: (_) => _onNoteChanged(),
              decoration: InputDecoration(
                hintText: 'Contenu de la note...',
                border: InputBorder.none,
                hintStyle: textTheme.bodyLarge?.copyWith(
                  color: hintColor,
                ),
              ),
              style: textTheme.bodyLarge?.copyWith(
                color: textColor,
              ),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
            ),
          ),
        ],
      ),
    );

    // Construction du corps avec Stack (fond + icône filigrane + texte)
    Widget body = Stack(
      children: [
        // COUCHE 1 : Fond uni (pastel si thème/couleur, sinon surface)
        Positioned.fill(
          child: Container(color: backgroundColor),
        ),
        // COUCHE 2 : Icône filigrane style Xiaomi (thème uniquement)
        if (hasTheme)
          Positioned(
            bottom: 40,
            right: 20,
            child: Icon(
              _currentTheme.icon,
              size: 200,
              color: _currentTheme.accentColor.withOpacity(0.08),
            ),
          ),
        // COUCHE 3 : Contenu texte
        textFields,
      ],
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          // Bouton favoris
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.star : Icons.star_border,
              color: _isFavorite ? Colors.amber : null,
            ),
            onPressed: _toggleFavorite,
            tooltip: _isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
          ),
          // Bouton apparence
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            onPressed: _showAppearanceSheet,
            tooltip: 'Apparence',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteNote,
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveAndExit,
          ),
        ],
      ),
      body: body,
    );
  }

}

/// Bottom sheet pour choisir l'apparence de la note
class _AppearanceSheet extends StatelessWidget {
  final NoteColor currentColor;
  final NoteTheme currentTheme;
  final void Function(NoteColor) onColorSelected;
  final void Function(NoteTheme) onThemeSelected;

  const _AppearanceSheet({
    required this.currentColor,
    required this.currentTheme,
    required this.onColorSelected,
    required this.onThemeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Titre
          Text(
            'Apparence',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Section Couleurs
          Text(
            'Couleurs',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ColorCircle(
                color: Colors.transparent,
                isSelected: currentColor == NoteColor.none && currentTheme == NoteTheme.none,
                onTap: () => onColorSelected(NoteColor.none),
                icon: Icons.block,
              ),
              ...NoteColor.values.where((c) => c != NoteColor.none).map((color) => 
                _ColorCircle(
                  color: color.color,
                  isSelected: currentColor == color,
                  onTap: () => onColorSelected(color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section Thèmes - Centrée
          Text(
            'Thèmes',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          // Wrap centré pour les thèmes
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: NoteTheme.values.where((t) => t != NoteTheme.none).map((theme) => 
                _ThemeCard(
                  theme: theme,
                  isSelected: currentTheme == theme,
                  onTap: () => onThemeSelected(theme),
                ),
              ).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Cercle de couleur sélectionnable
class _ColorCircle extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  const _ColorCircle({
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color == Colors.transparent ? null : color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary 
                : Theme.of(context).colorScheme.outline,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: icon != null
            ? Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant)
            : isSelected 
                ? const Icon(Icons.check, size: 20, color: Colors.black54)
                : null,
      ),
    );
  }
}

/// Carte de thème sélectionnable
class _ThemeCard extends StatelessWidget {
  final NoteTheme theme;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: theme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary 
                : Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.accentColor.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Icône en filigrane
            Positioned(
              top: 8,
              right: 8,
              child: Icon(
                theme.icon,
                size: 40,
                color: theme.accentColor.withOpacity(0.25),
              ),
            ),
            // Contenu
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSelected ? Icons.check_circle : theme.icon,
                    color: isSelected 
                        ? Theme.of(context).colorScheme.primary 
                        : theme.accentColor,
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    theme.label,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
