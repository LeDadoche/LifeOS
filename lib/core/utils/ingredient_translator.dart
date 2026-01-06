/// Traducteur d'ingrédients anglais -> français
/// Utilisé pour matcher les ingrédients Spoonacular avec la liste locale
class IngredientTranslator {
  /// Familles d'ingrédients (alias/synonymes)
  /// Si un ingrédient appartient à un groupe, tous les membres sont interchangeables
  static const Map<String, List<String>> ingredientFamilies = {
    'fromage_rape': [
      'gruyère',
      'gruyere',
      'emmental',
      'comté',
      'comte',
      'fromage râpé',
      'fromage rape',
      'grana padano',
      'parmesan',
      'grated cheese',
      'shredded cheese',
      'mozzarella râpée',
      'cheddar râpé',
    ],
    'huile': [
      'huile',
      'huile d\'olive',
      'huile olive',
      'huile de tournesol',
      'huile végétale',
      'huile vegetale',
      'oil',
      'olive oil',
      'vegetable oil',
      'cooking oil',
      'canola oil',
    ],
    'oeufs': [
      'oeuf',
      'oeufs',
      'egg',
      'eggs',
      'œuf',
      'œufs',
    ],
    'lait': [
      'lait',
      'milk',
      'lait entier',
      'lait demi-écrémé',
      'lait écrémé',
      'whole milk',
      'skim milk',
    ],
    'creme': [
      'crème',
      'creme',
      'crème fraîche',
      'creme fraiche',
      'crème liquide',
      'cream',
      'heavy cream',
      'sour cream',
      'crème épaisse',
    ],
    'beurre': [
      'beurre',
      'butter',
      'beurre doux',
      'beurre salé',
      'margarine',
    ],
    'poulet': [
      'poulet',
      'chicken',
      'blanc de poulet',
      'cuisse de poulet',
      'filet de poulet',
      'chicken breast',
      'chicken thigh',
    ],
    'boeuf': [
      'boeuf',
      'bœuf',
      'beef',
      'steak',
      'boeuf haché',
      'viande hachée',
      'ground beef',
      'steak haché',
    ],
    'tomate': [
      'tomate',
      'tomates',
      'tomato',
      'tomatoes',
      'tomates cerises',
      'cherry tomatoes',
      'tomates concassées',
    ],
    'oignon': [
      'oignon',
      'oignons',
      'onion',
      'onions',
      'échalote',
      'shallot',
      'oignon rouge',
      'red onion',
      'oignon jaune',
    ],
    'ail': [
      'ail',
      'garlic',
      'gousse d\'ail',
      'gousses d\'ail',
      'garlic clove',
    ],
    'pomme_de_terre': [
      'pomme de terre',
      'pommes de terre',
      'patate',
      'patates',
      'potato',
      'potatoes',
      'pdt',
    ],
    'carotte': [
      'carotte',
      'carottes',
      'carrot',
      'carrots',
    ],
    'farine': [
      'farine',
      'flour',
      'farine de blé',
      'wheat flour',
      'all-purpose flour',
    ],
    'sucre': [
      'sucre',
      'sugar',
      'sucre en poudre',
      'sucre roux',
      'brown sugar',
      'powdered sugar',
      'sucre glace',
    ],
    'sel': [
      'sel',
      'salt',
      'sel fin',
      'gros sel',
      'sea salt',
      'fleur de sel',
    ],
    'poivre': [
      'poivre',
      'pepper',
      'black pepper',
      'poivre noir',
      'poivre moulu',
    ],
    'pates': [
      'pâtes',
      'pates',
      'pasta',
      'spaghetti',
      'tagliatelles',
      'penne',
      'fusilli',
      'macaroni',
      'noodles',
      'nouilles',
    ],
    'riz': [
      'riz',
      'rice',
      'riz basmati',
      'riz long',
      'riz complet',
    ],
    'fromage': [
      'fromage',
      'cheese',
      'fromage blanc',
      'cottage cheese',
    ],
  };

