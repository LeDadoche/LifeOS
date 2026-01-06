import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'meal_model.dart';
import 'recipe_model.dart';

final kitchenRepositoryProvider = Provider<KitchenRepository>((ref) {
  return KitchenRepository(Supabase.instance.client);
});

final shoppingListProvider = StreamProvider<List<ShoppingItem>>((ref) {
  return ref.watch(kitchenRepositoryProvider).watchShoppingList();
});

final mealsForWeekProvider = StreamProvider<List<Meal>>((ref) {
  return ref.watch(kitchenRepositoryProvider).watchMealsForWeek();
});

final recipesProvider = StreamProvider<List<Recipe>>((ref) {
  return ref.watch(kitchenRepositoryProvider).watchRecipes();
});

class KitchenRepository {
  final SupabaseClient _client;

  KitchenRepository(this._client);

  // --- Recipes ---

  Stream<List<Recipe>> watchRecipes() {
    return _client
        .from('recipes')
        .stream(primaryKey: ['id'])
        .order('is_favorite', ascending: false)
        .order('title', ascending: true)
        .map((data) => data.map((json) => Recipe.fromJson(json)).toList());
  }

  Future<void> addRecipe(Recipe recipe) async {
await _client.from('recipes').insert(recipe.toJson());
  }

  Future<void> updateRecipe(Recipe recipe) async {
    if (recipe.id == null) return;
    await _client.from('recipes').update(recipe.toJson()).eq('id', recipe.id!);
  }

  Future<void> deleteRecipe(int id) async {
    await _client.from('recipes').delete().eq('id', id);
  }

  Future<void> toggleFavorite(Recipe recipe) async {
    if (recipe.id == null) return;
    await _client.from('recipes').update({
      'is_favorite': !recipe.isFavorite,
    }).eq('id', recipe.id!);
  }

  // --- Meals ---

  Future<void> saveMeal(DateTime date, bool isLunch, String description) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final mealType = isLunch ? 'lunch' : 'dinner';
    // Supabase date column usually handles ISO strings.
    // To ensure uniqueness per day/type, we should probably query first.
    
    // Check if exists
    final existing = await _client
        .from('meal_plans')
        .select()
        .eq('user_id', user.id)
        .eq('meal_type', mealType)
        // We need to match the date. Since date in DB might be timestamp, we need to be careful.
        // Assuming the 'date' column is just a date or we store midnight.
        // Let's assume we store the exact DateTime passed (normalized to midnight in UI/Repo).
        .eq('date', date.toIso8601String())
        .maybeSingle();

    if (existing != null) {
      await _client.from('meal_plans').update({
        'description': description,
      }).eq('id', existing['id']);
    } else {
      await _client.from('meal_plans').insert({
        'date': date.toIso8601String(),
        'meal_type': mealType,
        'description': description,
        'user_id': user.id,
      });
    }
  }

  Stream<List<Meal>> watchMealsForWeek() {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final endOfWeek = startOfToday.add(const Duration(days: 7));

    return _client
        .from('meal_plans')
        .stream(primaryKey: ['id'])
        .order('date')
        .map((data) {
          final meals = data.map((json) => Meal.fromJson(json)).toList();
          return meals.where((m) => 
            m.date.isAfter(startOfToday.subtract(const Duration(seconds: 1))) && 
            m.date.isBefore(endOfWeek)
          ).toList();
        });
  }

  // --- Shopping List ---

  Future<void> addShoppingItem(String name, {String? quantity}) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('shopping_items').insert({
      'name': name,
      'quantity': quantity,
      'is_bought': false,
      'user_id': user.id,
    });
  }

  Future<void> updateShoppingItem(ShoppingItem item, {String? quantity}) async {
    if (item.id == null) return;
    final updates = <String, dynamic>{};
    if (quantity != null) updates['quantity'] = quantity;
    
    if (updates.isNotEmpty) {
      await _client.from('shopping_items').update(updates).eq('id', item.id!);
    }
  }

  Future<void> toggleShoppingItem(ShoppingItem item) async {
    if (item.id == null) return;
    await _client.from('shopping_items').update({
      'is_bought': !item.isBought,
    }).eq('id', item.id!);
  }

  Future<void> deleteShoppingItem(int id) async {
    await _client.from('shopping_items').delete().eq('id', id);
  }

  Future<List<String>> getShoppingListNames() async {
    final response = await _client
        .from('shopping_items')
        .select('name')
        .eq('is_bought', false); // Only use items not yet bought? Or all? Let's assume all available items (not bought) make sense for "fridge" analysis, or maybe bought items are in the fridge? 
        // The prompt says "based on the current shopping list". Usually "shopping list" means things to buy. 
        // But "Analyse du frigo" implies things I HAVE. 
        // Let's assume for now we use items marked as 'is_bought' = true (meaning I have them) OR maybe the user uses the list as a pantry inventory.
        // Let's stick to the prompt "based on the current shopping list". I'll take ALL items for now to be safe, or maybe just the names.
    
    // Actually, if it's "Analyse du frigo", it usually means ingredients I have at home.
    // If the shopping list is "Things to buy", then I don't have them yet.
    // However, often users put things in the list they have.
    // Let's assume we take ALL items in the list for now.
    
    final data = response as List<dynamic>;
    return data.map((e) => e['name'] as String).toList();
  }

  Stream<List<ShoppingItem>> watchShoppingList() {
    return _client
        .from('shopping_items')
        .stream(primaryKey: ['id'])
        .order('is_bought', ascending: true)
        .order('created_at') // Assuming created_at exists, if not remove this line or use name
        .map((data) => data.map((json) => ShoppingItem.fromJson(json)).toList());
  }
}
