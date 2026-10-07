/// Alimento do banco nutricional (TACO/TBCA) ou de fonte externa validada
/// (OpenFoodFacts). Os valores são SEMPRE por 100 g do alimento.
class Food {
  const Food({
    required this.id,
    required this.name,
    required this.category,
    this.aliases = const [],
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0,
    this.sodium = 0,
    this.standardPortionGrams = 100,
    this.source = 'TACO/TBCA',
    this.barcode,
    this.brand,
  });

  final String id;
  final String name;
  final String category;
  final List<String> aliases;
  final double kcal; // por 100 g
  final double protein; // g por 100 g
  final double carbs; // g por 100 g
  final double fat; // g por 100 g
  final double fiber; // g por 100 g
  final double sodium; // mg por 100 g
  final double standardPortionGrams;
  final String source;
  final String? barcode;
  final String? brand;

  Food copyWith({
    String? name,
    List<String>? aliases,
    String? category,
    String? brand,
  }) {
    return Food(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      aliases: aliases ?? this.aliases,
      kcal: kcal,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      sodium: sodium,
      standardPortionGrams: standardPortionGrams,
      source: source,
      barcode: barcode,
      brand: brand ?? this.brand,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'aliases': aliases,
        'kcal': kcal,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
        'sodium': sodium,
        'standardPortionGrams': standardPortionGrams,
        'source': source,
        'barcode': barcode,
        'brand': brand,
      };

  factory Food.fromJson(Map<String, dynamic> json) => Food(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? 'Outros',
        aliases: (json['aliases'] as List?)?.cast<String>() ?? const [],
        kcal: (json['kcal'] as num?)?.toDouble() ?? 0,
        protein: (json['protein'] as num?)?.toDouble() ?? 0,
        carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
        fat: (json['fat'] as num?)?.toDouble() ?? 0,
        fiber: (json['fiber'] as num?)?.toDouble() ?? 0,
        sodium: (json['sodium'] as num?)?.toDouble() ?? 0,
        standardPortionGrams: (json['standardPortionGrams'] as num?)?.toDouble() ?? 100,
        source: json['source'] as String? ?? 'TACO/TBCA',
        barcode: json['barcode'] as String?,
        brand: json['brand'] as String?,
      );

  /// Nutrientes calculados para uma porção de [grams] gramas.
  ({double kcal, double protein, double carbs, double fat, double fiber, double sodium})
      nutritionFor(double grams) {
    final factor = grams / 100;
    return (
      kcal: kcal * factor,
      protein: protein * factor,
      carbs: carbs * factor,
      fat: fat * factor,
      fiber: fiber * factor,
      sodium: sodium * factor,
    );
  }

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (name.toLowerCase().contains(q)) return true;
    for (final a in aliases) {
      if (a.toLowerCase().contains(q)) return true;
    }
    return false;
  }
}