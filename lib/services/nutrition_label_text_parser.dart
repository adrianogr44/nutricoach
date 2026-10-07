import '../data/models/food.dart';
import 'bioimpedance_text_parser.dart';

class ParsedNutritionLabel {
  const ParsedNutritionLabel({
    required this.name,
    this.brand,
    this.kcal,
    this.protein,
    this.carbs,
    this.fat,
    this.fiber,
    this.sodium,
  });

  final String name;
  final String? brand;
  final double? kcal;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? fiber;
  final double? sodium;

  Food toFood(String id, String category) => Food(
        id: id,
        name: name,
        category: category,
        kcal: kcal ?? 0,
        protein: protein ?? 0,
        carbs: carbs ?? 0,
        fat: fat ?? 0,
        fiber: fiber ?? 0,
        sodium: sodium ?? 0,
        source: 'Rótulo do produto',
        brand: brand,
      );
}

class NutritionLabelTextParser {
  const NutritionLabelTextParser();

  ParsedNutritionLabel parse(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) {
      throw const LocalParseException('O texto do rótulo está vazio.');
    }

    final label = ParsedNutritionLabel(
      name: _lineValue(text, const ['produto', 'nome']) ?? 'Produto sem nome',
      brand: _lineValue(text, const ['marca']),
      kcal: _value(text, const ['valor energético', 'valor energetico', 'energia']),
      protein: _value(text, const ['proteínas', 'proteinas', 'proteína', 'proteina']),
      carbs: _value(text, const ['carboidratos', 'carboidrato']),
      fat: _value(text, const ['gorduras totais', 'gordura total', 'lipídios', 'lipidios']),
      fiber: _value(text, const ['fibra alimentar', 'fibras alimentares', 'fibras']),
      sodium: _value(text, const ['sódio', 'sodio']),
    );

    if (label.kcal == null &&
        label.protein == null &&
        label.carbs == null &&
        label.fat == null) {
      throw const LocalParseException(
        'Nenhum valor nutricional conhecido foi encontrado. Revise o texto.',
      );
    }
    return label;
  }

  double? _value(String text, List<String> labels) {
    for (final label in labels) {
      final match = RegExp(
        '${RegExp.escape(label)}\\s*[:.-]?\\s*([0-9]+(?:[.,][0-9]+)?)',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        return double.tryParse(match.group(1)!.replaceAll(',', '.'));
      }
    }
    return null;
  }

  String? _lineValue(String text, List<String> labels) {
    for (final label in labels) {
      final match = RegExp(
        '(?:^|\\n)\\s*${RegExp.escape(label)}\\s*[:.-]?\\s*([^\\n\\r]+)',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) return match.group(1)?.trim();
    }
    return null;
  }
}
