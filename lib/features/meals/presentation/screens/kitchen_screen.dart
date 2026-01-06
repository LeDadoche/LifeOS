import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../data/kitchen_repository.dart';
import '../../data/recipe_model.dart';
import '../../data/meal_model.dart';
import '../../../../core/services/spoonacular_service.dart';
import '../../../../core/services/ocr_service.dart';
import '../../../../core/utils/ingredient_translator.dart';
import '../../../../core/utils/culinary_formatter.dart';
import '../widgets/recipe_detail_sheet.dart';

/// Non-food product keywords for icon differentiation
const _nonFoodKeywords = {
  'papier toilette',
  'gel douche',
  'liquide vaisselle',
  'sac poubelle',
  'papier cuisson',
  'papier alu',
  'brosse à dents',
  'mousse à raser',
  'lave-vaisselle',
  'après-shampoing',
  'savon',
  'shampooing',
  'shampoing',
  'déodorant',
  'dentifrice',
  'brosse',
  'mouchoir',
  'coton',
  'couche',
  'serviette',
  'tampon',
  'rasoir',
  'soin',
  'maquillage',
  'parfum',
  'lessive',
  'adoucissant',
  'assouplissant',
  'nettoyant',
  'dégraissant',
  'javel',
  'vitre',
  'éponge',
  'sac',
  'alu',
  'film',
  'pile',
  'ampoule',
};

bool _isNonFood(String itemName) {
  final lower = itemName.toLowerCase();
  for (final keyword in _nonFoodKeywords) {
    if (lower.contains(keyword)) return true;
  }
  return false;
}

class KitchenScreen extends ConsumerWidget {
  const KitchenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cuisine'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Mon Frigo'),
              Tab(text: 'Mes Recettes'),
              Tab(text: 'Planning'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ShoppingListTab(),
            RecipesTab(),
            MealPlanningTab(),
          ],
        ),
      ),
    );
  }
}

class ShoppingListTab extends ConsumerStatefulWidget {
  const ShoppingListTab({super.key});

  @override
  ConsumerState<ShoppingListTab> createState() => _ShoppingListTabState();
}

class _ShoppingListTabState extends ConsumerState<ShoppingListTab> {
  final _controller = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _parseAndAddItem(String text) {
    if (text.isEmpty) return;

    String name = text;
    String? quantity;

    // Regex to find quantity at the start (e.g., "2kg ", "3 ", "1.5L ")
    final regex = RegExp(r'^(\d+(?:[.,]\d+)?\s*[a-zA-Z]*)\s+(.*)$');
    final match = regex.firstMatch(text);

    if (match != null) {
      quantity = match.group(1)?.trim();
      name = match.group(2)?.trim() ?? text;
    }

    ref
        .read(kitchenRepositoryProvider)
        .addShoppingItem(name, quantity: quantity);
  }