  /// Les 150+ ingrédients les plus communs
  static const Map<String, String> englishToFrench = {
    // Produits laitiers & Oeufs
    'egg': 'oeuf',
    'eggs': 'oeufs',
    'milk': 'lait',
    'butter': 'beurre',
    'cream': 'crème',
    'heavy cream': 'crème épaisse',
    'sour cream': 'crème aigre',
    'yogurt': 'yaourt',
    'cheese': 'fromage',
    'cheddar': 'cheddar',
    'mozzarella': 'mozzarella',
    'parmesan': 'parmesan',
    'cream cheese': 'fromage frais',
    'feta': 'feta',
    'goat cheese': 'chèvre',
    'ricotta': 'ricotta',
    'mascarpone': 'mascarpone',

    // Viandes
    'chicken': 'poulet',
    'chicken breast': 'blanc de poulet',
    'chicken thigh': 'cuisse de poulet',
    'beef': 'boeuf',
    'ground beef': 'boeuf haché',
    'steak': 'steak',
    'pork': 'porc',
    'pork chop': 'côte de porc',
    'bacon': 'bacon',
    'ham': 'jambon',
    'sausage': 'saucisse',
    'lamb': 'agneau',
    'veal': 'veau',
    'duck': 'canard',
    'turkey': 'dinde',
    'ground turkey': 'dinde hachée',
    'meatball': 'boulette de viande',
    'meat': 'viande',

    // Poissons & Fruits de mer
    'fish': 'poisson',
    'salmon': 'saumon',
    'tuna': 'thon',
    'cod': 'cabillaud',
    'shrimp': 'crevette',
    'prawn': 'crevette',
    'scallop': 'coquille saint-jacques',
    'mussel': 'moule',
    'clam': 'palourde',
    'lobster': 'homard',
    'crab': 'crabe',
    'squid': 'calamar',
    'anchovy': 'anchois',
    'sardine': 'sardine',
    'trout': 'truite',

    // Légumes
    'onion': 'oignon',
    'garlic': 'ail',
    'tomato': 'tomate',
    'potato': 'pomme de terre',
    'carrot': 'carotte',
    'celery': 'céleri',
    'bell pepper': 'poivron',
    'zucchini': 'courgette',
    'eggplant': 'aubergine',
    'cucumber': 'concombre',
    'lettuce': 'laitue',
    'spinach': 'épinard',
    'broccoli': 'brocoli',
    'cauliflower': 'chou-fleur',
    'cabbage': 'chou',
    'mushroom': 'champignon',
    'leek': 'poireau',
    'asparagus': 'asperge',
    'green bean': 'haricot vert',
    'pea': 'petit pois',
    'corn': 'maïs',
    'avocado': 'avocat',
    'artichoke': 'artichaut',
    'beet': 'betterave',
    'radish': 'radis',
    'turnip': 'navet',
    'squash': 'courge',
    'pumpkin': 'citrouille',
    'sweet potato': 'patate douce',
    'kale': 'chou frisé',
    'arugula': 'roquette',
    'shallot': 'échalote',
    'scallion': 'oignon vert',
    'green onion': 'oignon vert',
    'spring onion': 'oignon nouveau',

    // Fruits
    'apple': 'pomme',
    'banana': 'banane',
    'orange': 'orange',
    'lemon': 'citron',
    'lime': 'citron vert',
    'strawberry': 'fraise',
    'raspberry': 'framboise',
    'blueberry': 'myrtille',
    'grape': 'raisin',
    'peach': 'pêche',
    'pear': 'poire',
    'cherry': 'cerise',
    'mango': 'mangue',
    'pineapple': 'ananas',
    'watermelon': 'pastèque',
    'melon': 'melon',
    'kiwi': 'kiwi',
    'fig': 'figue',
    'plum': 'prune',
    'apricot': 'abricot',
    'coconut': 'noix de coco',
    'pomegranate': 'grenade',
    'cranberry': 'canneberge',
    'raisin': 'raisin sec',

    // Céréales & Féculents
    'flour': 'farine',
    'bread': 'pain',
    'rice': 'riz',
    'pasta': 'pâtes',
    'noodle': 'nouilles',
    'spaghetti': 'spaghetti',
    'macaroni': 'macaroni',
    'oat': 'avoine',
    'oatmeal': 'flocons d\'avoine',
    'quinoa': 'quinoa',
    'couscous': 'couscous',
    'breadcrumb': 'chapelure',
    'crouton': 'croûton',
    'tortilla': 'tortilla',
    'pita': 'pita',
    'baguette': 'baguette',
    'croissant': 'croissant',

    // Légumineuses & Noix
    'bean': 'haricot',
    'black bean': 'haricot noir',
    'kidney bean': 'haricot rouge',
    'chickpea': 'pois chiche',
    'lentil': 'lentille',
    'almond': 'amande',
    'walnut': 'noix',
    'peanut': 'cacahuète',
    'cashew': 'noix de cajou',
    'pistachio': 'pistache',
    'hazelnut': 'noisette',
    'pecan': 'noix de pécan',
    'pine nut': 'pignon de pin',
    'chestnut': 'châtaigne',
    'sesame': 'sésame',
    'sunflower seed': 'graine de tournesol',
    'chia seed': 'graine de chia',
    'flaxseed': 'graine de lin',

    // Herbes & Épices
    'salt': 'sel',
    'pepper': 'poivre',
    'black pepper': 'poivre noir',
    'paprika': 'paprika',
    'cumin': 'cumin',
    'cinnamon': 'cannelle',
    'ginger': 'gingembre',
    'turmeric': 'curcuma',
    'oregano': 'origan',
    'basil': 'basilic',
    'thyme': 'thym',
    'rosemary': 'romarin',
    'parsley': 'persil',
    'cilantro': 'coriandre',
    'coriander': 'coriandre',
    'mint': 'menthe',
    'dill': 'aneth',
    'bay leaf': 'laurier',
    'chive': 'ciboulette',
    'sage': 'sauge',
    'tarragon': 'estragon',
    'nutmeg': 'muscade',
    'clove': 'clou de girofle',
    'cardamom': 'cardamome',
    'fennel': 'fenouil',
    'curry': 'curry',
    'chili': 'piment',
    'cayenne': 'cayenne',
    'saffron': 'safran',
    'vanilla': 'vanille',

    // Huiles & Condiments
    'oil': 'huile',
    'olive oil': 'huile d\'olive',
    'vegetable oil': 'huile végétale',
    'coconut oil': 'huile de coco',
    'sesame oil': 'huile de sésame',
    'vinegar': 'vinaigre',
    'balsamic vinegar': 'vinaigre balsamique',
    'wine vinegar': 'vinaigre de vin',
    'mustard': 'moutarde',
    'mayonnaise': 'mayonnaise',
    'ketchup': 'ketchup',
    'soy sauce': 'sauce soja',
    'worcestershire sauce': 'sauce worcestershire',
    'hot sauce': 'sauce piquante',
    'honey': 'miel',
    'maple syrup': 'sirop d\'érable',
    'jam': 'confiture',
    'peanut butter': 'beurre de cacahuète',

    // Produits de base
    'sugar': 'sucre',
    'brown sugar': 'sucre roux',
    'powdered sugar': 'sucre glace',
    'baking powder': 'levure chimique',
    'baking soda': 'bicarbonate',
    'yeast': 'levure',
    'cornstarch': 'maïzena',
    'gelatin': 'gélatine',
    'cocoa': 'cacao',
    'chocolate': 'chocolat',
    'dark chocolate': 'chocolat noir',
    'white chocolate': 'chocolat blanc',
    'coffee': 'café',
    'tea': 'thé',

    // Boissons & Liquides
    'water': 'eau',
    'broth': 'bouillon',
    'chicken broth': 'bouillon de poulet',
    'beef broth': 'bouillon de boeuf',
    'vegetable broth': 'bouillon de légumes',
    'stock': 'fond',
    'wine': 'vin',
    'white wine': 'vin blanc',
    'red wine': 'vin rouge',
    'beer': 'bière',
    'juice': 'jus',
    'orange juice': 'jus d\'orange',
    'lemon juice': 'jus de citron',
    'lime juice': 'jus de citron vert',
    'apple cider': 'cidre de pomme',

    // Conserves & Produits transformés
    'tomato paste': 'concentré de tomate',
    'tomato sauce': 'sauce tomate',
    'canned tomato': 'tomate en conserve',
    'canned tuna': 'thon en boite',
    'canned corn': 'maïs en boite',
    'olives': 'olives',
    'capers': 'câpres',
    'pickle': 'cornichon',
    'sun-dried tomato': 'tomate séchée',

    // Tofu & Alternatives
    'tofu': 'tofu',
    'tempeh': 'tempeh',
    'seitan': 'seitan',
    'almond milk': 'lait d\'amande',
    'oat milk': 'lait d\'avoine',
    'soy milk': 'lait de soja',
    'coconut milk': 'lait de coco',
  };

