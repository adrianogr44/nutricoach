import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/core/theme/app_theme.dart';
import 'package:nutricoach_ai/data/models/diet.dart';
import 'package:nutricoach_ai/data/models/food.dart';
import 'package:nutricoach_ai/data/models/meal.dart';
import 'package:nutricoach_ai/data/repositories/local_store.dart';
import 'package:nutricoach_ai/services/household_measure.dart';
import 'package:nutricoach_ai/shell/home_shell.dart';
import 'package:nutricoach_ai/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regressão: ao registrar uma refeição a section "Hoje" não pode estourar
/// (NoSuchMethodError em receptor dynamic quebra o build e o Flutter renderiza
/// a ErrorWidget cinza de 100.000px dentro do ListView = barra infinita).
const _food = Food(
  id: 'arroz-branco',
  name: 'Arroz branco cozido',
  category: 'Cereais e grãos',
  kcal: 128,
  protein: 2.5,
  carbs: 28.1,
  fat: 0.2,
);

Future<AppState> _makeState() async {
  SharedPreferences.setMockInitialValues({});
  final state = AppState(await LocalStore.open());
  await state.init();
  return state;
}

Future<void> _pump(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const HomeShell(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double _maxScrollExtent(WidgetTester tester) {
  final scrollables = tester.stateList<ScrollableState>(find.byType(Scrollable));
  var max = 0.0;
  for (final s in scrollables) {
    if (s.position.maxScrollExtent > max) max = s.position.maxScrollExtent;
  }
  return max;
}

void main() {
  testWidgets('Hoje sem refeição: layout íntegro', (tester) async {
    final state = await _makeState();
    await _pump(tester, state);

    expect(tester.takeException(), isNull);
    expect(_maxScrollExtent(tester), lessThan(5000));
    expect(find.text('Nenhuma refeição ainda'), findsOneWidget);
  });

  testWidgets('Hoje com refeição registrada: sem barra de erro', (tester) async {
    final state = await _makeState();
    await state.addMeal(
      state.buildMeal(
        date: DateTime.now(),
        type: MealType.almoco,
        items: [const MealItem(food: _food, quantityGrams: 150)],
        rawText: '150g de arroz',
      ),
    );
    await _pump(tester, state);

    expect(tester.takeException(), isNull);
    expect(_maxScrollExtent(tester), lessThan(5000));
    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.text('Almoço'), findsWidgets);
    expect(find.textContaining('kcal'), findsWidgets);
  });

  testWidgets('Hoje com dieta + refeição extra: sem barra de erro', (tester) async {
    final state = await _makeState();
    final diet = await state.createDiet('Minha Dieta');
    final dm = await state.addDietMeal(diet.id, name: 'Almoço', time: '12:30');
    await state.addDietMealItem(
      diet.id,
      dm.id,
      DietMealItem(
        foodId: _food.id,
        quantity: 150,
        unit: MeasureUnit.g,
        foodSnapshot: _food,
      ),
    );
    await state.addMeal(
      state.buildMeal(
        date: DateTime.now(),
        type: MealType.lanche,
        items: [const MealItem(food: _food, quantityGrams: 50)],
        rawText: '50g de arroz',
      ),
    );
    await _pump(tester, state);

    expect(tester.takeException(), isNull);
    expect(_maxScrollExtent(tester), lessThan(5000));
    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.text('Extras do dia'), findsOneWidget);
  });
}