  void _addItem() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      _parseAndAddItem(text);
      _controller.clear();
    }
  }

  Future<void> _scanImage() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Import photo disponible uniquement sur mobile'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();

    if (pickedFiles.isNotEmpty) {
      final ocrService = OcrService();
      final List<Map<String, dynamic>> candidates = [];
      final Set<String> addedNames = {};

      try {
        for (final file in pickedFiles) {
          final inputImage = InputImage.fromFilePath(file.path);
          final results = await ocrService.processImage(inputImage);

          for (final result in results) {
            if (!addedNames.contains(result.name)) {
              candidates.add({
                'name': result.name,
                'quantity': result.quantity,
              });
              addedNames.add(result.name);
            }
          }
        }

        if (!mounted) return;
        _showCandidatesDialog(candidates);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de l\'analyse: $e'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } finally {
        ocrService.dispose();
      }
    }
  }

  void _showCandidatesDialog(List<Map<String, dynamic>> candidates) {
    // We work with a local copy to allow removal
    final itemsToImport = List<Map<String, dynamic>>.from(candidates);

    if (itemsToImport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun produit connu détecté.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Résultats de l\'analyse',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text('${itemsToImport.length} produits identifiés',
                          style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          children: [
                            const Text(
                                'Appuyez pour éditer, Croix pour supprimer :',
                                style: TextStyle(fontStyle: FontStyle.italic)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: itemsToImport.map((item) {
                                return InputChip(
                                  label: Text(
                                      '${item['name']}${item['quantity'] != null ? " (x${item['quantity']})" : ""}'),
                                  selected: false,
                                  onDeleted: () {
                                    setState(() {
                                      itemsToImport.remove(item);
                                    });
                                  },
                                  onPressed: () {
                                    _showEditItemDialog(context, item,
                                        (newName, newQty) {
                                      setState(() {
                                        item['name'] = newName;
                                        item['quantity'] = newQty;
                                      });
                                    });
                                  },
                                  deleteIcon: const Icon(Icons.close, size: 18),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: itemsToImport.isEmpty
                            ? null
                            : () {
                                int added = 0;
                                for (final item in itemsToImport) {
                                  ref
                                      .read(kitchenRepositoryProvider)
                                      .addShoppingItem(item['name'],
                                          quantity: item['quantity'] != null
                                              ? 'x${item['quantity']}'
                                              : null);
                                  added++;
                                }
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('$added articles importés !'),
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.check),
                        label: Text(
                            'Ajouter ces ${itemsToImport.length} articles à ma liste'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showEditItemDialog(BuildContext context, Map<String, dynamic> item,
      Function(String, String?) onSave) {
    final nameController = TextEditingController(text: item['name']);
    final qtyController = TextEditingController(text: item['quantity'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier l\'article'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nom du produit'),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: qtyController,
              decoration:
                  const InputDecoration(labelText: 'Quantité (ex: 2kg, x2)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                onSave(
                    nameController.text.trim(),
                    qtyController.text.trim().isEmpty
                        ? null
                        : qtyController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(shoppingListProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Add item row
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Ajouter (ex: 2kg Pommes)...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.add_shopping_cart),
                  ),
                  onSubmitted: (_) => _addItem(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                onPressed: _scanImage,
                icon: const Icon(Icons.camera_alt),
                tooltip: 'Importer depuis une image',
              ),
            ],
          ),
        ),
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher un article...',
              prefixIcon: const Icon(Icons.search),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value.toLowerCase());
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: itemsAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return const Center(
                  child: Text('Liste de courses vide 🎉'),
                );
              }

              // Filter by search query
              var filteredItems = items.where((item) {
                if (_searchQuery.isEmpty) return true;
                return item.name.toLowerCase().contains(_searchQuery);
              }).toList();

              if (filteredItems.isEmpty && _searchQuery.isNotEmpty) {
                return Center(
                  child: Text('Aucun article trouvé pour "$_searchQuery"'),
                );
              }

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: ListView.builder(
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      try {
                        final item = filteredItems[index];
                        final isNonFood = _isNonFood(item.name);
                        final isEven = index % 2 == 0;
                        return Container(
                          color: isEven
                              ? null
                              : colorScheme.surfaceContainerHighest
                                  .withOpacity(0.3),
                          child: ListTile(
                            leading: item.quantity != null &&
                                    item.quantity!.isNotEmpty
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      item.quantity!,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    isNonFood
                                        ? Icons.inventory_2_outlined
                                        : Icons.restaurant,
                                    color: isNonFood
                                        ? colorScheme.secondary
                                        : colorScheme.primary,
                                  ),
                            title: Text(item.name),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color: colorScheme.error),
                              tooltip: 'Supprimer',
                              onPressed: () => _confirmDeleteItem(item),
                            ),
                          ),
                        );
                      } catch (e) {
                        return const SizedBox.shrink();
                      }
                    },
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Erreur: $err')),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteItem(ShoppingItem item) async {
    // Save item and repository reference for potential undo
    final savedItem = item;
    final repo = ref.read(kitchenRepositoryProvider);

    // Delete immediately with await for PC compatibility
    await repo.deleteShoppingItem(item.id!);

    // Force UI refresh by invalidating the provider
    ref.invalidate(shoppingListProvider);

    // Show SnackBar with Undo
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${item.name}" supprimé'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'ANNULER',
            onPressed: () async {
              // Re-add the item using saved repo reference
              await repo.addShoppingItem(
                savedItem.name,
                quantity: savedItem.quantity,
              );
              ref.invalidate(shoppingListProvider);
            },
          ),
        ),
      );
    }
  }
}

