import '../data/food_db/food_database.dart';
import '../data/models/food.dart';

class ParsedFoodItem {
  const ParsedFoodItem({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  final String name;
  final double quantity;
  final String unit;

  Food? match() {
    for (final query in _nameVariants(name)) {
      final results = FoodDatabase.search(query, limit: 1);
      if (results.isNotEmpty) return results.first;
    }
    return null;
  }

  double quantityInGrams(Food food) {
    switch (unit) {
      case 'kg':
        return quantity * 1000;
      case 'l':
        return quantity * 1000;
      case 'ml':
      case 'g':
        return quantity;
      case 'unidade':
        return food.standardPortionGrams * quantity;
      case 'xicara':
        return food.standardPortionGrams * quantity;
      default:
        return 0;
    }
  }

  static Iterable<String> _nameVariants(String value) sync* {
    final clean = value.trim();
    yield clean;
    if (clean.toLowerCase().endsWith('s') && clean.length > 2) {
      yield clean.substring(0, clean.length - 1);
    }
  }
}

class MealTextParser {
  const MealTextParser();

  static final RegExp _itemPattern = RegExp(
    r'^(\d+(?:[\.,]\d+)?)\s*(gramas?|quilogramas?|mililitros?|litros?|kg|ml|g|l|unidades?|un|x[ií]caras?)?\s*(?:de\s+)?(.+)$',
    caseSensitive: false,
  );

  List<ParsedFoodItem> parse(String text) {
    final normalized = text
        .trim()
        .replaceAll(RegExp(r'\s+e\s+(?=\d)', caseSensitive: false), ',')
        .replaceAll(RegExp(r'[;+]'), ',')
        .replaceFirst(
          RegExp(r'^(?:eu\s+)?(?:comi|consumi|bebi)\s+', caseSensitive: false),
          '',
        );

    final result = <ParsedFoodItem>[];
    for (final raw in normalized.split(',')) {
      final segment = raw.trim().replaceAll(RegExp(r'[.!?]+$'), '');
      if (segment.isEmpty) continue;
      final match = _itemPattern.firstMatch(segment);
      if (match == null) continue;

      final quantity = double.tryParse(match.group(1)!.replaceAll(',', '.'));
      final name = match.group(3)!.trim();
      if (quantity == null || quantity <= 0 || name.isEmpty) continue;
      result.add(ParsedFoodItem(
        name: name,
        quantity: quantity,
        unit: _normalizeUnit(match.group(2), name),
      ));
    }
    return result;
  }

  String _normalizeUnit(String? raw, String name) {
    final unit = (raw ?? '').toLowerCase();
    if (unit == 'g' || unit.startsWith('grama')) return 'g';
    if (unit == 'kg' || unit.startsWith('quilograma')) return 'kg';
    if (unit == 'ml' || unit.startsWith('mililitro')) return 'ml';
    if (unit == 'l' || unit.startsWith('litro')) return 'l';
    if (unit.startsWith('x')) return 'xicara';
    if (unit == 'un' || unit.startsWith('unidade')) return 'unidade';
    return name.toLowerCase().endsWith('s') ? 'unidade' : 'g';
  }
}
