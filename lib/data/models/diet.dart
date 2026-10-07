import 'food.dart';
import '../../services/household_measure.dart';

/// Item da dieta planejada — referência ao alimento + quantidade + unidade caseira.
class DietMealItem {
  const DietMealItem({
    required this.foodId,
    required this.quantity,
    required this.unit,
    this.customGramsPerUnit,
    this.foodSnapshot,
  });

  final String foodId;
  final double quantity;
  final MeasureUnit unit;
  final double? customGramsPerUnit;
  /// Snapshot do alimento no momento da criação (para exibir mesmo se banco mudar).
  final Food? foodSnapshot;

  double gramsFor(Food food) {
    return const HouseholdMeasureConverter().toGrams(food, quantity, unit, customGramsPerUnit: customGramsPerUnit);
  }

  ({double kcal, double protein, double carbs, double fat, double fiber, double sodium}) nutritionFor(Food food) {
    final grams = gramsFor(food);
    return food.nutritionFor(grams);
  }

  Map<String, dynamic> toJson() => {
        'foodId': foodId,
        'quantity': quantity,
        'unit': unit.name,
        'customGramsPerUnit': customGramsPerUnit,
        'foodSnapshot': foodSnapshot?.toJson(),
      };

  factory DietMealItem.fromJson(Map<String, dynamic> json) => DietMealItem(
        foodId: json['foodId'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        unit: MeasureUnitX.fromString(json['unit'] as String? ?? 'g'),
        customGramsPerUnit: (json['customGramsPerUnit'] as num?)?.toDouble(),
        foodSnapshot: json['foodSnapshot'] != null ? Food.fromJson(json['foodSnapshot'] as Map<String, dynamic>) : null,
      );

  DietMealItem copyWith({double? quantity, MeasureUnit? unit, double? customGramsPerUnit, Food? foodSnapshot}) {
    return DietMealItem(
      foodId: foodId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      customGramsPerUnit: customGramsPerUnit ?? this.customGramsPerUnit,
      foodSnapshot: foodSnapshot ?? this.foodSnapshot,
    );
  }
}

/// Refeição da dieta planejada (ex: Café da manhã, Almoço).
class DietMeal {
  const DietMeal({
    required this.id,
    required this.name,
    this.time,
    this.order = 0,
    this.items = const [],
  });

  final String id;
  final String name;
  final String? time; // "07:30"
  final int order;
  final List<DietMealItem> items;

  double totalKcal(Map<String, Food> foodById) {
    double sum = 0;
    for (final it in items) {
      final food = foodById[it.foodId] ?? it.foodSnapshot;
      if (food == null) continue;
      sum += it.nutritionFor(food).kcal;
    }
    return sum;
  }

  Map<String, double> totals(Map<String, Food> foodById) {
    double kcal = 0, p = 0, c = 0, f = 0;
    for (final it in items) {
      final food = foodById[it.foodId] ?? it.foodSnapshot;
      if (food == null) continue;
      final n = it.nutritionFor(food);
      kcal += n.kcal;
      p += n.protein;
      c += n.carbs;
      f += n.fat;
    }
    return {'kcal': kcal, 'protein': p, 'carbs': c, 'fat': f};
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'time': time,
        'order': order,
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory DietMeal.fromJson(Map<String, dynamic> json) => DietMeal(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Refeição',
        time: json['time'] as String?,
        order: (json['order'] as num?)?.toInt() ?? 0,
        items: (json['items'] as List? ?? []).map((e) => DietMealItem.fromJson(e as Map<String, dynamic>)).toList(),
      );

  DietMeal copyWith({String? name, String? time, int? order, List<DietMealItem>? items}) {
    return DietMeal(id: id, name: name ?? this.name, time: time ?? this.time, order: order ?? this.order, items: items ?? this.items);
  }
}

/// Plano alimentar completo (template) — uma dieta ativa por vez inicialmente.
class DietPlan {
  const DietPlan({
    required this.id,
    required this.name,
    this.meals = const [],
    this.createdAt,
    this.updatedAt,
    this.isActive = true,
  });

  final String id;
  final String name;
  final List<DietMeal> meals;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isActive;

  Map<String, double> get totals {
    double kcal = 0, p = 0, c = 0, f = 0;
    // precisa de foodById mas para getter rápido calculamos via snapshot se disponível
    for (final meal in meals) {
      for (final it in meal.items) {
        final food = it.foodSnapshot;
        if (food == null) continue;
        final n = it.nutritionFor(food);
        kcal += n.kcal;
        p += n.protein;
        c += n.carbs;
        f += n.fat;
      }
    }
    return {'kcal': kcal, 'protein': p, 'carbs': c, 'fat': f};
  }

  /// Calcula totais usando banco atual (mais preciso quando alimento tem dados atualizados).
  Map<String, double> totalsWith(Map<String, Food> foodById) {
    double kcal = 0, p = 0, c = 0, f = 0;
    for (final m in meals) {
      final t = m.totals(foodById);
      kcal += t['kcal']!;
      p += t['protein']!;
      c += t['carbs']!;
      f += t['fat']!;
    }
    return {'kcal': kcal, 'protein': p, 'carbs': c, 'fat': f};
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'meals': meals.map((e) => e.toJson()).toList(),
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'isActive': isActive,
      };

  factory DietPlan.fromJson(Map<String, dynamic> json) => DietPlan(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Minha Dieta',
        meals: (json['meals'] as List? ?? []).map((e) => DietMeal.fromJson(e as Map<String, dynamic>)).toList(),
        createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
        updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
        isActive: json['isActive'] as bool? ?? true,
      );

  DietPlan copyWith({String? name, List<DietMeal>? meals, DateTime? updatedAt, bool? isActive}) {
    return DietPlan(id: id, name: name ?? this.name, meals: meals ?? this.meals, createdAt: createdAt, updatedAt: updatedAt ?? this.updatedAt, isActive: isActive ?? this.isActive);
  }
}
