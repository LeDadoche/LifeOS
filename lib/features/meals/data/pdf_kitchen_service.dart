import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfKitchenService {
  
  /// Parses a PDF file bytes and returns a list of extracted shopping items.
  /// Returns a list of maps with 'name' and 'quantity'.
  Future<List<Map<String, String?>>> parseDrivePdf(Uint8List bytes) async {
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final PdfTextExtractor extractor = PdfTextExtractor(document);
    String text = extractor.extractText();
    document.dispose();

    return _processText(text);
  }

  List<Map<String, String?>> _processText(String fullText) {
    final List<String> lines = fullText.split('\n');
    final List<Map<String, String?>> items = [];
    
    bool inProductTable = false;
    
    // Keywords to start parsing
    final startKeywords = ['Désignation', 'Article', 'Produit', 'Libellé', 'Description'];
    // Keywords to stop parsing
    final stopKeywords = ['TOTAL', 'TVA', 'Montant', 'Récapitulatif', 'Merci'];

    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      // Check for start of table
      if (!inProductTable) {
        if (startKeywords.any((k) => line.contains(k))) {
          inProductTable = true;
        }
        continue;
      }

      // Check for end of table
      if (stopKeywords.any((k) => line.toUpperCase().contains(k.toUpperCase()))) {
        break;
      }

      // Parsing logic for a product line
      // Example line: "2  Coca Cola Zero 1.5L  3.50 €"
      // Example line: "1kg  Pommes Golden  2,99 €"
      
      // 1. Remove Price (usually at the end, contains € or $)
      // Regex for price: digits, comma/dot, digits, optional space, currency symbol
      final priceRegex = RegExp(r'(\d+[.,]\d+\s*[€$])');
      final priceMatch = priceRegex.firstMatch(line);
      
      String namePart = line;
      if (priceMatch != null) {
        // Take everything before the price
        namePart = line.substring(0, priceMatch.start).trim();
      }

      // If namePart is too short or empty after removing price, skip
      if (namePart.length < 3) continue;

      // 2. Extract Quantity
      // Usually at the start. "2 x", "2 ", "1.5kg "
      String? quantity;
      String name = namePart;

      // Regex: Start with digits (maybe decimals), optional unit, followed by space
      final qtyRegex = RegExp(r'^(\d+(?:[.,]\d+)?\s*(?:x|kg|g|L|ml|cl|pcs)?)\s+(.*)$', caseSensitive: false);
      final qtyMatch = qtyRegex.firstMatch(namePart);

      if (qtyMatch != null) {
        quantity = qtyMatch.group(1)?.trim();
        name = qtyMatch.group(2)?.trim() ?? namePart;
      } else {
        // Sometimes quantity is just a number at the start
        final simpleQtyRegex = RegExp(r'^(\d+)\s+(.*)$');
        final simpleQtyMatch = simpleQtyRegex.firstMatch(namePart);
        if (simpleQtyMatch != null) {
          quantity = simpleQtyMatch.group(1);
          name = simpleQtyMatch.group(2) ?? namePart;
        }
      }

      // Clean up name
      name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
      
      // Filter out garbage lines that might have been caught (e.g. just a barcode or reference number)
      // If name is only digits/symbols
      if (RegExp(r'^[\d\W]+$').hasMatch(name)) continue;
      
      // If name is one of the start keywords repeated
      if (startKeywords.any((k) => name.contains(k))) continue;

      if (name.length > 2) {
        items.add({
          'name': name,
          'quantity': quantity,
        });
      }
    }

    return items;
  }
}
