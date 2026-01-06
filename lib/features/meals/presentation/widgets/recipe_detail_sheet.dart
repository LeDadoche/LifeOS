import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/recipe_model.dart';
import '../../data/kitchen_repository.dart';
import '../../data/meal_model.dart';
import '../../../../core/utils/ingredient_translator.dart';
import '../../../../core/utils/culinary_formatter.dart';

class RecipeDetailSheet extends ConsumerStatefulWidget {
  final Recipe recipe;

  const RecipeDetailSheet({super.key, required this.recipe});

  @override
  ConsumerState<RecipeDetailSheet> createState() => _RecipeDetailSheetState();
}

class _RecipeDetailSheetState extends ConsumerState<RecipeDetailSheet> {
  int _servings = 1;

  @override
  Widget build(BuildContext context) {
    final shoppingListAsync = ref.watch(shoppingListProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Title & Image
                    if (widget.recipe.imageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          widget.recipe.imageUrl!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      widget.recipe.title,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Ingredients Section
                    Text(
                      'Ingrédients',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    shoppingListAsync.when(
                      data: (shoppingItems) =>
                          _buildIngredientsList(context, shoppingItems),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Text('Erreur chargement stock: $err'),
                    ),

                    const SizedBox(height: 32),

                    // Actions
                    FilledButton.tonalIcon(
                      onPressed: () => _launchPreparation(),
                      icon: const Icon(Icons.menu_book),
                      label: const Text('Voir la préparation'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Cook Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Cuisiner pour : ',
                                  style: TextStyle(
                                      color: colorScheme.onPrimaryContainer)),
                              IconButton(
                                icon: Icon(Icons.remove_circle_outline,
                                    color: colorScheme.onPrimaryContainer),
                                onPressed: _servings > 1
                                    ? () => setState(() => _servings--)
                                    : null,
                              ),
                              Text(
                                '$_servings pers.',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: colorScheme.onPrimaryContainer),
                              ),
                              IconButton(
                                icon: Icon(Icons.add_circle_outline,
                                    color: colorScheme.onPrimaryContainer),
                                onPressed: () => setState(() => _servings++),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: () =>
                                _cookRecipe(shoppingListAsync.value ?? []),
                            icon: const Icon(Icons.restaurant),
                            label: const Text('Cuisiner ce plat'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIngredientsList(BuildContext context, List<ShoppingItem> stock) {
    final ingredients = widget.recipe.ingredientsList;
    final colorScheme = Theme.of(context).colorScheme;

    if (ingredients == null || ingredients.isEmpty) {
      return Text(
        'Aucune liste d\'ingrédients disponible.',
        style: TextStyle(
            fontStyle: FontStyle.italic, color: colorScheme.onSurfaceVariant),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ingredients.map((ing) {
        final name = ing['name'] as String? ?? 'Inconnu';

        // Extract metric measures if available
        final metricMeasures = CulinaryFormatter.extractMetricMeasures(ing);
        final amount = metricMeasures['amount'] as double;
        final unit = metricMeasures['unit'] as String;

        // Check stock
        final isInStock = _isIngredientInStock(name, stock);

        // Use theme colors for proper contrast in both light and dark modes
        final chipColor = isInStock
            ? colorScheme.tertiaryContainer
            : colorScheme.errorContainer;
        final textColor = isInStock
            ? colorScheme.onTertiaryContainer
            : colorScheme.onErrorContainer;

        // Format: "200 g Farine De Blé"
        final formattedText = CulinaryFormatter.formatIngredient(
          name: name,
          amount: amount,
          unit: unit,
          servings: _servings,
        );

        return Chip(
          avatar: CircleAvatar(
            backgroundColor: textColor,
            radius: 6,
          ),
          label: Text(
            formattedText,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
          ),
          backgroundColor: chipColor,
          side: BorderSide.none,
        );
      }).toList(),
    );
  }

  bool _isIngredientInStock(String ingredientName, List<ShoppingItem> stock) {
    // Use smart matching from IngredientTranslator
    for (var item in stock) {
      if (IngredientTranslator.smartMatch(ingredientName, item.name)) {
        return true;
      }
    }

    // Fallback to old fuzzy match for edge cases
    final normalized = _normalizeForMatching(ingredientName);
    for (var item in stock) {
      final normalizedItem = _normalizeForMatching(item.name);
      if (_fuzzyMatch(normalized, normalizedItem)) {
        return true;
      }
    }
    return false;
  }

  /// Normalize text: lowercase, remove stopwords, translate common EN->FR
  String _normalizeForMatching(String text) {
    // Lowercase
    String result = text.toLowerCase();

    // Remove French stopwords
    const stopwords = [
      'de',
      'du',
      'la',
      'le',
      'les',
      'des',
      'un',
      'une',
      'à',
      'au',
      'aux',
      'd\'',
      'l\''
    ];
    for (var word in stopwords) {
      result = result.replaceAll(RegExp('\\b$word\\b'), ' ');
    }
    result = result.replaceAll(RegExp("['\"]\\s*"), ' ');

    // Translate common English ingredients to French
    result = _translateEnglishToFrench(result);

    // Remove extra spaces and trim
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    return result;
  }

  /// Fuzzy matching: check if words overlap significantly
  bool _fuzzyMatch(String a, String b) {
    // Direct contains check
    if (a.contains(b) || b.contains(a)) return true;

    // Word-level matching: check if key words match
    final wordsA = a.split(' ').where((w) => w.length > 2).toSet();
    final wordsB = b.split(' ').where((w) => w.length > 2).toSet();

    // If any significant word matches, consider it a match
    for (var wordA in wordsA) {
      for (var wordB in wordsB) {
        if (wordA.contains(wordB) || wordB.contains(wordA)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Translate common English ingredient names to French
  String _translateEnglishToFrench(String text) {
    const translations = {
      'potato': 'pomme terre',
      'potatoes': 'pommes terre',
      'tomato': 'tomate',
      'tomatoes': 'tomates',
      'onion': 'oignon',
      'onions': 'oignons',
      'garlic': 'ail',
      'chicken': 'poulet',
      'beef': 'boeuf',
      'pork': 'porc',
      'fish': 'poisson',
      'salmon': 'saumon',
      'egg': 'oeuf',
      'eggs': 'oeufs',
      'milk': 'lait',
      'butter': 'beurre',
      'cheese': 'fromage',
      'cream': 'crème',
      'flour': 'farine',
      'sugar': 'sucre',
      'salt': 'sel',
      'pepper': 'poivre',
      'oil': 'huile',
      'olive oil': 'huile olive',
      'water': 'eau',
      'carrot': 'carotte',
      'carrots': 'carottes',
      'lemon': 'citron',
      'rice': 'riz',
      'pasta': 'pâtes',
      'bread': 'pain',
      'mushroom': 'champignon',
      'mushrooms': 'champignons',
      'spinach': 'épinards',
      'broccoli': 'brocoli',
      'zucchini': 'courgette',
      'apple': 'pomme',
      'apples': 'pommes',
      'orange': 'orange',
      'banana': 'banane',
      'strawberry': 'fraise',
      'strawberries': 'fraises',
    };

    String result = text;
    for (var entry in translations.entries) {
      result = result.replaceAll(
          RegExp('\\b${entry.key}\\b', caseSensitive: false), entry.value);
    }
    return result;
  }

  Future<void> _launchPreparation() async {
    final url = widget.recipe.sourceUrl;
    print("=== DEBUG URL LAUNCHER ===");
    print("Tentative d ouverture de : $url");

    if (url != null && url.isNotEmpty) {
      try {
        final uri = Uri.parse(url);
        print("URI parsee : $uri");
        print("Scheme: ${uri.scheme}, Host: ${uri.host}");

        final canLaunch = await canLaunchUrl(uri);
        print("canLaunchUrl resultat: $canLaunch");

        if (canLaunch) {
          final launched =
              await launchUrl(uri, mode: LaunchMode.externalApplication);
          print("launchUrl resultat: $launched");
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Impossible d'ouvrir : $url"),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e, stack) {
        print("Erreur launchUrl: $e");
        print("Stack: $stack");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Erreur lors de l'ouverture : $e"),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } else {
      print("URL nulle ou vide");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Aucun lien de preparation disponible pour cette recette.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _cookRecipe(List<ShoppingItem> stock) async {
    final ingredients = widget.recipe.ingredientsList;
    if (ingredients == null) return;

    int modifiedCount = 0;
    final repo = ref.read(kitchenRepositoryProvider);

    // Backup state for Undo functionality
    final List<Map<String, dynamic>> backupItems = [];
    final List<int> deletedIds = [];
    final List<Map<String, dynamic>> updatedItems = [];

    for (var ing in ingredients) {
      final name = ing['name'] as String? ?? '';
      final amount = (ing['amount'] as num?)?.toDouble() ?? 0.0;
      final requiredAmount = amount * _servings;

      // Find matching stock item using smart matching
      ShoppingItem? match;
      for (var item in stock) {
        if (IngredientTranslator.smartMatch(name, item.name)) {
          match = item;
          break;
        }
      }

      // Fallback to old fuzzy match
      if (match == null) {
        final normalizedIng = _normalizeForMatching(name);
        for (var item in stock) {
          final normalizedItem = _normalizeForMatching(item.name);
          if (_fuzzyMatch(normalizedIng, normalizedItem)) {
            match = item;
            break;
          }
        }
      }

      if (match != null) {
        // Save backup before modifying
        backupItems.add({
          'id': match.id,
          'name': match.name,
          'quantity': match.quantity,
          'is_bought': match.isBought,
        });

        // Try to parse quantity from stock item
        final currentQtyStr = match.quantity ?? '';
        final currentQty = _parseQuantity(currentQtyStr);

        if (currentQty != null) {
          double newQty = currentQty - requiredAmount;

          if (newQty <= 0) {
            await repo.deleteShoppingItem(match.id!);
            deletedIds.add(match.id!);
            modifiedCount++;
          } else {
            final unitPart =
                currentQtyStr.replaceAll(RegExp(r'[0-9.,]'), '').trim();
            final newQtyStr =
                '${newQty.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} $unitPart';
            await repo.updateShoppingItem(match, quantity: newQtyStr);
            updatedItems.add({
              'id': match.id,
              'oldQty': match.quantity,
              'newQty': newQtyStr
            });
            modifiedCount++;
          }
        } else {
          // No quantity = assume 1 unit, remove it
          if (requiredAmount >= 1) {
            await repo.deleteShoppingItem(match.id!);
            deletedIds.add(match.id!);
            modifiedCount++;
          }
        }
      }
    }

    if (mounted) {
      Navigator.pop(context);
      final message = modifiedCount > 0
          ? 'Stock mis à jour : $modifiedCount ingrédient(s) modifié(s).'
          : 'Recette marquée comme faite (aucun ingrédient correspondant trouvé dans la liste).';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          action: modifiedCount > 0
              ? SnackBarAction(
                  label: 'ANNULER',
                  onPressed: () async {
                    // Restore deleted and updated items
                    for (var backup in backupItems) {
                      if (deletedIds.contains(backup['id'])) {
                        // Re-insert deleted item
                        await repo.addShoppingItem(
                          backup['name'] as String,
                          quantity: backup['quantity'] as String?,
                        );
                      } else {
                        // Restore updated item's quantity
                        final item = ShoppingItem(
                          id: backup['id'] as int,
                          name: backup['name'] as String,
                          quantity: backup['quantity'] as String?,
                          isBought: backup['is_bought'] as bool,
                          userId: '',
                        );
                        await repo.updateShoppingItem(item,
                            quantity: backup['quantity'] as String?);
                      }
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Modifications annulées.'),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                )
              : null,
        ),
      );
    }
  }

  double? _parseQuantity(String qtyStr) {
    if (qtyStr.isEmpty) return null;
    // Extract number
    final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(qtyStr);
    if (match != null) {
      return double.tryParse(match.group(1)!.replaceAll(',', '.'));
    }
    return null;
  }
}
