import 'food.dart';

/// Item individual dentro de uma refeição.
class MealItem {
  const MealItem({
    required this.food,
    required this.quantityGrams,
  });

  final Food food;
  final double quantityGrams;

  Map<String, dynamic> toJson() => {
        'food': food.toJson(),
        'quantityGrams': quantityGrams,
      };

  factory MealItem.fromJson(Map<String, dynamic> json) => MealItem(
        food: Food.fromJson(json['food'] as Map<String, dynamic>),
        quantityGrams: (json['quantityGrams'] as num?)?.toDouble() ?? 0,
      );

  ({double kcal, double protein, double carbs, double fat, double fiber, double sodium}) get nutrition =>
      food.nutritionFor(quantityGrams);
}

/// Tipos de refeição.
enum MealType { cafeDaManha, almoco, lanche, jantar, ceia, outro }

extension MealTypeX on MealType {
  String get label {
    switch (this) {
      case MealType.cafeDaManha:
        return 'Café da manhã';
      case MealType.almoco:
        return 'Almoço';
      case MealType.lanche:
        return 'Lanche';
      case MealType.jantar:
        return 'Jantar';
      case MealType.ceia:
        return 'Ceia';
      case MealType.outro:
        return 'Outro';
    }
  }

  String get emoji {
    switch (this) {
      case MealType.cafeDaManha:
        return '🍳';
      case MealType.almoco:
        return '🍽️';
      case MealType.lanche:
        return '🥪';
      case MealType.jantar:
        return '🍛';
      case MealType.ceia:
        return '🌙';
      case MealType.outro:
        return '🥣';
    }
  }

  static MealType fromLabel(String label) {
    return MealType.values.firstWhere(
      (t) => t.label == label,
      orElse: () => MealType.outro,
    );
  }
}

/// Uma refeição completa registrada.
class Meal {
  const Meal({
    required this.id,
    required this.date,
    required this.type,
    required this.items,
    this.rawText,
    this.createdAt,
  });

  final String id;
  final DateTime date;
  final MealType type;
  final List<MealItem> items;
  final String? rawText;
  final DateTime? createdAt;

  double get totalKcal => items.fold(0, (s, i) => s + i.nutrition.kcal);
  double get totalProtein => items.fold(0, (s, i) => s + i.nutrition.protein);
  double get totalCarbs => items.fold(0, (s, i) => s + i.nutrition.carbs);
  double get totalFat => items.fold(0, (s, i) => s + i.nutrition.fat);
  double get totalFiber => items.fold(0, (s, i) => s + i.nutrition.fiber);
  double get totalSodium => items.fold(0, (s, i) => s + i.nutrition.sodium);

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'type': type.name,
        'items': items.map((e) => e.toJson()).toList(),
        'rawText': rawText,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory Meal.fromJson(Map<String, dynamic> json) => Meal(
        id: json['id'] as String? ?? '',
        date: DateTime.tryParse(json['date'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        type: MealType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => MealType.outro,
        ),
        items: (json['items'] as List? ?? [])
            .map((e) => MealItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        rawText: json['rawText'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );
}