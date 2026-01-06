import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/home_widget_service.dart';
import '../../data/tasks_repository.dart';

/// Page minimaliste pour ajout rapide de tâche depuis le widget.
/// S'ouvre avec le clavier déjà visible et se ferme après validation.
class QuickAddTaskScreen extends ConsumerStatefulWidget {
  const QuickAddTaskScreen({super.key});

  @override
  ConsumerState<QuickAddTaskScreen> createState() => _QuickAddTaskScreenState();
}

class _QuickAddTaskScreenState extends ConsumerState<QuickAddTaskScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    debugPrint('📝 [QuickAddTask] Screen initialized!');
    // Demander le focus après le premier frame pour ouvrir le clavier
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('📝 [QuickAddTask] Requesting focus for keyboard...');
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submitTask() async {
    final title = _controller.text.trim();
    if (title.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      // Ajouter la tâche
      final repo = ref.read(tasksRepositoryProvider);
      await repo.addTask(title);

      // Mettre à jour le widget
      final homeWidgetService = HomeWidgetService();
      await homeWidgetService.updateTasksWidget();

      // Feedback haptique
      HapticFeedback.lightImpact();

      if (!mounted) return;

      // Fermer la page et retourner en arrière-plan
      _closeAndMinimize();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  void _closeAndMinimize() {
    // Fermer le clavier
    FocusScope.of(context).unfocus();

    // Si on peut revenir en arrière, le faire
    if (context.canPop()) {
      context.pop();
    } else {
      // Sinon, minimiser l'app (retour à l'écran d'accueil)
      if (Platform.isAndroid) {
        SystemNavigator.pop();
      } else {
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: colorScheme.onSurface),
          onPressed: () => _closeAndMinimize(),
        ),
        title: Text(
          'Nouvelle tâche',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submitTask,
            child: _isSubmitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  )
                : Text(
                    'Créer',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Champ de saisie principal
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                fontSize: 20,
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Que devez-vous faire ?',
                hintStyle: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 20,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onSubmitted: (_) => _submitTask(),
              textInputAction: TextInputAction.done,
            ),
            
            const SizedBox(height: 16),
            
            // Indicateur visuel
            Row(
              children: [
                Icon(
                  Icons.flash_on,
                  size: 16,
                  color: colorScheme.primary.withOpacity(0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  'Appuyez sur Entrée ou "Créer" pour ajouter',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
