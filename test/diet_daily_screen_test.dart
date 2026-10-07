import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/core/theme/app_theme.dart';
import 'package:nutricoach_ai/data/models/diet.dart';
import 'package:nutricoach_ai/data/models/meal.dart';
import 'package:nutricoach_ai/data/repositories/local_store.dart';
import 'package:nutricoach_ai/features/diet/diet_meal_daily_card.dart';
import 'package:nutricoach_ai/features/diet/diet_screen.dart';
import 'package:nutricoach_ai/services/household_measure.dart';
import 'package:nutricoach_ai/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _names = ['Café da manhã', 'Almoço', 'Lanche da tarde', 'Jantar', 'Ceia'];

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

Future<AppState> _makeState() async {
  SharedPreferences.setMockInitialValues({});
  final state = AppState(await LocalStore.open());
  await state.init();
  return state;
}

Future<void> _seed(AppState state) async {
  final diet = await state.createDiet('Minha Dieta');
  for (final name in _names) {
    final meal = await state.addDietMeal(diet.id, name: name);
    await state.addDietMealItem(
      diet.id,
      meal.id,
      const DietMealItem(foodId: 'arroz-branco', quantity: 150, unit: MeasureUnit.g),
    );
  }
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

/// Swipe horizontal real (passos curtos para o reconhecedor de gesto).
Future<void> _swipe(
  WidgetTester tester,
  Finder card,
  double dx, {
  Alignment startAt = Alignment.center,
}) async {
  final rect = tester.getRect(card);
  final origin = Offset(
    rect.left + rect.width * (startAt.x + 1) / 2,
    rect.top + rect.height * (startAt.y + 1) / 2,
  );
  const steps = 12;
  final gesture = await tester.startGesture(origin);
  for (var i = 1; i <= steps; i++) {
    await gesture.moveTo(origin + Offset(dx * i / steps, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Deixa o SnackBar (com seu Timer) terminar antes do fim do teste.
Future<void> _flushSnack(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

Finder _cardAt(int index) => find.byType(DietMealDailyCard).at(index);

void main() {
  testWidgets('Sem dieta: estado vazio orienta a criar a dieta', (tester) async {
    final state = await _makeState();
    await _pumpDiet(tester, state);

    expect(find.textContaining('Você ainda não possui uma dieta ativa.'), findsOneWidget);
    expect(find.text('Criar dieta'), findsOneWidget);
    expect(find.byType(DietMealDailyCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dieta do dia: 0 de 5 concluídas e primeira refeição é a próxima', (tester) async {
    final state = await _makeState();
    await _seed(state);
    await _pumpDiet(tester, state);

    expect(find.text('Dieta de hoje'), findsOneWidget);
    expect(find.text('0 de 5 refeições concluídas'), findsOneWidget);
    expect(find.byType(DietMealDailyCard), findsNWidgets(5));
    expect(
      find.descendant(of: _cardAt(0), matching: find.text('Próxima refeição')),
      findsOneWidget,
    );
    expect(find.text('Próxima refeição'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Alimentos e quantidades aparecem sem precisar tocar em nada', (tester) async {
    final state = await _makeState();
    await _seed(state);
    await _pumpDiet(tester, state);

    expect(find.text('150 g'), findsNWidgets(5));
    expect(find.text('Arroz branco cozido'), findsNWidgets(5));
    expect(find.text('Pendente'), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Após concluir uma refeição: 1 de 5 e a segunda vira a próxima', (tester) async {
    final state = await _makeState();
    await _seed(state);
    final first = state.activeDiet!.meals.first;
    await state.logDietMeal(dietMeal: first, date: _today());
    await _pumpDiet(tester, state);

    expect(find.text('1 de 5 refeições concluídas'), findsOneWidget);
    expect(find.text('Concluída'), findsOneWidget);
    expect(find.text('Próxima refeição'), findsOneWidget);
    expect(
      find.descendant(of: _cardAt(1), matching: find.text('Próxima refeição')),
      findsOneWidget,
    );
    expect(find.descendant(of: _cardAt(0), matching: find.text('Próxima refeição')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Refeição parcial não conta como concluída', (tester) async {
    final state = await _makeState();
    await _seed(state);
    final food = state.foodById('arroz-branco')!;
    await state.addMeal(
      Meal(
        id: 'manual-cafe',
        date: DateTime.now(),
        type: MealType.cafeDaManha,
        items: [MealItem(food: food, quantityGrams: 40)],
      ),
    );
    await _pumpDiet(tester, state);

    expect(find.text('0 de 5 refeições concluídas'), findsOneWidget);
    expect(find.text('Parcial'), findsOneWidget);
    expect(find.text('Concluída'), findsNothing);
    expect(
      find.descendant(of: _cardAt(0), matching: find.text('Próxima refeição')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Todas concluídas: 5 de 5 com confirmação de dia concluído', (tester) async {
    final state = await _makeState();
    await _seed(state);
    for (final meal in [...state.activeDiet!.meals]) {
      await state.logDietMeal(dietMeal: meal, date: _today());
    }
    await _pumpDiet(tester, state);

    expect(find.text('5 de 5 refeições concluídas'), findsOneWidget);
    expect(find.text('Dieta do dia concluída'), findsOneWidget);
    expect(find.text('Próxima refeição'), findsNothing);
    expect(find.text('Concluída'), findsNWidgets(5));
    expect(state.mealsOn(_today()), hasLength(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Swipe abaixo do threshold não registra nada', (tester) async {
    final state = await _makeState();
    await _seed(state);
    await _pumpDiet(tester, state);

    await _swipe(tester, _cardAt(0), 60);

    expect(state.mealsOn(_today()), isEmpty);
    expect(find.text('0 de 5 refeições concluídas'), findsOneWidget);
    expect(find.text('Concluída'), findsNothing);
    expect(find.text('Pendente'), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Swipe acima do threshold registra exatamente uma refeição', (tester) async {
    final state = await _makeState();
    await _seed(state);
    await _pumpDiet(tester, state);

    await _swipe(tester, _cardAt(0), 200);

    final logged = state.mealsOn(_today());
    expect(logged, hasLength(1));
    expect(logged.first.rawText, 'Dieta:${state.activeDiet!.meals.first.id}:Café da manhã');
    expect(find.text('1 de 5 refeições concluídas'), findsOneWidget);
    expect(find.text('Concluída'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _flushSnack(tester);
  });

  testWidgets('Swipe repetido na refeição já concluída não duplica o registro', (tester) async {
    final state = await _makeState();
    await _seed(state);
    await _pumpDiet(tester, state);

    await _swipe(tester, _cardAt(0), 200);
    await _swipe(tester, _cardAt(0), 200);
    await _swipe(tester, _cardAt(0), 200);

    expect(state.mealsOn(_today()), hasLength(1));
    expect(find.text('1 de 5 refeições concluídas'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _flushSnack(tester);
  });

  testWidgets('Registro feito por swipe sobrevive a um novo carregamento do estado', (tester) async {
    final state = await _makeState();
    await _seed(state);
    await _pumpDiet(tester, state);

    await _swipe(tester, _cardAt(0), 200);
    expect(state.mealsOn(_today()), hasLength(1));

    final reloaded = AppState(await LocalStore.open());
    await reloaded.init();
    final diet = reloaded.activeDiet!;
    expect(diet.meals, hasLength(5));
    expect(reloaded.dietMealStatusFor(_today(), diet.meals.first), 'consumed');
    expect(reloaded.mealsOn(_today()).first.rawText, 'Dieta:${diet.meals.first.id}:${diet.meals.first.name}');
    expect(tester.takeException(), isNull);
    await _flushSnack(tester);
  });

  testWidgets('Desfazer remove só o registro daquela refeição', (tester) async {
    final state = await _makeState();
    await _seed(state);
    final food = state.foodById('arroz-branco')!;
    await state.addMeal(
      Meal(
        id: 'manual-lanche',
        date: DateTime.now(),
        type: MealType.lanche,
        items: [MealItem(food: food, quantityGrams: 30)],
      ),
    );
    final first = state.activeDiet!.meals.first;
    await state.logDietMeal(dietMeal: first, date: _today());
    expect(state.mealsOn(_today()), hasLength(2));
    await _pumpDiet(tester, state);

    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();

    final restantes = state.mealsOn(_today());
    expect(restantes, hasLength(1));
    expect(restantes.first.rawText, isNull);
    expect(restantes.first.id, 'manual-lanche');
    expect(state.dietMealStatusFor(_today(), first), 'planned');
    expect(find.text('0 de 5 refeições concluídas'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _flushSnack(tester);
  });

  testWidgets('Após concluir por swipe, a próxima refeição fora da tela é trazida para a área visível', (tester) async {
    final state = await _makeState();
    await _seed(state);
    final meals = [...state.activeDiet!.meals];
    await state.logDietMeal(dietMeal: meals[0], date: _today());
    await state.logDietMeal(dietMeal: meals[1], date: _today());
    await _pumpDiet(tester, state);

    final scroll = find.descendant(of: find.byType(DietScreen), matching: find.byType(SingleChildScrollView)).first;
    final scrollBox = tester.renderObject(scroll) as RenderBox;
    double bottomOf(Finder card) {
      final box = tester.renderObject(card) as RenderBox;
      return box.localToGlobal(Offset.zero, ancestor: scrollBox).dy + box.size.height;
    }

    expect(
      bottomOf(_cardAt(3)),
      greaterThan(scrollBox.size.height),
      reason: 'a 4ª refeição deveria estar fora da tela antes do swipe',
    );

    // A 3ª refeição tem o topo visível: o gesto começa perto dele.
    await _swipe(tester, _cardAt(2), 200, startAt: const Alignment(0, -0.7));
    expect(state.mealsOn(_today()), hasLength(3));

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(
      bottomOf(_cardAt(3)),
      lessThanOrEqualTo(scrollBox.size.height),
      reason: 'a próxima refeição deveria ter sido trazida para a tela',
    );
    expect(tester.takeException(), isNull);
    await _flushSnack(tester);
  });

  testWidgets('Refeições seguem a ordem do plano (order), não a ordem do índice', (tester) async {
    final state = await _makeState();
    await _seed(state);
    final diet = state.activeDiet!;
    await state.updateDiet(diet.copyWith(meals: diet.meals.reversed.toList()));
    await _pumpDiet(tester, state);

    final cards = tester.widgetList<DietMealDailyCard>(find.byType(DietMealDailyCard)).toList();
    expect(cards, hasLength(5));
    expect(cards.map((c) => c.meal.name).toList(), _names);
    expect(tester.takeException(), isNull);
  });
}
