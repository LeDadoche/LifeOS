import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider pour gérer le mode confidentialité des finances
/// Masque tous les montants avec '***€' quand activé
final privacyModeProvider =
    StateNotifierProvider<PrivacyModeNotifier, bool>((ref) {
  return PrivacyModeNotifier();
});

class PrivacyModeNotifier extends StateNotifier<bool> {
  static const String _key = 'finance_privacy_mode';

  PrivacyModeNotifier() : super(false) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
  }

  Future<void> setPrivacy(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

/// Extension pour faciliter le masquage des montants
extension PrivacyAmount on double {
  String toPrivacyString({bool isHidden = false, int decimals = 2}) {
    if (isHidden) {
      return '***€';
    }
    return '${toStringAsFixed(decimals)}€';
  }
}

/// Widget helper pour afficher un montant avec support du mode privacy
String formatAmount(double amount, bool isPrivate,
    {int decimals = 2, bool showSign = false}) {
  if (isPrivate) {
    return '***€';
  }
  final prefix = showSign && amount > 0 ? '+' : '';
  return '$prefix${amount.toStringAsFixed(decimals)}€';
}
