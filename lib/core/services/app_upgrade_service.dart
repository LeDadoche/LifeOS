import 'package:flutter/material.dart';
import 'package:upgrader/upgrader.dart';

/// Service de mise à jour de l'application via GitHub Releases
class AppUpgradeService {
  /// Configuration de l'Upgrader pour GitHub
  /// 
  /// IMPORTANT: Remplacez 'VOTRE_USERNAME' et 'VOTRE_REPO' par vos valeurs
  /// Exemple: 'https://github.com/monuser/life_os/releases/latest/download/app-release.json'
  static const String _githubReleasesUrl = 
      'https://github.com/VOTRE_USERNAME/VOTRE_REPO/releases/latest/download/appcast.xml';

  /// Messages personnalisés en français
  static UpgraderMessages get frenchMessages => UpgraderMessages(
    code: 'fr',
  );

  /// Crée le widget Upgrader à wrapper autour de l'app
  static Widget wrapWithUpgrader({required Widget child}) {
    return UpgradeAlert(
      upgrader: Upgrader(
        // Configuration GitHub - URL de votre fichier appcast.xml
        // Vous devez créer ce fichier dans vos releases GitHub
        storeController: UpgraderStoreController(
          onAndroid: () => UpgraderAppcastStore(
            appcastURL: _githubReleasesUrl,
          ),
          oniOS: () => UpgraderAppcastStore(
            appcastURL: _githubReleasesUrl,
          ),
        ),
        
        // Personnalisation des messages en français
        messages: frenchMessages,
        
        // Fréquence de vérification (une fois par jour)
        durationUntilAlertAgain: const Duration(days: 1),
        
        // Mode debug pour tester (à désactiver en production)
        debugLogging: true,
      ),
      // Options d'affichage via UpgradeAlert
      showIgnore: true,  // Bouton "Ignorer"
      showLater: true,   // Bouton "Plus tard"
      showReleaseNotes: true, // Afficher les notes de version
      child: child,
    );
  }
}

/// Extension pour personnaliser les messages en français
/// Vous pouvez modifier ces textes selon vos préférences
class FrenchUpgraderMessages extends UpgraderMessages {
  @override
  String get title => 'Nouvelle version disponible !';

  @override
  String get body => 'Une nouvelle version de LifeOS est disponible. '
      'Voulez-vous la télécharger maintenant ?';

  @override
  String get buttonTitleIgnore => 'Ignorer';

  @override
  String get buttonTitleLater => 'Plus tard';

  @override
  String get buttonTitleUpdate => 'Mettre à jour';

  @override
  String get releaseNotes => 'Nouveautés :';

  @override
  String get prompt => 'Souhaitez-vous mettre à jour ?';
}