class RecipesTab extends ConsumerWidget {
  const RecipesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(recipesProvider);

    return Scaffold(
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'magic_wand',
            onPressed: () => _showMagicRecipesDialog(context, ref),
            backgroundColor: Colors.purpleAccent,
            child: const Icon(Icons.auto_fix_high, color: Colors.white),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'add_recipe',
            onPressed: () => _showAddRecipeDialog(context, ref),
            child: const Icon(Icons.add),
          ),
        ],
      ),
      body: recipesAsync.when(
        data: (recipes) {
          if (recipes.isEmpty) {
            return const Center(child: Text('Aucune recette pour le moment.'));
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75, // Vertical card
                ),
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  final recipe = recipes[index];
                  return RecipeCard(recipe: recipe);
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erreur: $err')),
      ),
    );
  }

  void _showMagicRecipesDialog(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final ingredients =
          await ref.read(kitchenRepositoryProvider).getShoppingListNames();
      final service = SpoonacularService();
      final suggestions = await service.searchRecipesByIngredients(ingredients);

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading
        _showSuggestionsSheet(context, ref, suggestions);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showSuggestionsSheet(BuildContext context, WidgetRef ref,
      List<SpoonacularRecipe> suggestions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SuggestionsSheetContent(
        suggestions: suggestions,
        ref: ref,
        onAddRecipe: (suggestion) =>
            _addSuggestionToRecipes(context, ref, suggestion),
      ),
    );
  }

  Future<void> _addSuggestionToRecipes(
      BuildContext context, WidgetRef ref, SpoonacularRecipe suggestion) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final service = SpoonacularService();
      final details = await service.getRecipeDetails(suggestion.id);

      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close loading spinner

      String finalUrl = details?['sourceUrl'] as String? ?? '';
      if (finalUrl.isEmpty) {
        final slug = suggestion.title.replaceAll(' ', '-');
        finalUrl = 'https://spoonacular.com/recipes/$slug-${suggestion.id}';
      }

      List<Map<String, dynamic>>? ingredientsList;
      if (details != null && details['extendedIngredients'] != null) {
        // Normalize to metric measures
        final rawIngredients =
            List<Map<String, dynamic>>.from(details['extendedIngredients']);
        ingredientsList = rawIngredients.map((ing) {
          final metricMeasures = CulinaryFormatter.extractMetricMeasures(ing);
          return {
            'name': ing['name'] as String? ?? '',
            'amount': metricMeasures['amount'],
            'unit': metricMeasures['unit'],
            'measures': ing['measures'], // Keep original for reference
          };
        }).toList();
      }

      final recipe = Recipe(
        title: suggestion.title,
        imageUrl: suggestion.image,
        sourceUrl: finalUrl,
        userId: Supabase.instance.client.auth.currentUser?.id ?? '',
        ingredientsList: ingredientsList,
      );
      await ref.read(kitchenRepositoryProvider).addRecipe(recipe);

      if (context.mounted) {
        Navigator.of(context).pop(); // Close suggestions sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recette "${suggestion.title}" ajoutee !'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading spinner
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur: Impossible de recuperer la recette.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showAddRecipeDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    bool isFavorite = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nouvelle Recette'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Titre'),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(labelText: 'URL (optionnel)'),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Favori'),
                value: isFavorite,
                onChanged: (val) => setState(() => isFavorite = val ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  final recipe = Recipe(
                    title: titleController.text,
                    sourceUrl: urlController.text.isNotEmpty
                        ? urlController.text
                        : null,
                    isFavorite: isFavorite,
                    userId: Supabase.instance.client.auth.currentUser?.id ?? '',
                  );
                  ref.read(kitchenRepositoryProvider).addRecipe(recipe);
                  context.pop();
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }
}

