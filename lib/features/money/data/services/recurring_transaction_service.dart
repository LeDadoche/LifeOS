import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../money_repository.dart';

/// Service de gestion des transactions récurrentes
/// Génère automatiquement les transactions du mois à partir des transactions permanentes
class RecurringTransactionService {
  final MoneyRepository _repository;

  RecurringTransactionService(this._repository);

  /// Clé pour stocker la dernière date de génération
  static const String _lastGenerationKey = 'last_recurring_generation';

  /// Vérifie et génère les transactions récurrentes si nécessaire
  Future<void> checkAndGenerateTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final lastGenerationStr = prefs.getString(_lastGenerationKey);
    final now = DateTime.now();

    bool shouldGenerate = false;

    if (lastGenerationStr == null) {
      // Première utilisation, on génère
      shouldGenerate = true;
    } else {
      final lastGeneration = DateTime.parse(lastGenerationStr);
      // Vérifie si on est dans un nouveau mois
      if (now.year > lastGeneration.year || 
          (now.year == lastGeneration.year && now.month > lastGeneration.month)) {
        shouldGenerate = true;
      }
    }

    if (shouldGenerate) {
      await _repository.generateMonthlyTransactions();
      await prefs.setString(_lastGenerationKey, now.toIso8601String());
    }

    // Met à jour les transactions prévues devenues passées
    await _repository.updateScheduledTransactions();
  }

  /// Force la génération des transactions pour le mois courant
  Future<void> forceGenerate() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    
    await _repository.generateMonthlyTransactions();
    await prefs.setString(_lastGenerationKey, now.toIso8601String());
  }

  /// Génère les transactions pour un mois spécifique (utile pour les tests)
  Future<void> generateForMonth(int year, int month) async {
    await _repository.generateMonthlyTransactions(
      forDate: DateTime(year, month, 1),
    );
  }
}

/// Provider pour le service de transactions récurrentes
final recurringTransactionServiceProvider = Provider<RecurringTransactionService>((ref) {
  final repository = ref.watch(moneyRepositoryProvider);
  return RecurringTransactionService(repository);
});

/// Provider pour initialiser le service au démarrage
final recurringTransactionInitProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(recurringTransactionServiceProvider);
  await service.checkAndGenerateTransactions();
});
