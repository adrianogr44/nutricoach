import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/core/theme/app_theme.dart';
import 'package:nutricoach_ai/data/models/training.dart';
import 'package:nutricoach_ai/data/repositories/local_store.dart';
import 'package:nutricoach_ai/features/training/training_home.dart';
import 'package:nutricoach_ai/services/training_transfer.dart';
import 'package:nutricoach_ai/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────── fixtures ───────────────────────────

TrainingPlan _plan({String id = 'plano-1', String name = 'Força A'}) => TrainingPlan(
      id: id,
      name: name,
      createdAt: DateTime(2026, 1, 5),
      updatedAt: DateTime(2026, 1, 6),
      days: [
        TrainingDay(
          id: 'd1',
          name: 'A - Peito',
          weekday: 1,
          time: '19:00',
          exercises: [
            ExerciseDef(
              id: 'e1',
              name: 'Supino reto',
              muscleGroup: 'Peito',
              sets: 4,
              repsMin: 8,
              repsMax: 10,
              loadKg: 40,
              restSeconds: 90,
              notes: 'desça devagar',
            ),
            ExerciseDef(id: 'e2', name: 'Crucifixo', sets: 3, repsMin: 12, repsMax: 15, loadKg: 14),
          ],
        ),
        TrainingDay(
          id: 'd2',
          name: 'B - Costas',
          exercises: [
            ExerciseDef(id: 'e3', name: 'Remada curvada', sets: 4, repsMin: 6, repsMax: 8, loadKg: 55, order: 2),
          ],
        ),
      ],
    );

Future<AppState> _makeState() async {
  SharedPreferences.setMockInitialValues({});
  final state = AppState(await LocalStore.open());
  await state.init();
  return state;
}