class RecipeCard extends ConsumerWidget {
  final Recipe recipe;

  const RecipeCard({super.key, required this.recipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => RecipeDetailSheet(recipe: recipe),
        );
      },
      onLongPressStart: (details) =>
          _showContextMenu(context, ref, details.globalPosition),
      onSecondaryTapDown: (details) =>
          _showContextMenu(context, ref, details.globalPosition),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Area
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImage(context),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          recipe.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: recipe.isFavorite
                              ? Colors.redAccent
                              : Colors.white,
                          size: 20,
                        ),
                        onPressed: () {
                          ref
                              .read(kitchenRepositoryProvider)
                              .toggleFavorite(recipe);
                        },
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Details Area
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      recipe.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (recipe.sourceUrl != null &&
                        recipe.sourceUrl!.isNotEmpty)
                      const Row(
                        children: [
                          Spacer(),
                          Icon(Icons.link, size: 16, color: Colors.blue),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    if (recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty) {
      return Image.network(
        recipe.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildPlaceholder(context),
      );
    } else if (recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty) {
      final uri = Uri.tryParse(recipe.sourceUrl!);
      if (uri != null && uri.host.isNotEmpty) {
        final faviconUrl =
            'https://www.google.com/s2/favicons?domain=${uri.host}&sz=128';
        return Center(
          child: Image.network(
            faviconUrl,
            fit: BoxFit.contain,
            width: 64,
            height: 64,
            errorBuilder: (context, error, stackTrace) =>
                _buildPlaceholder(context),
          ),
        );
      }
    }
    return _buildPlaceholder(context);
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Center(
        child: Icon(
          Icons.restaurant_menu,
          size: 48,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  void _showContextMenu(
      BuildContext context, WidgetRef ref, Offset globalPosition) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        overlay.size.width - globalPosition.dx,
        overlay.size.height - globalPosition.dy,
      ),
      items: [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 20),
              SizedBox(width: 8),
              Text('Modifier')
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 20, color: Colors.red),
              SizedBox(width: 8),
              Text('Supprimer', style: TextStyle(color: Colors.red))
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'edit') {
        showDialog(
          context: context,
          builder: (context) => EditRecipeDialog(recipe: recipe),
        );
      } else if (value == 'delete') {
        _confirmDelete(context, ref);
      }
    });
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la recette ?'),
        content: Text('Voulez-vous vraiment supprimer "${recipe.title}" ?'),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              if (recipe.id != null) {
                ref.read(kitchenRepositoryProvider).deleteRecipe(recipe.id!);
              }
              context.pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

class EditRecipeDialog extends ConsumerStatefulWidget {
  final Recipe recipe;

  const EditRecipeDialog({super.key, required this.recipe});

  @override
  ConsumerState<EditRecipeDialog> createState() => _EditRecipeDialogState();
}

