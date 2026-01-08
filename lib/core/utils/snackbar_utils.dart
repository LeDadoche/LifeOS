import 'package:flutter/material.dart';

/// Utilitaire pour afficher des SnackBars de manière cohérente
/// avec suppression automatique des anciens SnackBars
class SnackBarUtils {
  /// Affiche un SnackBar en supprimant d'abord tous les SnackBars existants
  static void show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 5),
    SnackBarAction? action,
    Color? backgroundColor,
    IconData? icon,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    
    final colorScheme = Theme.of(context).colorScheme;
    
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: colorScheme.onInverseSurface, size: 20),
              const SizedBox(width: 12),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        action: action,
      ),
    );
  }

  /// Affiche un SnackBar de succès (vert)
  static void showSuccess(BuildContext context, String message) {
    show(
      context,
      message: message,
      backgroundColor: Colors.green.shade700,
      icon: Icons.check_circle,
    );
  }

  /// Affiche un SnackBar d'erreur (rouge)
  static void showError(BuildContext context, String message) {
    show(
      context,
      message: message,
      backgroundColor: Colors.red.shade700,
      icon: Icons.error,
    );
  }

  /// Affiche un SnackBar d'information
  static void showInfo(BuildContext context, String message) {
    show(
      context,
      message: message,
      icon: Icons.info_outline,
    );
  }
}
