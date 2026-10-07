import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/core/constants.dart';
import 'package:nutricoach_ai/core/utils/nutrition_calculator.dart';
import 'package:nutricoach_ai/data/food_db/food_database.dart';
import 'package:nutricoach_ai/data/models/daily_summary.dart';
import 'package:nutricoach_ai/data/models/meal.dart';
import 'package:nutricoach_ai/data/models/tracking.dart';
import 'package:nutricoach_ai/data/models/user_profile.dart';

void main() {
  group('Banco TACO/TBCA', () {
    test('contém alimentos reais com valores por 100g', () {
      final arroz = FoodDatabase.byId('arroz-branco');
      expect(arroz, isNotNull);
      expect(arroz!.kcal, closeTo(128, 2));

      final frango = FoodDatabase.byId('peito-frango');
      expect(frango, isNotNull);
      expect(frango!.protein, greaterThan(25));
    });

    test('tabela TACO 4ª ed. completa (597 alimentos)', () {
      expect(FoodDatabase.all.length, greaterThanOrEqualTo(597));

      final arrozIntegral = FoodDatabase.byId('taco-1');
      expect(arrozIntegral, isNotNull);
      expect(arrozIntegral!.name, contains('Arroz, integral'));
      expect(arrozIntegral.kcal, closeTo(124, 2));

      final abacate = FoodDatabase.byId('taco-163');
      expect(abacate, isNotNull);
      expect(abacate!.name, contains('Abacate'));
      expect(abacate.category, 'Frutas e derivados');

      final queijoPrato = FoodDatabase.byId('taco-467');
      expect(queijoPrato, isNotNull);
      expect(queijoPrato!.kcal, closeTo(360, 2));
      expect(queijoPrato.category, 'Queijos e derivados');
    });

    test('busca encontra itens TACO por nome e caso reduzido', () {
      final preto = FoodDatabase.search('feijao preto');
      expect(
        preto.any((f) => f.id == 'taco-567'),
        isTrue,
        reason: 'Feijão, preto, cozido deve aparecer',
      );
      expect(FoodDatabase.search('queijo minas').any((f) => f.category == 'Queijos e derivados'), isTrue);
      expect(FoodDatabase.search('laranja valencia').isNotEmpty, isTrue);
    });

    test('busca com acentuação e alias', () {
      expect(FoodDatabase.search('feijao').isNotEmpty, isTrue);
      expect(FoodDatabase.search('peito de frango').isNotEmpty, isTrue);
      expect(FoodDatabase.search('strogonoff').isNotEmpty, isTrue);
    });

    test('nutrição calculada por porção', () {
      final arroz = FoodDatabase.byId('arroz-branco')!;
      // 200g de arroz = 2x os valores de 100g
      final n = arroz.nutritionFor(200);
      expect(n.kcal, closeTo(arroz.kcal * 2, 0.01));
      expect(n.protein, closeTo(arroz.protein * 2, 0.01));
    });
  });

  group('Calculadora nutricional', () {
    const homem = UserProfile(
      pesoAtualKg: 80,
      pesoDesejadoKg: 75,
      alturaCm: 180,
      idade: 30,
      sexo: Sexo.masculino,
      objetivo: Objetivo.emagrecer,
      nivelAtividade: NivelAtividade.moderado,
    );

    test('TMB Mifflin-St Jeor para homem 80kg/180cm/30y', () {
      final tmb = NutritionCalculator.tmb(
        pesoKg: 80,
        alturaCm: 180,
        idade: 30,
        sexo: Sexo.masculino,
      );
      expect(tmb, closeTo(1780, 1));
    });

    test('TDEE com nível moderado', () {
      final tmb = NutritionCalculator.tmb(
        pesoKg: homem.pesoAtualKg,
        alturaCm: homem.alturaCm,
        idade: homem.idade,
        sexo: homem.sexo,
      );
      final tdee = NutritionCalculator.tdee(tmb: tmb, nivel: NivelAtividade.moderado);
      expect(tdee, closeTo(tmb * 1.55, 1));
    });

    test('meta calórica para emagrecer = TDEE - 500', () {
      final tdee = 2500.0;
      final meta = NutritionCalculator.metaCalorica(tdee: tdee, objetivo: Objetivo.emagrecer);
      expect(meta, closeTo(2000, 0.001));
    });

    test('meta de proteína: 2g/kg no déficit', () {
      expect(NutritionCalculator.metaProteina(pesoKg: 80, objetivo: Objetivo.emagrecer), 160);
      expect(NutritionCalculator.metaProteina(pesoKg: 80, objetivo: Objetivo.manter), closeTo(128, 0.001));
    });

    test('IMC', () {
      expect(NutritionCalculator.imc(pesoKg: 80, alturaCm: 180), closeTo(24.69, 0.1));
    });
  });

  group('Resumo diário (status)', () {
    const profile = UserProfile(
      pesoAtualKg: 80,
      pesoDesejadoKg: 75,
      alturaCm: 180,
      idade: 30,
      sexo: Sexo.masculino,
      objetivo: Objetivo.emagrecer,
      nivelAtividade: NivelAtividade.moderado,
      metaCalorica: 2000,
      metaProteina: 160,
      metaCarboidrato: 200,
      metaGordura: 60,
      metaAguaMl: 2800,
    );

    DailySummary dayWith(double kcalConsumed, double kcalBurned) {
      final arroz = FoodDatabase.byId('arroz-branco')!;
      // ~128 kcal / 100g → precisa ~n gramas
      final grams = (kcalConsumed / arroz.kcal) * 100;
      return DailySummary(
        date: DateTime.now(),
        meals: [
          Meal(
            id: 'm1',
            date: DateTime.now(),
            type: MealType.almoco,
            items: [MealItem(food: arroz, quantityGrams: grams)],
          ),
        ],
        workouts: kcalBurned > 0
            ? [Workout(id: 'w1', date: DateTime.now(), kcalBurned: kcalBurned, source: 'test')]
            : const [],
        waterRecords: const [],
        profile: profile,
      );
    }

    test('déficit calórico', () {
      // comeu 1400, gastou 300 → líquido 1100, déficit de 900
      final day = dayWith(1400, 300);
      expect(day.status, DayStatus.deficit);
      expect(day.balanceKcal, greaterThan(0));
    });

    test('superávit', () {
      final day = dayWith(2500, 0);
      expect(day.status, DayStatus.surplus);
    });

    test('manutenção (dentro de ±50)', () {
      final day = dayWith(2000, 0);
      expect(day.status, DayStatus.maintenance);
    });
  });
}