class _EditRecipeDialogState extends ConsumerState<EditRecipeDialog> {
  late TextEditingController _titleController;
  late TextEditingController _urlController;
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.recipe.title);
    _urlController = TextEditingController(text: widget.recipe.sourceUrl);
    _isFavorite = widget.recipe.isFavorite;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier la recette'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Titre'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(labelText: 'URL Source'),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Favori'),
              value: _isFavorite,
              onChanged: (val) => setState(() => _isFavorite = val ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            if (_titleController.text.isNotEmpty) {
              final updatedRecipe = widget.recipe.copyWith(
                title: _titleController.text,
                sourceUrl:
                    _urlController.text.isNotEmpty ? _urlController.text : null,
                imageUrl: null, // Clear manual image URL to rely on Favicon
                isFavorite: _isFavorite,
              );
              ref.read(kitchenRepositoryProvider).updateRecipe(updatedRecipe);
              context.pop();
            }
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

/// Widget pour afficher les suggestions avec tri, filtrage et gestion des condiments
class _SuggestionsSheetContent extends StatefulWidget {
  final List<SpoonacularRecipe> suggestions;
  final WidgetRef ref;
  final Function(SpoonacularRecipe) onAddRecipe;

  const _SuggestionsSheetContent({
    required this.suggestions,
    required this.ref,
    required this.onAddRecipe,
  });

  @override
  State<_SuggestionsSheetContent> createState() =>
      _SuggestionsSheetContentState();
}

class _SuggestionsSheetContentState extends State<_SuggestionsSheetContent> {
  bool _hideMoreThan5Missing = false;
  late List<_ScoredRecipe> _scoredRecipes;

  @override
  void initState() {
    super.initState();
    _scoredRecipes = _calculateScores();
  }

  List<_ScoredRecipe> _calculateScores() {
    final scored = <_ScoredRecipe>[];

    for (final recipe in widget.suggestions) {
      int realMissing = 0;
      int pantryMissing = 0;

      // Analyser les ingrédients manquants
      for (final missed in recipe.missedIngredients) {
        final name = missed['name'] as String? ?? '';
        final translated = IngredientTranslator.translate(name);

        if (IngredientTranslator.isPantryItem(translated)) {
          pantryMissing++;
        } else {
          realMissing++;
        }
      }

      scored.add(_ScoredRecipe(
        recipe: recipe,
        realMissingCount: realMissing,
        pantryMissingCount: pantryMissing,
      ));
    }

    // Trier par nombre réel d'ingrédients manquants
    scored.sort((a, b) => a.realMissingCount.compareTo(b.realMissingCount));
    return scored;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Filtrer si nécessaire
    var displayedRecipes = _scoredRecipes;
    if (_hideMoreThan5Missing) {
      displayedRecipes =
          _scoredRecipes.where((r) => r.realMissingCount <= 5).toList();
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
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
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text('👨‍🍳', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Suggestions du Chef',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Stats and filter
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${displayedRecipes.length} recettes triées par faisabilité',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                    FilterChip(
                      label: const Text('≤ 5 manquants'),
                      selected: _hideMoreThan5Missing,
                      onSelected: (val) =>
                          setState(() => _hideMoreThan5Missing = val),
                    ),
                  ],
                ),
              ),
              // Legend
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('En stock',
                        style: TextStyle(
                            fontSize: 10, color: colorScheme.onSurfaceVariant)),
                    const SizedBox(width: 12),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('Condiment',
                        style: TextStyle(
                            fontSize: 10, color: colorScheme.onSurfaceVariant)),
                    const SizedBox(width: 12),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('Manquant',
                        style: TextStyle(
                            fontSize: 10, color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const Divider(height: 16),
              // Grid
              Expanded(
                child: displayedRecipes.isEmpty
                    ? const Center(
                        child:
                            Text('Aucune recette ne correspond aux critères.'))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount =
                              constraints.maxWidth > 600 ? 3 : 2;
                          return GridView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.65,
                            ),
                            itemCount: displayedRecipes.length,
                            itemBuilder: (context, index) {
                              final scored = displayedRecipes[index];
                              return _buildScoredCard(scored, colorScheme);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScoredCard(_ScoredRecipe scored, ColorScheme colorScheme) {
    final recipe = scored.recipe;
    final realMissing = scored.realMissingCount;
    final pantryMissing = scored.pantryMissingCount;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () => widget.onAddRecipe(recipe),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image - plus grande
            Expanded(
              flex: 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    recipe.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: colorScheme.primaryContainer,
                      child: Icon(Icons.restaurant,
                          size: 48, color: colorScheme.onPrimaryContainer),
                    ),
                  ),
                  // Badge en haut à droite
                  if (realMissing == 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle,
                                size: 14,
                                color: colorScheme.onTertiaryContainer),
                            const SizedBox(width: 4),
                            Text('Faisable!',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onTertiaryContainer)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // Badges
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (realMissing > 0)
                          _buildBadge(
                            'Manque $realMissing',
                            colorScheme.errorContainer,
                            colorScheme.onErrorContainer,
                          ),
                        if (pantryMissing > 0)
                          _buildBadge(
                            '$pantryMissing condiment${pantryMissing > 1 ? 's' : ''}',
                            colorScheme.secondaryContainer,
                            colorScheme.onSecondaryContainer,
                          ),
                        if (realMissing == 0 && pantryMissing == 0)
                          _buildBadge(
                            'Tout en stock!',
                            colorScheme.tertiaryContainer,
                            colorScheme.onTertiaryContainer,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 9, color: textColor, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// Modèle interne pour scorer une recette
class _ScoredRecipe {
  final SpoonacularRecipe recipe;
  final int realMissingCount;
  final int pantryMissingCount;

  _ScoredRecipe({
    required this.recipe,
    required this.realMissingCount,
    required this.pantryMissingCount,
  });
}

// ============================================================================
// MEAL PLANNING TAB - Semainier pour planifier les repas
// ============================================================================

class MealPlanningTab extends ConsumerWidget {
  const MealPlanningTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(mealsForWeekProvider);

    // Générer les 7 prochains jours
    final today = DateTime.now();
    final days = List.generate(7, (i) {
      final date = DateTime(today.year, today.month, today.day).add(Duration(days: i));
      return date;
    });

    return mealsAsync.when(
      data: (meals) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: days.length,
          itemBuilder: (context, index) {
            final date = days[index];
            final dayMeals = meals.where((m) => 
              m.date.year == date.year && 
              m.date.month == date.month && 
              m.date.day == date.day
            ).toList();

            final lunchMeal = dayMeals.where((m) => m.isLunch).firstOrNull;
            final dinnerMeal = dayMeals.where((m) => !m.isLunch).firstOrNull;

            return _DayPlanCard(
              date: date,
              isToday: index == 0,
              lunchDescription: lunchMeal?.description,
              dinnerDescription: dinnerMeal?.description,
              onAddLunch: () => _showMealPicker(context, ref, date, isLunch: true),
              onAddDinner: () => _showMealPicker(context, ref, date, isLunch: false),
              onCookLunch: lunchMeal != null 
                  ? () => _confirmCook(context, ref, lunchMeal.description)
                  : null,
              onCookDinner: dinnerMeal != null 
                  ? () => _confirmCook(context, ref, dinnerMeal.description)
                  : null,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Erreur: $err')),
    );
  }

  void _showMealPicker(BuildContext context, WidgetRef ref, DateTime date, {required bool isLunch}) {
    final recipes = ref.read(recipesProvider).valueOrNull ?? [];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _MealPickerSheet(
          date: date,
          isLunch: isLunch,
          recipes: recipes,
          scrollController: scrollController,
          onMealSelected: (description) {
            ref.read(kitchenRepositoryProvider).saveMeal(date, isLunch, description);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _confirmCook(BuildContext context, WidgetRef ref, String mealDescription) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cuisiner ce plat ?'),
        content: Text('Voulez-vous préparer "$mealDescription" ?\n\nLes ingrédients utilisés seront retirés de votre frigo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🍳 Bon appétit avec "$mealDescription" !'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
              // TODO: Implémenter la soustraction des ingrédients si la recette est liée
            },
            icon: const Icon(Icons.restaurant),
            label: const Text('Cuisiner'),
          ),
        ],
      ),
    );
  }
}

/// Carte représentant un jour avec ses deux créneaux repas
class _DayPlanCard extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final String? lunchDescription;
  final String? dinnerDescription;
  final VoidCallback onAddLunch;
  final VoidCallback onAddDinner;
  final VoidCallback? onCookLunch;
  final VoidCallback? onCookDinner;

  const _DayPlanCard({
    required this.date,
    required this.isToday,
    this.lunchDescription,
    this.dinnerDescription,
    required this.onAddLunch,
    required this.onAddDinner,
    this.onCookLunch,
    this.onCookDinner,
  });

  String _formatDayName(DateTime date) {
    const days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    return days[date.weekday - 1];
  }

  String _formatDate(DateTime date) {
    const months = ['jan.', 'fév.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
    return '${date.day} ${months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      elevation: isToday ? 4 : 1,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isToday 
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête du jour
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isToday ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isToday ? "Aujourd'hui" : _formatDayName(date),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isToday ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(date),
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Midi
            _MealSlot(
              icon: Icons.wb_sunny_outlined,
              label: 'Déjeuner',
              description: lunchDescription,
              onAdd: onAddLunch,
              onCook: onCookLunch,
              accentColor: Colors.orange,
            ),
            const SizedBox(height: 12),
            
            // Soir
            _MealSlot(
              icon: Icons.nightlight_outlined,
              label: 'Dîner',
              description: dinnerDescription,
              onAdd: onAddDinner,
              onCook: onCookDinner,
              accentColor: Colors.indigo,
            ),
          ],
        ),
      ),
    );
  }
}

