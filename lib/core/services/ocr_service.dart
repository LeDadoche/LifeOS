import 'dart:math';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../features/meals/data/grocery_dictionary.dart';

class OcrResult {
  final String name;
  final String? quantity;

  OcrResult({required this.name, this.quantity});
}

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<List<OcrResult>> processImage(InputImage inputImage) async {
    final recognizedText = await _textRecognizer.processImage(inputImage);
    final List<TextLine> allLines = [];

    for (var block in recognizedText.blocks) {
      allLines.addAll(block.lines);
    }

    // 1. REGROUPEMENT SPATIAL (Clustering)
    List<List<TextLine>> clusters = _clusterLines(allLines);

    List<OcrResult> results = [];

    for (var cluster in clusters) {
      // 2. NETTOYAGE & FUSION
      String productText = _cleanAndMergeCluster(cluster);
      
      if (productText.isEmpty) continue;

      // 3. DÉTECTION QUANTITÉ (Voisinage)
      String? quantity = _findQuantityForCluster(cluster, allLines);

      // 4. VALIDATION DICTIONNAIRE
      if (_isValidProduct(productText)) {
        results.add(OcrResult(name: productText, quantity: quantity));
      }
    }

    // 5. RÉGULATION DES DOUBLONS
    // On garde le nom le plus complet (ex: "Pomme de terre" > "Pomme")
    results.sort((a, b) => b.name.length.compareTo(a.name.length));
    
    List<OcrResult> finalResults = [];
    for (var result in results) {
      bool isSubset = false;
      for (var existing in finalResults) {
        if (existing.name.toLowerCase().contains(result.name.toLowerCase())) {
          isSubset = true;
          break;
        }
      }
      if (!isSubset) {
        finalResults.add(result);
      }
    }

    return finalResults;
  }

  List<List<TextLine>> _clusterLines(List<TextLine> lines) {
    if (lines.isEmpty) return [];

    // Trier par position Y (haut vers bas)
    lines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    List<List<TextLine>> clusters = [];
    
    for (var line in lines) {
      bool added = false;
      
      // Tenter de rejoindre un cluster existant
      for (var cluster in clusters) {
        // On compare avec la dernière ligne du cluster
        TextLine lastLine = cluster.last;
        
        // Critères de proximité
        double verticalGap = (line.boundingBox.top - lastLine.boundingBox.bottom).abs();
        bool isVerticallyClose = verticalGap < 20.0; // 20 pixels de tolérance
        
        // Alignement horizontal (gauche similaire ou chevauchement X)
        bool isHorizontallyAligned = (line.boundingBox.left - lastLine.boundingBox.left).abs() < 50.0 ||
                                     (line.boundingBox.left < lastLine.boundingBox.right && line.boundingBox.right > lastLine.boundingBox.left);

        if (isVerticallyClose && isHorizontallyAligned) {
          cluster.add(line);
          added = true;
          break;
        }
      }

      if (!added) {
        clusters.add([line]);
      }
    }
    return clusters;
  }

  String _cleanAndMergeCluster(List<TextLine> cluster) {
    if (cluster.isEmpty) return '';

    // 2. FILTRE PAR TAILLE (Heuristique)
    double maxHeight = cluster.map((l) => l.boundingBox.height).reduce(max);

    List<String> validParts = [];
    bool forceNextLine = false;

    for (var line in cluster) {
      // Skip small lines unless forced by previous connector
      if (!forceNextLine && line.boundingBox.height < maxHeight * 0.7) continue;

      String text = line.text.trim();
      
      // 1. ÉLIMINATION RADICALE DES PHRASES PARASITES
      text = text.replaceAll(RegExp(r'(?:une marque|petit prix|de consommation avec|découenné dégraissé)', caseSensitive: false), '');

      // 1. FILTRE DE LIGNES "DÉTAILS" (Prefixes marketing/logistique)
      if (RegExp(r'^(?:la barquette de|le filet de|l.?unité de|les \d+ (?:pots|canettes)|une marque|petit prix|france)', caseSensitive: false).hasMatch(text)) {
        continue;
      }

      // Rejet Prix
      if (text.contains('€') || text.contains('\$')) continue;
      
      // Rejet Métadonnées
      if (RegExp(r'^\d+[\.,]?\d*\s*(g|kg|ml|cl|l)$', caseSensitive: false).hasMatch(text)) continue; 
      if (RegExp(r'\/kg', caseSensitive: false).hasMatch(text)) continue;

      // Rejet Marques isolées
      String lowerText = text.toLowerCase();
      bool isJustBrand = false;
      for (var brand in GroceryDictionary.brandsAndStores) {
        if (lowerText == brand) {
          isJustBrand = true;
          break;
        }
      }
      if (isJustBrand) continue;

      // Nettoyage partiel Marques
      for (var brand in GroceryDictionary.brandsAndStores) {
         text = text.replaceAll(RegExp(brand, caseSensitive: false), '');
      }

      // 5. QUANTITÉ (Vérification)
      text = text.replaceAll(RegExp(r'\b[xX]\d+\b'), ''); 
      text = text.replaceAll(RegExp(r'\b\d+[xX]\b'), '');

      // Nettoyage caractères parasites
      text = text.replaceAll(RegExp(r'[^\w\sàâäéèêëîïôöùûüçÀÂÄÉÈÊËÎÏÔÖÙÛÜÇ-]'), ' ');
      text = text.trim();

      if (text.length > 1) { // Tolérance > 1 pour récupérer des mots courts si forcés
        validParts.add(text);
        
        // 2. RÉPARATION DES TEXTES COUPÉS
        // Si ça finit par un mot de liaison, on force la ligne suivante
        forceNextLine = RegExp(r'(?:de|du|des|au|aux|avec|à la|sur)$', caseSensitive: false).hasMatch(text);
      } else {
        forceNextLine = false;
      }
    }

    String merged = validParts.join(' ');
    
    // 4. ESTHÉTIQUE & LISIBILITÉ
    // Title Case
    if (merged.isNotEmpty) {
      merged = merged.split(' ').map((word) {
        if (word.isEmpty) return '';
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }).join(' ');
    }
    
    // 1. SUPPRESSION DES CONNECTEURS DE FIN (The "Trim" Logic)
    merged = merged.replaceAll(RegExp(r'\s+(?:De|Du|Des|Au|Aux|Avec|À|À La|Sur|Et)$'), '');

    // Limite 40 chars (coupe propre)
    if (merged.length > 40) {
      int cutIndex = merged.lastIndexOf(' ', 40);
      if (cutIndex != -1) {
        merged = merged.substring(0, cutIndex);
      } else {
        merged = merged.substring(0, 40);
      }
    }

    // 3. VALIDATION SÉMANTIQUE
    // Ignore si aucun mot ne fait au moins 3 lettres (évite "Le", "De", "Au")
    bool hasMeaningfulWord = merged.split(' ').any((w) => w.length >= 3);
    if (!hasMeaningfulWord) return '';

    return merged.trim();
  }

  String? _findQuantityForCluster(List<TextLine> cluster, List<TextLine> allLines) {
    // Définir la zone Y du cluster
    double clusterTop = cluster.first.boundingBox.top;
    double clusterBottom = cluster.last.boundingBox.bottom;
    double clusterRight = cluster.map((l) => l.boundingBox.right).reduce(max);

    // Chercher une ligne qui est :
    // 1. Dans la même zone Y (intersection)
    // 2. À droite du cluster
    // 3. Contient un pattern de quantité (x2, 2x, 2 pcs)

    for (var line in allLines) {
      // Ne pas vérifier les lignes du cluster lui-même
      if (cluster.contains(line)) continue;

      double lineTop = line.boundingBox.top;
      double lineBottom = line.boundingBox.bottom;
      double lineLeft = line.boundingBox.left;

      // Vérifier intersection verticale
      bool verticalOverlap = (lineTop < clusterBottom && lineBottom > clusterTop);
      
      // Vérifier position à droite
      bool isToTheRight = lineLeft > clusterRight - 20; // -20 tolérance chevauchement

      if (verticalOverlap && isToTheRight) {
        String text = line.text.trim();
        // Regex quantité
        final qtyRegex = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:x|pcs|qté)', caseSensitive: false);
        final match = qtyRegex.firstMatch(text);
        if (match != null) {
          return match.group(1);
        }
        // Inverse: x 2
        final qtyRegex2 = RegExp(r'(?:x|qté)\s*(\d+(?:[.,]\d+)?)', caseSensitive: false);
        final match2 = qtyRegex2.firstMatch(text);
        if (match2 != null) {
          return match2.group(1);
        }
      }
    }
    return null;
  }

  bool _isValidProduct(String text) {
    // On vérifie si le texte contient au moins un mot du dictionnaire PRODUITS
    // On split le texte candidat en mots
    List<String> words = text.toLowerCase().split(' ');
    
    for (var word in words) {
      if (word.length < 3) continue; // Ignorer petits mots
      
      // Vérifier si ce mot est contenu dans un des produits connus
      // OU si un produit connu est contenu dans ce mot (ex: "pommes" match "pomme")
      
      // Approche plus simple : Est-ce que la chaine complète contient un produit connu ?
      // Mais GroceryDictionary.products contient "pomme de terre".
      // Si text est "Pomme de terre vapeur", ça doit matcher.
      
      for (var product in GroceryDictionary.products) {
        if (text.toLowerCase().contains(product)) {
          return true;
        }
      }
    }
    return false;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
