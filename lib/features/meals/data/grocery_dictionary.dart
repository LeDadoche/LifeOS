class GroceryDictionary {
  static const List<String> products = [
    // Long names first (Priority)
    'pomme de terre', 'petit pois', 'haricot vert', 'haricot rouge', 'chou fleur', 'chou rouge', 'chou vert',
    'papier toilette', 'gel douche', 'liquide vaisselle', 'sac poubelle', 'papier cuisson', 'papier alu',
    'pâte à tartiner', 'huile d\'olive', 'huile de tournesol', 'vinaigre balsamique', 'vinaigre blanc',
    'crème fraiche', 'crème liquide', 'fromage blanc', 'yaourt nature', 'yaourt aux fruits',
    'jambon blanc', 'jambon cru', 'blanc de poulet', 'filet de poulet', 'escalope de dinde',
    'viande hachée', 'steak haché', 'saumon fumé', 'truite fumée', 'thon en boite',
    'jus d\'orange', 'jus de pomme', 'eau gazeuse', 'eau plate', 'coca cola', 'pois chiche',
    'brosse à dents', 'mousse à raser', 'lave-vaisselle', 'après-shampoing',

    // Short names
    'pomme', 'banane', 'orange', 'citron', 'clémentine', 'mandarine', 'poire', 'raisin', 'fraise', 'framboise',
    'tomate', 'carotte', 'oignon', 'ail', 'échalote', 'courgette', 'aubergine', 'poivron',
    'concombre', 'salade', 'laitue', 'mâche', 'roquette', 'épinard', 'haricot', 'champignon',
    'avocat', 'radis', 'chou', 'brocoli', 'poireau', 'navet', 'céleri', 'persil', 'basilic', 'coriandre', 'menthe',
    'fruit', 'legume', 'bio',
    'steak', 'boeuf', 'viande', 'haché', 'poulet', 'dinde', 'porc', 'jambon', 'lardon', 'saucisse', 'merguez',
    'chipolata', 'boudin', 'pâté', 'rillettes', 'foie gras', 'canard', 'lapin', 'agneau', 'veau',
    'poisson', 'saumon', 'thon', 'cabillaud', 'crevette', 'moule', 'huitre', 'surimi', 'colin', 'sardine', 'maquereau',
    'filet', 'escalope', 'cuisse', 'aile', 'rôti', 'côte',
    'lait', 'beurre', 'crème', 'yaourt', 'fromage', 'oeuf', 'emmental', 'comté', 'mozzarella', 'parmesan',
    'camembert', 'brie', 'roquefort', 'chèvre', 'feta', 'raclette', 'fondue', 'tartiflette', 'mascarpone',
    'ricotta', 'skyr', 'faisselle', 'blanc', 'dessert', 'flan', 'mousse', 'liégeois', 'viennois',
    'pâte', 'riz', 'semoule', 'blé', 'quinoa', 'lentille', 'pois', 'maïs',
    'farine', 'sucre', 'sel', 'poivre', 'épice', 'huile', 'vinaigre', 'moutarde', 'mayonnaise', 'ketchup',
    'sauce', 'pesto', 'bolognaise', 'carbonara', 'conserve', 'bocal', 'boite',
    'biscuit', 'gâteau', 'chocolat', 'bonbon', 'chips', 'apéritif', 'cacahuète', 'noix', 'amande',
    'céréale', 'muesli', 'confiture', 'miel', 'nutella', 'café', 'thé', 'infusion', 'cacao',
    'pain', 'mie', 'brioche', 'biscotte', 'croissant', 'chocolatine', 'baguette',
    'eau', 'jus', 'soda', 'cola', 'limonade', 'sirop', 'bière', 'vin', 'cidre', 'champagne', 'alcool',
    'whisky', 'vodka', 'rhum', 'gin', 'tequila', 'apérol', 'martini', 'ricard', 'pastis',
    'savon', 'shampooing', 'shampoing', 'déodorant', 'dentifrice', 'brosse',
    'mouchoir', 'coton', 'couche', 'serviette', 'tampon', 'rasoir', 'mousse',
    'soin', 'maquillage', 'parfum',
    'lessive', 'adoucissant', 'assouplissant', 'vaisselle', 'nettoyant', 'dégraissant',
    'javel', 'sol', 'vitre', 'éponge', 'sac', 'alu', 'film', 'pile', 'ampoule',
  ];

  static const List<String> brandsAndStores = [
    'intermarché', 'auchan', 'leclerc', 'carrefour', 'monoprix', 'casino', 'lidl', 'aldi', 'cora', 'picard',
    'système u', 'super u', 'hyper u', 'biocoop', 'naturalia', 'grand frais', 'thiriet', 'toupargel',
    'la vie claire', 'bio c\'bon', 'eau vive', 'marcel & fils',
    'monique ranou', 'pâturages', 'chabrior', 'saint eloi', 'top budget', 'marque repère', 'eco+',
    'danone', 'yoplait', 'nestlé', 'panzani', 'barilla', 'lustucru', 'bonduelle', 'd\'aucy', 'géant vert',
    'heinz', 'amora', 'maille', 'puget', 'isio', 'lesieur', 'coca', 'pepsi', 'orangina', 'schweppes', 'lipton',
    'heineken', 'kronenbourg', 'leffe', 'desperados', 'evian', 'volvic', 'cristaline', 'vittel', 'perrier',
    'badoit', 'san pellegrino', 'tropicana', 'joker', 'pampers', 'huggies', 'nivea', 'dop', 'l\'oréal', 'garnier',
    'mixa', 'ushuaia', 'axe', 'dove', 'le petit marseillais', 'ariel', 'skip', 'dash', 'persil', 'x-tra',
    'mir', 'paic', 'finish', 'sun', 'cajoline', 'soupline', 'lenor', 'herta', 'fleury michon', 'justin bridou',
    'cochonou', 'aoste', 'labeyrie', 'delpeyrat', 'madrange', 'sodebo', 'marie', 'buitoni', 'findus', 'iglo',
    'mccain', 'charal', 'bigard', 'socopa', 'president', 'galbani', 'lactel', 'candia', 'elle & vire',
    'bridel', 'paysan breton', 'entremont', 'bel', 'vache qui rit', 'kiri', 'babybel', 'boursin', 'caprice des dieux',
    'chaumes', 'coeur de lion', 'leerdammer', 'fol epi', 'st moret', 'philadelphia', 'tartare', 'chavroux',
    'soignon', 'lou pérac', 'salakis', 'istara', 'ossau iraty', 'etorki', 'p\'tit basque', 'rochebaron',
    'saint agur', 'société', 'papillon', 'bleu', 'total', 'prix', 'carte', 'bancaire', 'visa', 'mastercard',
    'commande', 'drive', 'bienvenue', 'merci', 'ticket', 'eur', 'kg', 'litre', 'montant', 'tva'
  ];

  static String? matchProduct(String text) {
    String cleanedText = text.toLowerCase();
    
    // 1. Remove brands
    for (final brand in brandsAndStores) {
      cleanedText = cleanedText.replaceAll(brand, '').trim();
    }
    
    // If nothing left or very short, it was just a brand
    if (cleanedText.length < 2) return null;

    // 2. Find longest match
    String? bestMatch;
    int bestMatchLength = 0;

    for (final product in products) {
      if (cleanedText.contains(product)) {
        if (product.length > bestMatchLength) {
          bestMatch = product;
          bestMatchLength = product.length;
        }
      }
    }
    
    if (bestMatch != null) {
       // Capitalize
       return bestMatch[0].toUpperCase() + bestMatch.substring(1);
    }

    return null;
  }
}
