import 'package:flutter/material.dart';

/// Widget qui gère le padding du clavier de manière optimisée.
/// 
/// Ce widget isole les rebuilds liés au clavier pour éviter les problèmes
/// de performance sur les appareils MIUI/POCO qui ont des animations
/// de clavier longues (500ms+).
/// 
/// POURQUOI CE WIDGET ?
/// - `MediaQuery.of(context)` cause un rebuild complet de tout l'arbre
/// - `MediaQuery.viewInsetsOf(context)` n'écoute QUE les viewInsets
/// - Ce widget encapsule cette logique pour une réutilisation facile
/// 
/// USAGE :
/// ```dart
/// KeyboardSafeArea(
///   child: SingleChildScrollView(
///     child: Form(...),
///   ),
/// )
/// ```
class KeyboardSafeArea extends StatelessWidget {
  /// Le widget enfant qui doit être protégé du clavier
  final Widget child;
  
  /// Padding supplémentaire en plus du clavier (ex: 16.0 pour de l'espace)
  final double additionalBottomPadding;
  
  /// Durée de l'animation du padding (défaut: 150ms pour fluidité)
  final Duration animationDuration;
  
  /// Courbe de l'animation
  final Curve animationCurve;

  const KeyboardSafeArea({
    super.key,
    required this.child,
    this.additionalBottomPadding = 0,
    this.animationDuration = const Duration(milliseconds: 150),
    this.animationCurve = Curves.easeOut,
  });

  @override
  Widget build(BuildContext context) {
    // IMPORTANT: Utiliser viewInsetsOf au lieu de MediaQuery.of
    // Cela évite les rebuilds quand d'autres propriétés MediaQuery changent
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    
    return AnimatedPadding(
      duration: animationDuration,
      curve: animationCurve,
      padding: EdgeInsets.only(bottom: bottomInset + additionalBottomPadding),
      child: child,
    );
  }
}

/// Version pour les BottomSheets qui ont besoin de s'adapter au clavier
/// 
/// USAGE dans showModalBottomSheet :
/// ```dart
/// showModalBottomSheet(
///   isScrollControlled: true,
///   builder: (context) => KeyboardAwareBottomSheet(
///     child: YourFormWidget(),
///   ),
/// )
/// ```
class KeyboardAwareBottomSheet extends StatelessWidget {
  final Widget child;
  final double minHeight;
  final double maxHeightFraction;
  final EdgeInsets contentPadding;

  const KeyboardAwareBottomSheet({
    super.key,
    required this.child,
    this.minHeight = 200,
    this.maxHeightFraction = 0.9,
    this.contentPadding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    // Utiliser viewInsetsOf pour isoler les rebuilds
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    
    return Container(
      constraints: BoxConstraints(
        minHeight: minHeight,
        maxHeight: screenHeight * maxHeightFraction,
      ),
      padding: contentPadding.copyWith(
        bottom: contentPadding.bottom + bottomInset,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: child,
      ),
    );
  }
}
