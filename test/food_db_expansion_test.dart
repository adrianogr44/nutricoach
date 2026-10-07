import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/data/food_db/food_database.dart';
import 'package:nutricoach_ai/data/models/diet.dart';
import 'package:nutricoach_ai/data/models/food.dart';
import 'package:nutricoach_ai/services/household_measure.dart';

const wheyId = 'dark-whey-protein-concentrate';

Food whey() => FoodDatabase.byId(wheyId)!;

void main() {
  group('Dark Supplements Whey (rótulo do produto)', () {
    test('busca por nome encontra o produto', () {
      final results = FoodDatabase.search('whey');
      expect(results, isNotEmpty, reason: 'whey precisa encontrar o produto');
      expect(results.first.id, wheyId, reason: 'match exato/intencional deve ranquear 1º');
    });

    test('busca por marca encontra o mesmo alimento', () {
      expect(FoodDatabase.search('dark whey').first.id, wheyId);
      expect(FoodDatabase.search('whey dark').first.id, wheyId);
    });

    test('busca por sigla WPC encontra o mesmo alimento', () {
      expect(FoodDatabase.search('wpc').first.id, wheyId);
    });

    test('valores nutricionais por 100 g vindos do rótulo', () {
      final f = whey();
      expect(f.kcal, closeTo(350, 0.001));
      expect(f.protein, closeTo(70, 0.001));
      expect(f.carbs, closeTo(16, 0.001));
      expect(f.fat, closeTo(1, 0.001));
      expect(f.fiber, closeTo(0, 0.001));
      expect(f.sodium, closeTo(180, 0.001));
    });

    test('porção padrão do rótulo = 30 g', () {
      expect(whey().standardPortionGrams, 30);
    });

    test('conversão da porção de 30 g reproduz o rótulo', () {
      final n = whey().nutritionFor(whey().standardPortionGrams);
      expect(n.kcal, closeTo(105, 0.001));
      expect(n.protein, closeTo(21, 0.001));
      expect(n.carbs, closeTo(4.8, 0.001));
      expect(n.fat, closeTo(0.3, 0.001));
      expect(n.fiber, closeTo(0, 0.001));
      expect(n.sodium, closeTo(54, 0.001));
    });

    test('1 porção/unidade caseira = 30 g via standardPortionGrams', () {
      const c = HouseholdMeasureConverter();
      final f = whey();
      expect(c.toGrams(f, 1, MeasureUnit.unidade), 30);
      expect(c.toGrams(f, 1, MeasureUnit.porcao), 30);
      expect(f.nutritionFor(c.toGrams(f, 1, MeasureUnit.porcao)).kcal, closeTo(105, 0.001));
    });

    test('aliases encontram o mesmo registro', () {
      for (final q in [
        'whey',
        'dark whey',
        'whey dark',
        'wpc',
        'whey protein',
        'whey protein concentrate',
        'dark supplements whey',
        'proteina whey',
        'proteína whey',
        'proteina do soro do leite',
        'suplemento proteico',
        'whey concentrado',
      ]) {
        expect(
          FoodDatabase.search(q).any((f) => f.id == wheyId),
          isTrue,
          reason: 'busca "$q" precisa encontrar o whey',
        );
      }
    });

    test('registro é único (aliases não viram alimentos separados)', () {
      final wheys = FoodDatabase.all.where((f) => f.id.contains('whey') || f.id.contains('dark'));
      expect(wheys.length, 1);
      expect(whey().source, contains('Dark Supplements'));
      expect(whey().brand, 'Dark Supplements');
      expect(whey().source, isNot(contains('TACO')));
      expect(whey().source, isNot(contains('TBCA')));
    });

    test('não depende de rede para ser encontrado', () {
      expect(FoodDatabase.search('whey').first.source, isNot('OpenFoodFacts'));
    });
  });

  group('Creatina', () {
    test('é reconhecida pela busca', () {
      final results = FoodDatabase.search('creatina');
      expect(results, isNotEmpty);
      expect(results.first.id, 'creatina-monohidratada');
    });

    test('aliases de creatina', () {
      for (final q in ['creatina', 'creatina monohidratada', 'creatine', 'creatine monohydrate']) {
        expect(
          FoodDatabase.search(q).any((f) => f.id == 'creatina-monohidratada'),
          isTrue,
          reason: 'busca "$q" precisa encontrar creatina',
        );
      }
    });

    test('não atribui macros arbitrários', () {
      final c = FoodDatabase.byId('creatina-monohidratada')!;
      expect(c.kcal, 0);
      expect(c.protein, 0);
      expect(c.carbs, 0);
      expect(c.fat, 0);
      expect(c.fiber, 0);
      expect(c.sodium, 0);
      expect(c.standardPortionGrams, 5);
      expect(c.nutritionFor(5).kcal, 0);
    });
  });

  group('Buscas simples da dieta', () {
    const queries = [
      'frango',
      'peito de frango',
      'carne bovina',
      'patinho',
      'peixe',
      'tilápia',
      'ovo',
      'ovo inteiro',
      'arroz',
      'arroz branco cozido',
      'macarrão',
      'macarrão cozido',
      'feijão',
      'feijão carioca',
      'feijão preto',
      'lentilha',
      'pão',
      'pão francês',
      'pão de forma',
      'aveia',
      'banana',
      'maçã',
      'mamão',
      'mamao',
      'laranja',
    ];

    test('todas retornam resultados locais', () {
      for (final q in queries) {
        expect(
          FoodDatabase.search(q),
          isNotEmpty,
          reason: 'busca "$q" precisa retornar resultados no banco local',
        );
      }
    });

    test('pao e pão retornam resultados equivalentes', () {
      final semAcento = FoodDatabase.search('pao').map((f) => f.id).toList();
      final comAcento = FoodDatabase.search('pão').map((f) => f.id).toList();
      expect(comAcento, semAcento);
      expect(semAcento, isNotEmpty);
    });

    test('buscas-chave retornam o alimento esperado em 1º lugar', () {
      expect(FoodDatabase.search('arroz branco cozido').first.id, 'arroz-branco');
      expect(FoodDatabase.search('banana').first.id, 'banana');
      expect(FoodDatabase.search('peito de frango').first.id, 'peito-frango');
      expect(
        FoodDatabase.search('feijão carioca').any((f) => f.id == 'feijao-carioca'),
        isTrue,
        reason: 'feijão carioca precisa ser encontrado (TACO e curado compartilham o alias)',
      );
      expect(FoodDatabase.search('aveia').first.id, 'aveia');
    });
  });

  group('Sem duplicação', () {
    test('ids do banco são únicos', () {
      final ids = [for (final f in FoodDatabase.all) f.id];
      expect(ids.toSet().length, ids.length, reason: 'nenhum id pode se repetir');
    });

    test('alimentos da dieta não ganharam cópias', () {
      for (final id in [
        'arroz-branco',
        'peito-frango',
        'ovo',
        'pao-frances',
        'pao-forma',
        'banana',
        'maca',
        'mamao',
        'laranja',
        'feijao-carioca',
        'feijao-preto',
        'lentilha',
        'aveia',
        'macarrao',
        'patinho',
        'tilapia',
      ]) {
        expect(FoodDatabase.byId(id), isNotNull, reason: '$id deve continuar existindo');
        expect(
          FoodDatabase.all.where((f) => f.id == id).length,
          1,
          reason: '$id não pode ser duplicado',
        );
      }
    });

    test('expansão adiciona apenas os novos registros curados', () {
      final ids = {for (final f in FoodDatabase.all) f.id};
      expect(ids.length, greaterThanOrEqualTo(597 + 132));
      expect(ids.where((id) => id.contains('whey')).length, 1);
      expect(ids.where((id) => id.contains('creatina')).length, 1);
    });
  });

  group('Dieta referencia o banco', () {
    test('café da manhã usa whey, aveia, creatina e banana', () {
      final byId = {for (final f in FoodDatabase.all) f.id: f};
      const converter = HouseholdMeasureConverter();
      final breakfast = DietPlan(
        id: 'd1',
        name: 'Minha Dieta',
        meals: [
          DietMeal(id: 'm1', name: 'Café da manhã', time: '07:30', items: [
            DietMealItem(foodId: wheyId, quantity: 30, unit: MeasureUnit.g),
            DietMealItem(foodId: 'aveia', quantity: 50, unit: MeasureUnit.g),
            DietMealItem(foodId: 'creatina-monohidratada', quantity: 5, unit: MeasureUnit.g),
            DietMealItem(foodId: 'banana', quantity: 1, unit: MeasureUnit.unidade),
          ]),
        ],
      );

      for (final item in breakfast.meals.first.items) {
        expect(byId[item.foodId], isNotNull, reason: '${item.foodId} precisa existir no banco');
      }

      final wheyItem = breakfast.meals.first.items.first;
      final wheyFood = byId[wheyItem.foodId]!;
      expect(converter.toGrams(wheyFood, wheyItem.quantity, wheyItem.unit), 30);

      final totals = breakfast.totalsWith(byId);
      // 105 (whey 30g) + 197 (aveia 50g) + 0 (creatina 5g) + 98 (banana 100g)
      expect(totals['kcal']!, closeTo(400, 0.01));
      expect(totals['protein']!, closeTo(29.25, 0.01));
    });

    test('item da dieta calcula nutrição a partir do Food referenciado', () {
      final item = DietMealItem(foodId: wheyId, quantity: 30, unit: MeasureUnit.g);
      final food = FoodDatabase.byId(item.foodId)!;
      final n = item.nutritionFor(food);
      expect(n.kcal, closeTo(105, 0.001));
      expect(n.protein, closeTo(21, 0.001));
      expect(n.carbs, closeTo(4.8, 0.001));
      expect(n.fat, closeTo(0.3, 0.001));
      expect(n.sodium, closeTo(54, 0.001));
    });
  });
}
