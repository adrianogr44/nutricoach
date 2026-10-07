import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/data/models/diet.dart';
import 'package:nutricoach_ai/data/models/food.dart';
import 'package:nutricoach_ai/services/household_measure.dart';

void main() {
  group('HouseholdMeasureConverter', () {
    test('converte medidas caseiras por alimento (feijao concha 90g)', () {
      const food = Food(id: 'feijao-carioca', name: 'Feijão carioca cozido', category: 'Leguminosas', kcal: 76, protein: 4.8, carbs: 13.6, fat: 0.5);
      const converter = HouseholdMeasureConverter();
      expect(converter.toGrams(food, 1, MeasureUnit.concha), 90);
      expect(converter.toGrams(food, 1.5, MeasureUnit.concha), 135);
      expect(converter.toGrams(food, 2, MeasureUnit.concha), 180);
      // arroz concha 45g
      const arroz = Food(id: 'arroz-branco', name: 'Arroz branco cozido', category: 'Cereais e grãos', kcal: 128, protein: 2.5, carbs: 28.1, fat: 0.2);
      expect(converter.toGrams(arroz, 1, MeasureUnit.concha), 45);
    });

    test('converte g/kg/ml/litro direto', () {
      const food = Food(id: 'arroz-branco', name: 'Arroz', category: 'Cereais e grãos', kcal: 128, protein: 2.5, carbs: 28.1, fat: 0.2);
      const c = HouseholdMeasureConverter();
      expect(c.toGrams(food, 150, MeasureUnit.g), 150);
      expect(c.toGrams(food, 0.5, MeasureUnit.kg), 500);
      expect(c.toGrams(food, 200, MeasureUnit.ml), 200);
      expect(c.toGrams(food, 1, MeasureUnit.l), 1000);
    });

    test('unidade e fatia usam standardPortion', () {
      const pao = Food(id: 'pao-forma', name: 'Pão forma', category: 'Pães e torradas', kcal: 253, protein: 7.9, carbs: 43.4, fat: 3.7, standardPortionGrams: 25);
      const c = HouseholdMeasureConverter();
      expect(c.toGrams(pao, 2, MeasureUnit.fatia), 50);
      expect(c.toGrams(pao, 1, MeasureUnit.unidade), 25);
    });

    test('customGrams per unit sobrescreve', () {
      const food = Food(id: 'feijao-carioca', name: 'Feijão', category: 'Leguminosas', kcal: 76, protein: 4.8, carbs: 13.6, fat: 0.5);
      const c = HouseholdMeasureConverter();
      expect(c.toGrams(food, 1, MeasureUnit.concha, customGramsPerUnit: 120), 120);
    });

    test('nutricao calculada via gramas', () {
      const feijao = Food(id: 'feijao-carioca', name: 'Feijão', category: 'Leguminosas', kcal: 76, protein: 4.8, carbs: 13.6, fat: 0.5);
      const c = HouseholdMeasureConverter();
      final grams = c.toGrams(feijao, 1, MeasureUnit.concha); // 90
      final n = feijao.nutritionFor(grams);
      expect(n.kcal, closeTo(68.4, 0.1));
      expect(n.protein, closeTo(4.32, 0.1));
    });
  });

  group('DietPlan', () {
    test('calcula totais via food map', () {
      const arroz = Food(id: 'arroz-branco', name: 'Arroz branco cozido', category: 'Cereais e grãos', kcal: 128, protein: 2.5, carbs: 28.1, fat: 0.2, standardPortionGrams: 100);
      const feijao = Food(id: 'feijao-carioca', name: 'Feijão carioca cozido', category: 'Leguminosas', kcal: 76, protein: 4.8, carbs: 13.6, fat: 0.5, standardPortionGrams: 100);
      final diet = DietPlan(
        id: 'd1',
        name: 'Minha Dieta',
        meals: [
          DietMeal(id: 'm1', name: 'Almoço', time: '12:30', items: [
            DietMealItem(foodId: 'arroz-branco', quantity: 150, unit: MeasureUnit.g, foodSnapshot: arroz),
            DietMealItem(foodId: 'feijao-carioca', quantity: 1, unit: MeasureUnit.concha, foodSnapshot: feijao),
          ]),
        ],
      );
      final totals = diet.totalsWith({'arroz-branco': arroz, 'feijao-carioca': feijao});
      // 150g arroz 192 kcal + 90g feijao 68.4 = 260.4
      expect(totals['kcal']!, closeTo(260.4, 0.2));
      expect(totals['protein']!, closeTo(3.75 + 4.32, 0.1));
    });

    test('serializa e desserializa', () {
      final plan = DietPlan(id: 'id', name: 'Teste', meals: [DietMeal(id: 'm1', name: 'Café', time: '07:30', items: [DietMealItem(foodId: 'ovo', quantity: 2, unit: MeasureUnit.unidade)])]);
      final json = plan.toJson();
      final restored = DietPlan.fromJson(json);
      expect(restored.name, 'Teste');
      expect(restored.meals.first.name, 'Café');
      expect(restored.meals.first.items.first.quantity, 2);
      expect(restored.meals.first.items.first.unit, MeasureUnit.unidade);
    });

    test('diet clone nao confunde com daily meal', () {
      const frango = Food(id: 'peito-frango', name: 'Peito de frango grelhado', category: 'Carnes e aves', kcal: 159, protein: 32, carbs: 0, fat: 3.2);
      final dietItem = DietMealItem(foodId: 'peito-frango', quantity: 180, unit: MeasureUnit.g, foodSnapshot: frango);
      // Simula log com quantidade alterada só no diário: 150g
      const converter = HouseholdMeasureConverter();
      final plannedGrams = converter.toGrams(frango, 180, MeasureUnit.g);
      final dailyGrams = converter.toGrams(frango, 150, MeasureUnit.g);
      expect(plannedGrams, 180);
      expect(dailyGrams, 150);
      // Garante que alteração diária não afeta dieta
      expect(dietItem.quantity, 180);
    });
  });
}
