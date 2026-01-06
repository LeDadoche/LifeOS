/// Utilitaires de formatage culinaire
/// Gère les unités métriques et le formatage des ingrédients
library;
import 'ingredient_translator.dart';

class CulinaryFormatter {
  /// Traduction des unités anglaises vers français (métrique)
  static const Map<String, String> unitTranslations = {
    // Masses
    'gram': 'g',
    'grams': 'g',
    'g': 'g',
    'kilogram': 'kg',
    'kilograms': 'kg',
    'kg': 'kg',

    // Volumes
    'milliliter': 'ml',
    'milliliters': 'ml',
    'ml': 'ml',
    'liter': 'L',
    'liters': 'L',
    'l': 'L',
    'litre': 'L',
    'litres': 'L',

    // Cuillères
    'tablespoon': 'c. à soupe',
    'tablespoons': 'c. à soupe',
    'tbsp': 'c. à soupe',
    'tbsps': 'c. à soupe',
    'teaspoon': 'c. à café',
    'teaspoons': 'c. à café',
    'tsp': 'c. à café',
    'tsps': 'c. à café',

    // Autres
    'pinch': 'pincée',
    'pinches': 'pincées',
    'pkg': 'paquet',
    'package': 'paquet',
    'packages': 'paquets',
    'sachet': 'sachet',
    'sachets': 'sachets',
    'bunch': 'botte',
    'bunches': 'bottes',
    'clove': 'gousse',
    'cloves': 'gousses',
    'slice': 'tranche',
    'slices': 'tranches',
    'piece': 'morceau',
    'pieces': 'morceaux',
    'handful': 'poignée',
    'handfuls': 'poignées',
    'sprig': 'brin',
    'sprigs': 'brins',
    'leaf': 'feuille',
    'leaves': 'feuilles',
    'stalk': 'tige',
    'stalks': 'tiges',
    'head': 'tête',
    'heads': 'têtes',
    'can': 'boîte',
    'cans': 'boîtes',
    'jar': 'pot',
    'jars': 'pots',
    'bottle': 'bouteille',
    'bottles': 'bouteilles',

    // Unités à masquer (renverra vide)
    'unit': '',
    'units': '',
    'item': '',
    'items': '',
    'serving': '',
    'servings': '',
    'large': '',
    'medium': '',
    'small': '',

    // Unités US à ignorer (fallback vers métrique préféré)
    'cup': 'tasse',
    'cups': 'tasses',
    'ounce': 'oz',
    'ounces': 'oz',
    'oz': 'oz',
    'pound': 'lb',
    'pounds': 'lb',
    'lb': 'lb',
    'lbs': 'lb',
    'pint': 'pinte',
    'pints': 'pintes',
    'quart': 'quart',
    'quarts': 'quarts',
    'gallon': 'gallon',
    'gallons': 'gallons',
    'fluid ounce': 'fl oz',
    'fluid ounces': 'fl oz',
    'fl oz': 'fl oz',
  };

  /// Traduit une unité anglaise en français
  static String translateUnit(String unit) {
    final lower = unit.toLowerCase().trim();
    return unitTranslations[lower] ?? unit;
  }

  /// Formate une quantité : entier si possible, sinon 1 décimale
  static String formatQuantity(double amount) {
    if (amount == 0) return '';
    // Vérifier si c'est un entier
    if (amount == amount.truncateToDouble()) {
      return amount.toInt().toString();
    }
    // Sinon, une décimale max
    final formatted = amount.toStringAsFixed(1);
    // Retirer le .0 final si présent
    return formatted.endsWith('.0')
        ? formatted.substring(0, formatted.length - 2)
        : formatted;
  }

  /// Convertit un texte en Sentence Case (première lettre du premier mot en majuscule)
  /// Ex: "fromage suisse" au lieu de "Fromage Suisse"
  static String toSentenceCase(String text) {
    if (text.isEmpty) return text;
    final trimmed = text.trim();
    return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
  }

  /// Nettoie un nom d'ingrédient : retire parenthèses et espaces superflus
  static String cleanIngredientName(String name) {
    // Retirer le contenu entre parenthèses
    String cleaned = name.replaceAll(RegExp(r'\([^)]*\)'), '');
    // Retirer les doubles espaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  /// Formate un ingrédient complet : "Quantité Unité Nom"
  /// Ex: "200 g Fromage suisse"
  static String formatIngredient({
    required String name,
    required double amount,
    required String unit,
    int servings = 1,
  }) {
    final adjustedAmount = amount * servings;
    final formattedQty = formatQuantity(adjustedAmount);
    final translatedUnit = translateUnit(unit);

    // Nettoyer puis traduire le nom
    final cleanedName = cleanIngredientName(name);
    final translatedName = IngredientTranslator.translateFullName(cleanedName);
    final formattedName = toSentenceCase(translatedName);

    // Construction du texte
    final parts = <String>[];
    if (formattedQty.isNotEmpty) parts.add(formattedQty);
    if (translatedUnit.isNotEmpty) parts.add(translatedUnit);
    parts.add(formattedName);

    return parts.join(' ');
  }

  /// Extrait les mesures métriques d'un ingrédient Spoonacular
  /// Retourne {amount, unit} depuis measures.metric
  static Map<String, dynamic> extractMetricMeasures(
      Map<String, dynamic> ingredient) {
    final measures = ingredient['measures'] as Map<String, dynamic>?;

    if (measures != null && measures['metric'] != null) {
      final metric = measures['metric'] as Map<String, dynamic>;
      return {
        'amount': (metric['amount'] as num?)?.toDouble() ?? 0.0,
        'unit': metric['unitShort'] as String? ??
            metric['unitLong'] as String? ??
            '',
      };
    }

    // Fallback sur les valeurs de base
    return {
      'amount': (ingredient['amount'] as num?)?.toDouble() ?? 0.0,
      'unit': ingredient['unit'] as String? ?? '',
    };
  }
}
