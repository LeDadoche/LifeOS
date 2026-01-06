import 'dart:convert';
import 'package:http/http.dart' as http;

class SpoonacularService {
  // TODO: Replace with your actual Spoonacular API Key
  static const String _apiKey = '8fe0a9165a254271bdd84d3b7de38a91';
  static const String _baseUrl = 'https://api.spoonacular.com/recipes';

  Future<List<SpoonacularRecipe>> searchRecipesByIngredients(
      List<String> ingredients) async {
    if (ingredients.isEmpty) return [];

    final ingredientsString = ingredients.join(',');
    // Added &language=fr (though findByIngredients might not fully support it, it's good practice)
    // Note: findByIngredients returns English titles usually.
    // To get French, we might need complex search, but let's try adding the param.
    // Actually, findByIngredients doesn't support language param officially in docs,
    // but complexSearch does. Let's stick to findByIngredients for now as it matches logic.
    // However, the user explicitly asked for "&language=fr".
    final uri = Uri.parse(
        '$_baseUrl/findByIngredients?apiKey=$_apiKey&ingredients=$ingredientsString&number=21&ranking=1&language=fr&instructionsRequired=true');

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => SpoonacularRecipe.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load recipes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching recipes: $e');
    }
  }

  Future<Map<String, dynamic>?> getRecipeDetails(int id) async {
    // Added &language=fr to get instructions and ingredients in French if available
    final uri = Uri.parse(
        '$_baseUrl/$id/information?apiKey=$_apiKey&includeNutrition=false&language=fr');
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // Ignore error or log it
    }
    return null;
  }

  Future<String?> getRecipeUrl(int id) async {
    final details = await getRecipeDetails(id);
    return details?['sourceUrl'] as String?;
  }
}

class SpoonacularRecipe {
  final int id;
  final String title;
  final String image;
  final int usedIngredientCount;
  final int missedIngredientCount;
  final List<Map<String, dynamic>> missedIngredients;
  final List<Map<String, dynamic>> usedIngredients;

  SpoonacularRecipe({
    required this.id,
    required this.title,
    required this.image,
    required this.usedIngredientCount,
    required this.missedIngredientCount,
    required this.missedIngredients,
    required this.usedIngredients,
  });

  factory SpoonacularRecipe.fromJson(Map<String, dynamic> json) {
    return SpoonacularRecipe(
      id: json['id'] as int,
      title: json['title'] as String,
      image: json['image'] as String,
      usedIngredientCount: json['usedIngredientCount'] as int,
      missedIngredientCount: json['missedIngredientCount'] as int,
      missedIngredients: (json['missedIngredients'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      usedIngredients: (json['usedIngredients'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }
}
