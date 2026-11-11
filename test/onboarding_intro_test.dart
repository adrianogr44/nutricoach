import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/app.dart';
import 'package:nutricoach_ai/core/theme/app_theme.dart';
import 'package:nutricoach_ai/data/repositories/local_store.dart';
import 'package:nutricoach_ai/features/onboarding/onboarding_intro_screen.dart';
import 'package:nutricoach_ai/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('primeiro acesso mostra a introdução antes do onboarding de bio',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const NutriCoachApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding-intro')), findsOneWidget);
    expect(find.text('Seu dia em um só lugar'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();

    // Pular a introdução não bloqueia o app: segue para o onboarding real.
    expect(find.text('Seu corpo em dados'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_intro_seen'), isTrue);
  });

  testWidgets('percorrer a introdução marca como vista e persiste',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final state = AppState(await LocalStore.open());
    await state.init();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const OnboardingIntroScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding-next')), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Anotar é rápido'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Foco no exercício atual'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Cinco áreas, sem labirinto'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-finish')), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-finish')));
    await tester.pumpAndSettle();

    expect(state.onboardingIntroSeen, isTrue);
    final reloaded = AppState(await LocalStore.open());
    await reloaded.init();
    expect(reloaded.onboardingIntroSeen, isTrue);
  });

  testWidgets('introdução pode ser revista sem alterar o fluxo atual',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final state = AppState(await LocalStore.open());
    await state.init();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const OnboardingIntroScreen(review: true),
                    ),
                  ),
                  child: const Text('Abrir introdução'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir introdução'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('onboarding-intro')), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();

    // Em modo revisão, apenas fecha e volta para onde o usuário estava.
    expect(find.byKey(const Key('onboarding-intro')), findsNothing);
    expect(find.text('Abrir introdução'), findsOneWidget);
  });
}