  /// Articles de base généralement présents dans un placard
  static const List<String> basicPantryItems = [
    'sel',
    'poivre',
    'huile',
    'huile d\'olive',
    'huile végétale',
    'sucre',
    'vinaigre',
    'épices',
    'herbes',
    'ail',
    'oignon',
    'farine',
    'levure',
    'moutarde',
    'sauce soja',
    'bouillon',
    'maïzena',
    'bicarbonate',
    'levure chimique',
    'eau',
  ];

  /// Traduit un ingrédient anglais en français
  /// Retourne le texte original si aucune traduction n'est trouvée
  static String translate(String englishIngredient) {
    final lower = englishIngredient.toLowerCase().trim();

    // Cherche une correspondance exacte
    if (englishToFrench.containsKey(lower)) {
      return englishToFrench[lower]!;
    }

    // Cherche si le texte contient un ingrédient connu
    for (final entry in englishToFrench.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }

    return englishIngredient;
  }

  /// Mots-clés supplémentaires pour la traduction par segments
  static const Map<String, String> keywordTranslations = {
    // Adjectifs / Préparation
    'pre-made': 'prêt à l\'emploi',
    'premade': 'prêt à l\'emploi',
    'homemade': 'maison',
    'fresh': 'frais',
    'frozen': 'surgelé',
    'dried': 'séché',
    'canned': 'en conserve',
    'sliced': 'tranché',
    'chopped': 'haché',
    'diced': 'en dés',
    'minced': 'émincé',
    'ground': 'moulu',
    'grated': 'râpé',
    'shredded': 'effiloché',
    'crushed': 'écrasé',
    'melted': 'fondu',
    'softened': 'ramolli',
    'thawed': 'décongelé',
    'cooked': 'cuit',
    'raw': 'cru',
    'ripe': 'mûr',
    'unripe': 'pas mûr',
    'organic': 'bio',
    'unsalted': 'non salé',
    'salted': 'salé',
    'sweet': 'sucré',
    'hot': 'piquant',
    'mild': 'doux',
    'spicy': 'épicé',
    'smoked': 'fumé',
    'roasted': 'rôti',
    'toasted': 'grillé',
    'fried': 'frit',
    'baked': 'cuit au four',
    'boiled': 'bouilli',
    'steamed': 'vapeur',
    'grilled': 'grillé',
    'sautéed': 'sauté',
    'sauteed': 'sauté',
    'blanched': 'blanchi',
    'marinated': 'mariné',
    'stuffed': 'farci',
    'whipped': 'fouetté',
    'beaten': 'battu',
    'mixed': 'mélangé',
    'plain': 'nature',
    'whole': 'entier',
    'half': 'demi',
    'low-fat': 'allégé',
    'fat-free': 'sans matière grasse',
    'sugar-free': 'sans sucre',
    'gluten-free': 'sans gluten',
    'boneless': 'désossé',
    'skinless': 'sans peau',

    // Types de pâte
    'filo': 'pâte filo',
    'phyllo': 'pâte filo',
    'puff': 'feuilletée',
    'shortcrust': 'brisée',
    'pie': 'à tarte',
    'pizza': 'à pizza',
    'pastry': 'pâte',
    'dough': 'pâte',
    'crust': 'croûte',
    'shell': 'fond',
    'wrapper': 'feuille',

    // Contenants (pas les unités de mesure)
    'cups': 'coupelles',
    'mini cups': 'mini coupelles',

    // Fromages
    'swiss': 'suisse',
    'cheddar': 'cheddar',
    'mozzarella': 'mozzarella',
    'parmesan': 'parmesan',
    'feta': 'feta',
    'brie': 'brie',
    'camembert': 'camembert',
    'gouda': 'gouda',
    'blue': 'bleu',
    'ricotta': 'ricotta',
    'mascarpone': 'mascarpone',
    'cottage': 'cottage',
    'cream cheese': 'fromage frais',
    'goat': 'chèvre',

    // Couleurs
    'white': 'blanc',
    'black': 'noir',
    'red': 'rouge',
    'green': 'vert',
    'yellow': 'jaune',
    'brown': 'brun',
    'golden': 'doré',

    // Autres ingrédients courants
    'sauce': 'sauce',
    'stock': 'bouillon',
    'broth': 'bouillon',
    'juice': 'jus',
    'zest': 'zeste',
    'peel': 'écorce',
    'skin': 'peau',
    'seed': 'graine',
    'seeds': 'graines',
    'nut': 'noix',
    'nuts': 'noix',
    'leaf': 'feuille',
    'leaves': 'feuilles',
    'stem': 'tige',
    'root': 'racine',
    'clove': 'gousse',
    'cloves': 'gousses',
    'wedge': 'quartier',
    'wedges': 'quartiers',
    'chunk': 'morceau',
    'chunks': 'morceaux',
    'cube': 'cube',
    'cubes': 'cubes',
    'strip': 'lamelle',
    'strips': 'lamelles',
    'ring': 'rondelle',
    'rings': 'rondelles',
    'powder': 'poudre',
    'flakes': 'flocons',
    'extract': 'extrait',
    'essence': 'essence',
    'filling': 'garniture',
    'topping': 'nappage',
    'glaze': 'glaçage',
    'coating': 'enrobage',
    'mix': 'mélange',
    'blend': 'mélange',
    'spread': 'tartinable',
  };

