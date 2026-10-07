import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/core/theme/app_theme.dart';
import 'package:nutricoach_ai/data/models/diet.dart';
import 'package:nutricoach_ai/data/models/food.dart';
import 'package:nutricoach_ai/data/repositories/local_store.dart';
import 'package:nutricoach_ai/features/diet/diet_screen.dart';
import 'package:nutricoach_ai/services/diet_transfer.dart';
import 'package:nutricoach_ai/services/household_measure.dart';
import 'package:nutricoach_ai/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _whey = Food(
  id: 'dark-whey-protein-concentrate',
  name: 'Whey Protein Concentrate — Dark Supplements',
  category: 'Suplementos',
  kcal: 350,
  protein: 70,
  carbs: 16,
  fat: 1,
  standardPortionGrams: 30,
  source: 'Rótulo do produto — Dark Supplements Whey Protein Concentrate',
);

DietPlan _plan({String id = 'plano-1'}) => DietPlan(
      id: id,
      name: 'Minha Dieta',
      createdAt: DateTime(2026, 1, 5),
      updatedAt: DateTime(2026, 1, 6),
      meals: [
        DietMeal(id: 'm1', name: 'Café da manhã', time: '07:30', order: 0, items: [
          const DietMealItem(foodId: 'dark-whey-protein-concentrate', quantity: 30, unit: MeasureUnit.g, foodSnapshot: _whey),
          const DietMealItem(foodId: 'banana', quantity: 1, unit: MeasureUnit.unidade),
        ]),
        DietMeal(id: 'm2', name: 'Almoço', time: '12:30', order: 1, items: [
          const DietMealItem(foodId: 'arroz-branco', quantity: 150, unit: MeasureUnit.g),
        ]),
      ],
    );

Future<AppState> _makeState() async {
  SharedPreferences.setMockInitialValues({});
  final state = AppState(await LocalStore.open());
  await state.init();
  return state;
}