Future<void> _pumpHome(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(900, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const TrainingHomeScreen(),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Finder _dialogField() => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );

// ─────────────────────────── testes ───────────────────────────

void main() {
  group('TrainingTransfer', () {
    test('export -> decode preserva plano, dias e exercícios', () {
      final original = _plan();
      final decoded = TrainingTransfer.decode(TrainingTransfer.export(original));

      expect(decoded.id, original.id);
      expect(decoded.name, 'Força A');
      expect(decoded.createdAt, original.createdAt);
      expect(decoded.updatedAt, original.updatedAt);
      expect(decoded.days, hasLength(2));

      final d1 = decoded.days.first;
      expect(d1.id, 'd1');
      expect(d1.name, 'A - Peito');
      expect(d1.weekday, 1);
      expect(d1.time, '19:00');
      expect(d1.exercises, hasLength(2));

      final e1 = d1.exercises.first;
      expect(e1.id, 'e1');
      expect(e1.name, 'Supino reto');
      expect(e1.muscleGroup, 'Peito');
      expect(e1.sets, 4);
      expect(e1.repsMin, 8);
      expect(e1.repsMax, 10);
      expect(e1.loadKg, 40);
      expect(e1.restSeconds, 90);
      expect(e1.notes, 'desça devagar');
      expect(e1.order, 0);

      expect(decoded.days.last.exercises.single.order, 2);
      expect(decoded.days.last.totalExercises, 1);
      expect(decoded.days.last.totalSets, 4);
    });

    test('export usa envelope de formato e versão', () {
      final decoded = jsonDecode(TrainingTransfer.export(_plan())) as Map<String, dynamic>;
      expect(decoded['format'], 'nutricoach-treino');
      expect(decoded['version'], 1);
      expect(decoded['plan'], isA<Map<String, dynamic>>());
      expect(TrainingTransfer.fileName, 'nutricoach-treino.json');
    });

    test('recusa conteúdo vazio', () {
      expect(
        () => TrainingTransfer.decode('   '),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('Cole o JSON do treino'))),
      );
    });

    test('recusa JSON inválido com mensagem amigável', () {
      expect(
        () => TrainingTransfer.decode('{qualquer'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('não é um JSON válido'))),
      );
    });

    test('recusa JSON que não é um objeto', () {
      expect(
        () => TrainingTransfer.decode('[1, 2, 3]'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('estrutura de um treino'))),
      );
    });

    test('recusa JSON de outro formato (ex.: dieta)', () {
      final other = jsonEncode({'format': 'nutricoach-dieta', 'version': 1, 'plan': <String, dynamic>{}});
      expect(
        () => TrainingTransfer.decode(other),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('não é um treino exportado'))),
      );
    });

    test('recusa versão de arquivo futura', () {
      final future = jsonEncode({'format': 'nutricoach-treino', 'version': 99, 'plan': <String, dynamic>{}});
      expect(
        () => TrainingTransfer.decode(future),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('Versão do arquivo não suportada'))),
      );
    });

    test('recusa arquivo sem a ficha', () {
      final missing = jsonEncode({'format': 'nutricoach-treino', 'version': 1});
      expect(
        () => TrainingTransfer.decode(missing),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('não contém nenhuma ficha'))),
      );
    });

    test('recusa ficha sem dias', () {
      final withoutDays = jsonEncode({
        'format': 'nutricoach-treino',
        'version': 1,
        'plan': {'id': 'p', 'name': 'Vazio', 'days': []},
      });
      expect(
        () => TrainingTransfer.decode(withoutDays),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('nenhum dia de treino'))),
      );
    });
  });

  group('AppState.importTrainingPlan', () {
    test('importa a ficha e torna o plano ativo', () async {
      final state = await _makeState();
      final imported = await state.importTrainingPlan(TrainingTransfer.export(_plan()));

      expect(state.trainingPlans, hasLength(1));
      expect(state.activeTrainingPlan?.id, imported.id);
      expect(state.activeTrainingPlan?.days, hasLength(2));
      expect(imported.name, 'Força A');
    });

    test('importar duas vezes não duplica (idempotente)', () async {
      final state = await _makeState();
      final json = TrainingTransfer.export(_plan());
      await state.importTrainingPlan(json);
      final second = await state.importTrainingPlan(json);

      expect(state.trainingPlans, hasLength(1));
      expect(second.id, state.trainingPlans.single.id);
    });

    test('substitui a ficha existente com o mesmo id', () async {
      final state = await _makeState();
      await state.importTrainingPlan(TrainingTransfer.export(_plan()));

      final updated = _plan().copyWith(name: 'Força A v2');
      await state.importTrainingPlan(TrainingTransfer.export(updated));

      expect(state.trainingPlans, hasLength(1));
      expect(state.trainingPlans.single.name, 'Força A v2');
      expect(state.activeTrainingPlan?.name, 'Força A v2');
    });

    test('gera id novo quando o arquivo não traz id', () async {
      final state = await _makeState();
      final json = TrainingTransfer.export(_plan(id: ''));
      final imported = await state.importTrainingPlan(json);

      expect(imported.id, isNotEmpty);
      expect(state.trainingPlans.single.id, imported.id);
      expect(state.activeTrainingPlan?.id, imported.id);
    });

    test('propaga FormatException sem alterar o estado', () async {
      final state = await _makeState();
      await state.importTrainingPlan(TrainingTransfer.export(_plan()));

      await expectLater(state.importTrainingPlan('lixo'), throwsA(isA<FormatException>()));

      expect(state.trainingPlans, hasLength(1));
      expect(state.trainingPlans.single.id, 'plano-1');
      expect(state.activeTrainingPlan?.id, 'plano-1');
    });

    test('a ficha importada sobrevive à reabertura do estado', () async {
      final state = await _makeState();
      await state.importTrainingPlan(TrainingTransfer.export(_plan()));

      final reopened = AppState(await LocalStore.open());
      await reopened.init();

      expect(reopened.trainingPlans, hasLength(1));
      expect(reopened.activeTrainingPlan?.days, hasLength(2));
      expect(reopened.activeTrainingPlan?.days.first.exercises, hasLength(2));
    });
  });

  group('Tela do Treino — exportar/importar', () {
    testWidgets('estado vazio oferece importar treino', (tester) async {
      final state = await _makeState();
      await _pumpHome(tester, state);

      expect(find.byKey(const Key('create-training')), findsOneWidget);
      expect(find.byKey(const Key('import-training-empty')), findsOneWidget);

      await tester.tap(find.byKey(const Key('import-training-empty')));
      await _settle(tester);

      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Importar treino')), findsOneWidget);
      expect(_dialogField(), findsOneWidget);
      expect(find.text('Escolher arquivo'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Importar'), findsOneWidget);
    });

    testWidgets('colar JSON e importar cria as divisões', (tester) async {
      final state = await _makeState();
      await _pumpHome(tester, state);

      await tester.tap(find.byKey(const Key('import-training-empty')));
      await _settle(tester);

      await tester.enterText(_dialogField(), TrainingTransfer.export(_plan()));
      await tester.tap(find.widgetWithText(FilledButton, 'Importar'));
      await _settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(state.trainingPlans, hasLength(1));
      expect(find.byKey(const Key('division-card-0')), findsOneWidget);
      expect(find.byKey(const Key('division-card-1')), findsOneWidget);
      expect(find.byKey(const Key('summary-card')), findsOneWidget);
    });

    testWidgets('JSON inválido mostra o erro dentro do diálogo', (tester) async {
      final state = await _makeState();
      await _pumpHome(tester, state);

      await tester.tap(find.byKey(const Key('import-training-empty')));
      await _settle(tester);

      await tester.enterText(_dialogField(), '{quebrado');
      await tester.tap(find.widgetWithText(FilledButton, 'Importar'));
      await _settle(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('não é um JSON válido'), findsOneWidget);
      expect(state.trainingPlans, isEmpty);
    });

    testWidgets('aba Ficha oferece exportar e importar', (tester) async {
      final state = await _makeState();
      await state.importTrainingPlan(TrainingTransfer.export(_plan()));
      await _pumpHome(tester, state);

      await tester.tap(find.byKey(const Key('tab-ficha')));
      await _settle(tester);

      expect(find.byKey(const Key('export-training')), findsOneWidget);
      expect(find.byKey(const Key('import-training')), findsOneWidget);
      expect(find.textContaining('histórico de sessões fica neste dispositivo'), findsOneWidget);
    });

    testWidgets('exportar mostra o JSON com envelope do formato', (tester) async {
      final state = await _makeState();
      await state.importTrainingPlan(TrainingTransfer.export(_plan()));
      await _pumpHome(tester, state);

      await tester.tap(find.byKey(const Key('tab-ficha')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('export-training')));
      await _settle(tester);

      expect(find.text('Exportar treino'), findsOneWidget);
      expect(find.textContaining('Força A · 2 dias · 3 exercícios'), findsOneWidget);
      expect(find.textContaining('nutricoach-treino'), findsWidgets);
      expect(find.widgetWithText(FilledButton, 'Copiar'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Salvar'), findsOneWidget);
    });

    testWidgets('exportar inacessível sem plano; estado vazio não quebra', (tester) async {
      final state = await _makeState();
      await _pumpHome(tester, state);

      expect(find.byKey(const Key('export-training')), findsNothing);
      expect(find.byKey(const Key('tab-ficha')), findsNothing);
      expect(find.textContaining('não possui um treino cadastrado'), findsOneWidget);
    });
  });
}
