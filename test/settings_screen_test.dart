import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/core/theme/app_theme.dart';
import 'package:nutricoach_ai/data/models/body_track.dart';
import 'package:nutricoach_ai/data/models/user_profile.dart';
import 'package:nutricoach_ai/data/repositories/local_store.dart';
import 'package:nutricoach_ai/features/settings/settings_screen.dart';
import 'package:nutricoach_ai/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _seededState() async {
  SharedPreferences.setMockInitialValues({});
  final state = AppState(await LocalStore.open());
  await state.init();
  await state.saveProfile(
    const UserProfile(
      name: 'Ana',
      pesoAtualKg: 72,
      pesoDesejadoKg: 66,
      alturaCm: 168,
      idade: 31,
      sexo: Sexo.feminino,
      objetivo: Objetivo.emagrecer,
      nivelAtividade: NivelAtividade.moderado,
      metaCalorica: 1900,
      metaProteina: 120,
      metaAguaMl: 2500,
    ),
  );
  final today = DateTime.now();
  await state.addWeight(
    WeightRecord(
      date: today.subtract(const Duration(days: 2)),
      weightKg: 72.6,
    ),
  );
  await state.addWeight(WeightRecord(date: today, weightKg: 72));
  return state;
}

void main() {
  testWidgets('perfil e ajustes organiza todas as áreas com funções reais',
      (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = await _seededState();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Perfil e ajustes'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.textContaining('Emagrecer'), findsWidgets);
    expect(find.text('Editar perfil e metas'), findsOneWidget);

    for (final section in [
      'Seu corpo',
      'Alimentação',
      'Treino e evolução',
      'Integrações',
      'Ajuda e preferências',
    ]) {
      expect(find.text(section), findsOneWidget);
    }

    for (final item in [
      'Peso',
      'Medidas e fotos',
      'Bioimpedância',
      'Minha dieta',
      'Banco de alimentos',
      'Minha ficha de treino',
      'Histórico e evolução',
      'Saúde e dispositivos',
      'Armazenamento e sincronização',
      'Rever introdução',
      'Sobre o NutriCoach IA',
    ]) {
      expect(find.text(item), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('rever introdução abre e fecha sem sair dos ajustes',
      (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = await _seededState();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Rever introdução'));
    await tester.tap(find.text('Rever introdução'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding-intro')), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();

    expect(find.text('Perfil e ajustes'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-intro')), findsNothing);
  });

  testWidgets('sobre o app informa versão e privacidade', (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = await _seededState();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Sobre o NutriCoach IA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sobre o NutriCoach IA'));
    await tester.pumpAndSettle();

    expect(find.text('Versão 1.0.0'), findsOneWidget);
    expect(find.textContaining('Privacidade'), findsOneWidget);
    expect(find.text('Fechar'), findsOneWidget);
  });
}