/// Slot pour un repas (Midi ou Soir)
class _MealSlot extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? description;
  final VoidCallback onAdd;
  final VoidCallback? onCook;
  final Color accentColor;

  const _MealSlot({
    required this.icon,
    required this.label,
    this.description,
    required this.onAdd,
    this.onCook,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasDescription = description != null && description!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasDescription ? accentColor.withOpacity(0.3) : colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasDescription ? description! : 'Aucun repas prévu',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: hasDescription ? FontWeight.w600 : FontWeight.normal,
                    color: hasDescription ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                    fontStyle: hasDescription ? FontStyle.normal : FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (hasDescription && onCook != null)
            IconButton(
              icon: const Icon(Icons.restaurant_outlined),
              tooltip: 'Cuisiner',
              onPressed: onCook,
              color: accentColor,
            ),
          IconButton(
            icon: Icon(hasDescription ? Icons.edit : Icons.add_circle_outline),
            tooltip: hasDescription ? 'Modifier' : 'Ajouter un repas',
            onPressed: onAdd,
            color: hasDescription ? colorScheme.onSurfaceVariant : colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet pour choisir un repas
class _MealPickerSheet extends StatefulWidget {
  final DateTime date;
  final bool isLunch;
  final List<Recipe> recipes;
  final ScrollController scrollController;
  final void Function(String description) onMealSelected;

  const _MealPickerSheet({
    required this.date,
    required this.isLunch,
    required this.recipes,
    required this.scrollController,
    required this.onMealSelected,
  });

  @override
  State<_MealPickerSheet> createState() => _MealPickerSheetState();
}

class _MealPickerSheetState extends State<_MealPickerSheet> {
  final _customController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filteredRecipes = widget.recipes.where((r) => 
      r.title.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Titre
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              widget.isLunch ? '🌞 Choisir le déjeuner' : '🌙 Choisir le dîner',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Input pour repas personnalisé
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _customController,
              decoration: InputDecoration(
                hintText: 'Ou saisir un repas libre...',
                prefixIcon: const Icon(Icons.edit),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () {
                    if (_customController.text.trim().isNotEmpty) {
                      widget.onMealSelected(_customController.text.trim());
                    }
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  widget.onMealSelected(value.trim());
                }
              },
            ),
          ),
          const SizedBox(height: 12),

          // Barre de recherche dans les recettes
          if (widget.recipes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher dans mes recettes...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
            ),
          const SizedBox(height: 8),

          // Liste des recettes
          Expanded(
            child: widget.recipes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.menu_book_outlined, size: 64, color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune recette enregistrée',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ajoutez des recettes dans l\'onglet "Mes Recettes"',
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: widget.scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredRecipes.length,
                    itemBuilder: (context, index) {
                      final recipe = filteredRecipes[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: recipe.imageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    recipe.imageUrl!,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 50,
                                      height: 50,
                                      color: colorScheme.surfaceContainerHighest,
                                      child: const Icon(Icons.restaurant),
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.restaurant),
                                ),
                          title: Text(recipe.title),
                          trailing: recipe.isFavorite
                              ? Icon(Icons.favorite, color: Colors.red.shade300, size: 18)
                              : null,
                          onTap: () => widget.onMealSelected(recipe.title),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

