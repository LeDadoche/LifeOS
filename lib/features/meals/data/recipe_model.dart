class Recipe {
  final int? id;
  final String title;
  final String? sourceUrl;
  final String? imageUrl;
  final bool isFavorite;
  final String userId;
  final DateTime? createdAt;
  final List<Map<String, dynamic>>? ingredientsList;

  Recipe({
    this.id,
    required this.title,
    this.sourceUrl,
    this.imageUrl,
    this.isFavorite = false,
    required this.userId,
    this.createdAt,
    this.ingredientsList,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: (json['id'] as num?)?.toInt(),
      title: json['title'] as String,
      sourceUrl: json['source_url'] as String?,
      imageUrl: json['image_url'] as String?,
      isFavorite: json['is_favorite'] as bool? ?? false,
      userId: json['user_id'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      ingredientsList: json['ingredients_list'] != null
          ? List<Map<String, dynamic>>.from(json['ingredients_list'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'source_url': sourceUrl,
      'image_url': imageUrl,
      'is_favorite': isFavorite,
      'user_id': userId,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (ingredientsList != null) 'ingredients_list': ingredientsList,
    };
  }

  Recipe copyWith({
    int? id,
    String? title,
    String? sourceUrl,
    String? imageUrl,
    bool? isFavorite,
    String? userId,
    DateTime? createdAt,
    List<Map<String, dynamic>>? ingredientsList,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      isFavorite: isFavorite ?? this.isFavorite,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      ingredientsList: ingredientsList ?? this.ingredientsList,
    );
  }
}
