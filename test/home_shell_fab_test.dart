import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/core/theme/app_theme.dart';
import 'package:nutricoach_ai/data/repositories/local_store.dart';
import 'package:nutricoach_ai/shell/home_shell.dart';
import 'package:nutricoach_ai/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regressão: o FAB "+" estava centerDocked, exatamente sobre o item central
/// da barra (Treino) — impossível clicar na aba no mobile.
Future<AppState> _makeState() async {
  SharedPreferences.setMockInitialValues({});
  final state = AppState(await LocalStore.open());
  await state.init();
  return state;
}

Future<void> _pump(WidgetTester tester, AppState state, Size size) async {
  tester.view.physicalSize = size;
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

Finder _navIcon(IconData icon) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.byIcon(icon));

void main() {
  testWidgets('Mobile: FAB fica acima da barra e abre o sheet', (tester) async {
    final state = await _makeState();
    await _pump(tester, state, const Size(390, 844));

    expect(tester.takeException(), isNull);
    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);

    final fabRect = tester.getRect(fab);
    final navRect = tester.getRect(find.byType(NavigationBar));
    expect(fabRect.overlaps(navRect), isFalse);
    expect(fabRect.bottom, lessThanOrEqualTo(navRect.top));
    expect(fabRect.left, greaterThanOrEqualTo(0));
    expect(fabRect.right, lessThanOrEqualTo(390));
    expect(fabRect.top, greaterThanOrEqualTo(0));

    await tester.tap(fab);
    await tester.pumpAndSettle();
    expect(find.text('Adicionar refeição'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mobile: FAB não bloqueia nenhuma das 5 abas', (tester) async {
    final state = await _makeState();
    await _pump(tester, state, const Size(390, 844));

    const activeIcons = [
      Icons.home,
      Icons.restaurant_menu,
      Icons.fitness_center,
      Icons.calendar_month,
      Icons.lightbulb,
    ];

    final destinations = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byType(NavigationDestination),
    );
    expect(destinations, findsNWidgets(5));

    for (var i = 0; i < activeIcons.length; i++) {
      await tester.tap(destinations.at(i));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_navIcon(activeIcons[i]), findsOneWidget, reason: 'aba $i não respondeu ao toque');
    }
  });

  testWidgets('Desktop: sem FAB, ação no header', (tester) async {
    final state = await _makeState();
    await _pump(tester, state, const Size(1400, 900));

    expect(tester.takeException(), isNull);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Registrar'), findsOneWidget);
  });
}