Future<void> _pumpDiet(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(theme: AppTheme.dark(), home: const DietScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _appBarMenu() => find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(PopupMenuButton<String>),
    );

void main() {
  group('DietTransfer', () {
    test('export -> decode preserva plano, refeições e itens', () {
      final original = _plan();
      final restored = DietTransfer.decode(DietTransfer.export(original));

      expect(restored.id, original.id);
      expect(restored.name, 'Minha Dieta');
      expect(restored.meals.length, 2);
      expect(restored.meals.first.name, 'Café da manhã');
      expect(restored.meals.first.time, '07:30');
      expect(restored.meals.first.order, 0);
      expect(restored.meals.first.items.length, 2);

      final item = restored.meals.first.items.first;
      expect(item.foodId, 'dark-whey-protein-concentrate');
      expect(item.quantity, 30);
      expect(item.unit, MeasureUnit.g);
      expect(item.foodSnapshot, isNotNull);
      expect(item.foodSnapshot!.kcal, 350);
      expect(item.foodSnapshot!.protein, 70);
      expect(item.foodSnapshot!.standardPortionGrams, 30);
      expect(item.foodSnapshot!.source, contains('Dark Supplements'));

      final totals = restored.totalsWith({
        for (final f in [item.foodSnapshot!]) f.id: f,
      });
      expect(totals['kcal'], closeTo(105, 0.001));
    });

    test('export usa envelope de formato e versão', () {
      final json = DietTransfer.export(_plan());
      expect(json, contains('"format": "nutricoach-dieta"'));
      expect(json, contains('"version": 1'));
      expect(json, contains('dark-whey-protein-concentrate'));
    });

    test('recusa conteúdo vazio', () {
      expect(() => DietTransfer.decode('   '), throwsFormatException);
      expect(
        () => DietTransfer.decode(''),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('Cole o JSON'))),
      );
    });

    test('recusa JSON inválido com mensagem amigável', () {
      expect(
        () => DietTransfer.decode('não é json'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('JSON válido'))),
      );
    });

    test('recusa JSON que não é dieta exportada', () {
      expect(
        () => DietTransfer.decode('{"qualquer": 1}'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('NutriCoach'))),
      );
      expect(
        () => DietTransfer.decode('{"format":"outro","version":1,"diet":{}}'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('NutriCoach'))),
      );
    });

    test('recusa versão de arquivo futura', () {
      final raw = '{"format":"nutricoach-dieta","version":99,"diet":{"id":"x","name":"X","meals":[{"id":"m","name":"Almoço","items":[]}]}}';
      expect(
        () => DietTransfer.decode(raw),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('Versão'))),
      );
    });

    test('recusa dieta sem refeições', () {
      final raw = '{"format":"nutricoach-dieta","version":1,"diet":{"id":"x","name":"X","meals":[]}}';
      expect(
        () => DietTransfer.decode(raw),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('refeição'))),
      );
    });
  });

  group('AppState.importDiet', () {
    test('cria a dieta e torna a ativa', () async {
      final state = await _makeState();
      expect(state.activeDiet, isNull);

      final plan = await state.importDiet(DietTransfer.export(_plan()));

      expect(state.activeDiet, isNotNull);
      expect(state.activeDiet!.id, plan.id);
      expect(state.activeDiet!.name, 'Minha Dieta');
      expect(state.activeDiet!.meals.length, 2);
      expect(state.hasDiet, isTrue);
    });

    test('importar duas vezes não duplica (idempotente)', () async {
      final state = await _makeState();
      final raw = DietTransfer.export(_plan());

      await state.importDiet(raw);
      await state.importDiet(raw);

      expect(state.dietPlans.length, 1);
      expect(state.activeDiet!.meals.length, 2);
    });

    test('substitui dieta existente com o mesmo id', () async {
      final state = await _makeState();
      final created = await state.createDiet('Dieta antiga');
      expect(state.dietPlans.length, 1);

      await state.importDiet(DietTransfer.export(_plan(id: created.id)));

      expect(state.dietPlans.length, 1);
      expect(state.activeDiet!.id, created.id);
      expect(state.activeDiet!.name, 'Minha Dieta');
      expect(state.activeDiet!.meals.length, 2);
    });

    test('gera id novo quando o arquivo não traz id', () async {
      final state = await _makeState();
      final raw = '{"format":"nutricoach-dieta","version":1,"diet":{"name":"Sem id","meals":[{"id":"m","name":"Almoço","items":[]}]}}';

      final plan = await state.importDiet(raw);

      expect(plan.id, isNotEmpty);
      expect(state.dietPlans.length, 1);
      expect(state.activeDiet!.id, plan.id);
    });

    test('propaga FormatException sem alterar o estado', () async {
      final state = await _makeState();
      await expectLater(state.importDiet('arquivo errado'), throwsA(isA<FormatException>()));
      expect(state.dietPlans, isEmpty);
      expect(state.activeDiet, isNull);
    });
  });

  group('Tela da Dieta — exportar/importar', () {
    testWidgets('sem dieta, oferece importar além de criar', (tester) async {
      final state = await _makeState();
      await _pumpDiet(tester, state);

      expect(find.text('Crie sua dieta'), findsOneWidget);
      expect(find.text('Importar dieta'), findsOneWidget);
    });

    testWidgets('com dieta, o menu traz exportar e importar', (tester) async {
      final state = await _makeState();
      await state.importDiet(DietTransfer.export(_plan()));
      await _pumpDiet(tester, state);

      await tester.tap(_appBarMenu());
      await tester.pumpAndSettle();

      expect(find.text('Exportar dieta'), findsOneWidget);
      expect(find.text('Importar dieta'), findsOneWidget);
      expect(find.text('Apagar dieta'), findsOneWidget);
    });

    testWidgets('exportar mostra o JSON da dieta', (tester) async {
      final state = await _makeState();
      await state.importDiet(DietTransfer.export(_plan()));
      await _pumpDiet(tester, state);

      await tester.tap(_appBarMenu());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exportar dieta'));
      await tester.pumpAndSettle();

      expect(find.text('Exportar dieta'), findsWidgets);
      expect(find.textContaining('"format": "nutricoach-dieta"'), findsOneWidget);
      expect(find.textContaining('Minha Dieta · 2 refeições'), findsOneWidget);
    });

    testWidgets('importar colando JSON traz a dieta para o dispositivo', (tester) async {
      final state = await _makeState();
      final json = DietTransfer.export(_plan());
      await _pumpDiet(tester, state);
      expect(state.activeDiet, isNull);

      await tester.tap(find.text('Importar dieta'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, json);
      await tester.tap(find.text('Importar'));
      await tester.pumpAndSettle();

      expect(state.activeDiet, isNotNull);
      expect(state.activeDiet!.meals.length, 2);
      expect(find.text('Café da manhã'), findsOneWidget);
      expect(find.text('Almoço'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('importar JSON inválido mostra o erro sem quebrar', (tester) async {
      final state = await _makeState();
      await _pumpDiet(tester, state);

      await tester.tap(find.text('Importar dieta'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'conteúdo errado');
      await tester.tap(find.text('Importar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('JSON válido'), findsOneWidget);
      expect(state.activeDiet, isNull);
    });
  });
}