  /// Traduit un nom d'ingrédient mot par mot
  /// Retourne un nom français cohérent
  static String translateFullName(String englishName) {
    // 1. Retirer les parenthèses et leur contenu
    String cleaned = englishName.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' '); // Normaliser espaces

    // 2. Vérifier traduction exacte d'abord
    final exactMatch = translate(cleaned);
    if (exactMatch != cleaned) {
      return exactMatch;
    }

    // 3. Découper en mots et traduire chaque segment
    final words = cleaned.toLowerCase().split(RegExp(r'[\s\-]+'));
    final translatedWords = <String>[];
    final processedIndices = <int>{};

    // Chercher les correspondances multi-mots d'abord
    for (int i = 0; i < words.length; i++) {
      if (processedIndices.contains(i)) continue;

      bool found = false;

      // Essayer des combinaisons de 3, 2, puis 1 mot
      for (int len = 3; len >= 1 && !found; len--) {
        if (i + len > words.length) continue;

        final phrase = words.sublist(i, i + len).join(' ');

        // Chercher dans englishToFrench
        if (englishToFrench.containsKey(phrase)) {
          translatedWords.add(englishToFrench[phrase]!);
          for (int j = i; j < i + len; j++) {
            processedIndices.add(j);
          }
          found = true;
        }
        // Chercher dans keywordTranslations
        else if (keywordTranslations.containsKey(phrase)) {
          translatedWords.add(keywordTranslations[phrase]!);
          for (int j = i; j < i + len; j++) {
            processedIndices.add(j);
          }
          found = true;
        }
      }

      // Si aucune correspondance, vérifier mot seul
      if (!found) {
        final word = words[i];
        if (englishToFrench.containsKey(word)) {
          translatedWords.add(englishToFrench[word]!);
        } else if (keywordTranslations.containsKey(word)) {
          translatedWords.add(keywordTranslations[word]!);
        } else {
          // Garder le mot original si pas de traduction
          translatedWords.add(word);
        }
        processedIndices.add(i);
      }
    }

    // 4. Reconstruire le nom
    return translatedWords.join(' ');
  }

  /// Vérifie si un ingrédient (en français) est un article de base du placard
  static bool isPantryItem(String frenchIngredient) {
    final lower = frenchIngredient.toLowerCase().trim();

    for (final pantry in basicPantryItems) {
      if (lower.contains(pantry) || pantry.contains(lower)) {
        return true;
      }
    }
    return false;
  }

  /// Normalise un texte pour la comparaison
  static String normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[éèêëœ]'), 'e')
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim();
  }

  /// Retire le 's' final pour gérer le pluriel
  static String singularize(String text) {
    final trimmed = text.trim();
    if (trimmed.endsWith('s') && trimmed.length > 3) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  /// Trouve le groupe d'alias auquel appartient un ingrédient
  static String? findFamilyKey(String ingredient) {
    final normalized = normalize(ingredient);
    final singular = singularize(normalized);

    for (final entry in ingredientFamilies.entries) {
      for (final alias in entry.value) {
        final normalizedAlias = normalize(alias);
        final singularAlias = singularize(normalizedAlias);

        // Correspondance exacte ou partielle
        if (normalized == normalizedAlias ||
            singular == singularAlias ||
            normalized.contains(normalizedAlias) ||
            normalizedAlias.contains(normalized) ||
            singular.contains(singularAlias) ||
            singularAlias.contains(singular)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  /// Vérifie si deux ingrédients appartiennent à la même famille
  static bool areSameFamily(String ingredient1, String ingredient2) {
    // D'abord, traduire si en anglais
    final translated1 = translate(ingredient1);
    final translated2 = translate(ingredient2);

    // Normaliser
    final norm1 = normalize(translated1);
    final norm2 = normalize(translated2);
    final sing1 = singularize(norm1);
    final sing2 = singularize(norm2);

    // Match direct
    if (norm1 == norm2 || sing1 == sing2) return true;
    if (norm1.contains(norm2) || norm2.contains(norm1)) return true;
    if (sing1.contains(sing2) || sing2.contains(sing1)) return true;

    // Match par famille
    final family1 = findFamilyKey(translated1);
    final family2 = findFamilyKey(translated2);

    if (family1 != null && family2 != null && family1 == family2) {
      return true;
    }

    return false;
  }

  /// Matching intelligent d'ingrédients
  /// Combine traduction, normalisation, singularisation et familles
  static bool smartMatch(String recipeIngredient, String fridgeItem) {
    return areSameFamily(recipeIngredient, fridgeItem);
  }
}
