import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/core/theme/app_theme.dart';
import 'package:nutricoach_ai/data/models/training.dart';
import 'package:nutricoach_ai/data/repositories/local_store.dart';
import 'package:nutricoach_ai/features/training/training_home.dart';
import 'package:nutricoach_ai/features/training/training_stats.dart';
import 'package:nutricoach_ai/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────── fixtures ───────────────────────────

/// Plano A/B/C com 2 exercícios por dia (4 séries por dia).
/// `weekday: null` mantém o "hoje" fixo no primeiro dia em qualquer data.
Map<String, Object> _seedPlan() => {
      'training_plans': jsonEncode([
        {
          'id': 'p1',
          'name': 'Força A',
          'isActive': true,
          'days': [
            {
              'id': 'd1',
              'name': 'A - Peito e Tríceps',
              'exercises': [
                {'id': 'e1', 'name': 'Supino reto', 'sets': 2, 'repsMin': 8, 'repsMax': 10, 'loadKg': 40, 'restSeconds': 0},
                {'id': 'e2', 'name': 'Tríceps corda', 'sets': 2, 'repsMin': 10, 'repsMax': 12, 'loadKg': 20, 'restSeconds': 0},
              ],
            },
            {
              'id': 'd2',
              'name': 'B - Costas',
              'exercises': [
                {'id': 'e3', 'name': 'Remada curvada', 'sets': 2, 'repsMin': 8, 'repsMax': 10, 'loadKg': 50, 'restSeconds': 0},
              ],
            },
            {
              'id': 'd3',
              'name': 'C - Pernas',
              'exercises': [
                {'id': 'e4', 'name': 'Agachamento', 'sets': 2, 'repsMin': 6, 'repsMax': 8, 'restSeconds': 0, 'loadKg': 60},
              ],
            },
          ],
        },
      ]),
      'active_training_plan_id': 'p1',
      'training_sessions': '[]',
    };

Map<String, Object> _seedWithSession(Map<String, dynamic> session) => {
      ..._seedPlan(),
      'training_sessions': jsonEncode([session]),
    };

Map<String, dynamic> _completedSession({
  String id = 's1',
  String dayId = 'd1',
  String date = '2026-10-06T08:00:00.000',
  List<Map<String, dynamic>> exercises = const [],
}) =>
    {
      'id': id,
      'planId': 'p1',
      'dayId': dayId,
      'date': date,
      'startAt': date,
      'endAt': '2026-10-06T08:50:00.000',
      'exercises': exercises,
      'status': 'completed',
    };

Map<String, dynamic> _activeSession({String id = 's-ongoing', String date = '2026-10-07T08:00:00.000'}) => {
      'id': id,
      'planId': 'p1',
      'dayId': 'd1',
      'date': date,
      'startAt': date,
      'exercises': [
        {
          // e1 planejado com 2 séries → exercício concluído (1 de 2 do dia).
          'exerciseId': 'e1',
          'sets': [
            {'weight': 40, 'reps': 8, 'completedAt': date},
            {'weight': 40, 'reps': 9, 'completedAt': date},
          ],
        },
      ],
      'status': 'active',
    };

Future<AppState> _state(Map<String, Object> seed) async {
  SharedPreferences.setMockInitialValues(seed);
  final state = AppState(await LocalStore.open());
  await state.init();
  return state;
}

/// Reabre o mesmo armazenamento (novo objeto AppState, mesmo backing).
Future<AppState> _reopen() async {
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

/// Avança a animação sem cair em `pumpAndSettle` (há timers de 1s).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
}

// ─────────────────────────── testes ───────────────────────────

void main() {
  testWidgets('sem plano de treino mostra o estado vazio com ação de criar', (tester) async {
    final state = await _state({'training_sessions': '[]'});
    await _pumpHome(tester, state);

    expect(find.byKey(const Key('create-training')), findsOneWidget);
    expect(find.textContaining('não possui um treino cadastrado'), findsOneWidget);
    expect(find.byKey(const Key('summary-card')), findsNothing);
  });

  testWidgets('plano A/B/C exibe as três divisões, resumo e consistência', (tester) async {
    final state = await _state(_seedPlan());
    await _pumpHome(tester, state);

    expect(find.byKey(const Key('division-card-0')), findsOneWidget);
    expect(find.byKey(const Key('division-card-1')), findsOneWidget);
    expect(find.byKey(const Key('division-card-2')), findsOneWidget);
    expect(find.byKey(const Key('summary-card')), findsOneWidget);
    expect(find.byKey(const Key('consistency-grid')), findsOneWidget);
    expect(find.textContaining('C - Pernas'), findsWidgets);
    expect(find.byKey(const Key('start-training')), findsOneWidget);
  });

  testWidgets('iniciar treino cria uma sessão ativa e abre a tela de execução', (tester) async {
    final state = await _state(_seedPlan());
    await _pumpHome(tester, state);

    await tester.tap(find.byKey(const Key('start-training')));
    await _settle(tester);

    expect(state.trainingSessions, hasLength(1));
    expect(state.activeTrainingSession, isNotNull);
    expect(find.byKey(const Key('progress-card')), findsOneWidget);
    expect(find.byKey(const Key('exercise-e1')), findsOneWidget);
  });

  testWidgets('registrar as séries de um exercício conclui 50% do treino', (tester) async {
    final state = await _state(_seedPlan());
    await _pumpHome(tester, state);

    await tester.tap(find.byKey(const Key('start-training')));
    await _settle(tester);

    expect(find.textContaining('0%'), findsWidgets);

    // Série 1 de 2 do primeiro exercício: ainda não conclui o exercício.
    await tester.enterText(find.byKey(const Key('set-kg-e1-1')), '42.5');
    await tester.enterText(find.byKey(const Key('set-reps-e1-1')), '8');
    await tester.tap(find.byKey(const Key('set-confirm-e1-1')));
    await _settle(tester);

    expect(TrainingStats.setsFor(state.trainingSessions.first, 'e1'), hasLength(1));
    expect(find.textContaining('0%'), findsWidgets);

    // Série 2 de 2 → 1 de 2 exercícios concluídos = 50%.
    await tester.enterText(find.byKey(const Key('set-kg-e1-2')), '42.5');
    await tester.enterText(find.byKey(const Key('set-reps-e1-2')), '8');
    await tester.tap(find.byKey(const Key('set-confirm-e1-2')));
    await _settle(tester);

    final session = state.trainingSessions.first;
    final sets = TrainingStats.setsFor(session, 'e1');
    expect(sets, hasLength(2));
    expect(sets.first.weight, 42.5);

    expect(find.textContaining('50%'), findsWidgets);
    expect(find.textContaining('01 / 02'), findsWidgets);
  });

  testWidgets('série registrada sobrevive à reabertura do estado', (tester) async {
    final state = await _state(_seedPlan());
    await _pumpHome(tester, state);

    await tester.tap(find.byKey(const Key('start-training')));
    await _settle(tester);

    await tester.enterText(find.byKey(const Key('set-kg-e1-1')), '40');
    await tester.enterText(find.byKey(const Key('set-reps-e1-1')), '10');
    await tester.tap(find.byKey(const Key('set-confirm-e1-1')));
    await _settle(tester);

    final reopened = await _reopen();

    expect(reopened.trainingSessions, hasLength(1));
    final sets = TrainingStats.setsFor(reopened.trainingSessions.first, 'e1');
    expect(sets, hasLength(1));
    expect(sets.first.weight, 40);
    expect(sets.first.reps, 10);
    expect(reopened.activeTrainingSession, isNotNull);
  });

  testWidgets('sessão ativa não permite iniciar uma duplicata', (tester) async {
    final state = await _state(_seedWithSession(_activeSession()));
    await _pumpHome(tester, state);

    expect(find.byKey(const Key('active-session-banner')), findsOneWidget);
    expect(find.byKey(const Key('start-training')), findsNothing);

    await tester.tap(find.byKey(const Key('continue-training')));
    await _settle(tester);

    expect(find.byKey(const Key('progress-card')), findsOneWidget);
    expect(state.trainingSessions, hasLength(1));
  });

  testWidgets('progresso da sessão ativa reflete as séries registradas', (tester) async {
    final state = await _state(_seedWithSession(_activeSession()));
    await _pumpHome(tester, state);

    // Banner: e1 concluído (2 de 2) → 1 de 2 exercícios do dia.
    expect(find.textContaining('1/2 exercícios'), findsOneWidget);

    await tester.tap(find.byKey(const Key('continue-training')));
    await _settle(tester);

    expect(find.textContaining('50%'), findsWidgets);
    expect(find.textContaining('01 / 02'), findsWidgets);
    // O exercício e2 está pendente e abre por padrão.
    expect(find.byKey(const Key('set-confirm-e2-1')), findsOneWidget);
  });

  testWidgets('finalizar treino marca a sessão como concluída', (tester) async {
    final state = await _state(_seedPlan());
    await _pumpHome(tester, state);

    await tester.tap(find.byKey(const Key('start-training')));
    await _settle(tester);

    // Registra as 2 séries do primeiro exercício.
    for (var set = 1; set <= 2; set++) {
      await tester.enterText(find.byKey(Key('set-kg-e1-$set')), '40');
      await tester.enterText(find.byKey(Key('set-reps-e1-$set')), '8');
      await tester.tap(find.byKey(Key('set-confirm-e1-$set')));
      await _settle(tester);
    }

    await tester.tap(find.widgetWithText(TextButton, 'Finalizar'));
    await _settle(tester);

    // Ainda há exercícios incompletos → diálogo de confirmação.
    expect(find.text('Finalizar treino?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Finalizar'));
    await _settle(tester);

    expect(state.trainingSessions.first.status, TrainingStatus.completed);
    expect(find.text('TREINO CONCLUÍDO'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Concluir'));
    await _settle(tester);

    expect(state.activeTrainingSession, isNull);
    expect(find.byKey(const Key('progress-card')), findsNothing);
    expect(find.byKey(const Key('start-training')), findsOneWidget);
  });

  testWidgets('histórico lista as sessões concluídas com o nome do treino', (tester) async {
    final state = await _state(
      _seedWithSession(
        _completedSession(
          exercises: [
            {
              'exerciseId': 'e1',
              'sets': [
                {'weight': 40, 'reps': 8, 'completedAt': '2026-10-06T08:30:00.000'},
                {'weight': 40, 'reps': 8, 'completedAt': '2026-10-06T08:35:00.000'},
              ],
            },
          ],
        ),
      ),
    );
    await _pumpHome(tester, state);

    await tester.tap(find.byKey(const Key('tab-historico')));
    await _settle(tester);

    expect(find.byKey(const Key('history-empty')), findsNothing);
    expect(find.textContaining('sessões concluídas'), findsOneWidget);
    expect(find.text('A - Peito e Tríceps'), findsOneWidget);

    // Expandindo a sessão: volume = 40 kg × 8 reps × 2 séries = 640 kg.
    await tester.tap(find.text('A - Peito e Tríceps'));
    await _settle(tester);
    expect(find.textContaining('VOLUME 640 KG'), findsOneWidget);
    expect(find.textContaining('Supino reto'), findsWidgets);
  });

  testWidgets('histórico vazio explica que nada foi concluído ainda', (tester) async {
    final state = await _state(_seedPlan());
    await _pumpHome(tester, state);

    await tester.tap(find.byKey(const Key('tab-historico')));
    await _settle(tester);

    expect(find.byKey(const Key('history-empty')), findsOneWidget);
    expect(find.textContaining('Nenhum treino concluído'), findsOneWidget);
  });

  testWidgets('sessão incompleta reaparece ao recriar o estado', (tester) async {
    final seed = _seedWithSession(_activeSession());
    final state = await _state(seed);
    expect(state.activeTrainingSession, isNotNull);

    // Mesmo backing, novo objeto AppState.
    final reopened = await _reopen();
    expect(reopened.activeTrainingSession, isNotNull);
    expect(reopened.activeTrainingSession!.id, 's-ongoing');
    expect(TrainingStats.setsFor(reopened.activeTrainingSession!, 'e1'), hasLength(2));

    await _pumpHome(tester, reopened);
    expect(find.byKey(const Key('active-session-banner')), findsOneWidget);
    expect(find.byKey(const Key('start-training')), findsNothing);
  });

  testWidgets('trocar de plano na ficha troca o plano ativo', (tester) async {
    final seed = _seedPlan();
    final plans = jsonDecode(seed['training_plans'] as String) as List;
    plans.add({
      'id': 'p2',
      'name': 'Força B',
      'isActive': false,
      'days': [
        {
          'id': 'd9',
          'name': 'Único',
          'exercises': [
            {'id': 'e9', 'name': 'Levantamento terra', 'sets': 3, 'repsMin': 5, 'repsMax': 5, 'loadKg': 80, 'restSeconds': 0},
          ],
        },
      ],
    });
    final state = await _state({...seed, 'training_plans': jsonEncode(plans)});
    await _pumpHome(tester, state);

    await tester.tap(find.byTooltip('Trocar plano'));
    await _settle(tester);
    expect(find.text('Trocar plano'), findsOneWidget);

    await tester.tap(find.text('Força B'));
    await _settle(tester);

    expect(state.activeTrainingPlan?.id, 'p2');
    expect(find.textContaining('Único'), findsWidgets);
    expect(find.textContaining('Força A'), findsNothing);
  });

  testWidgets('com apenas um plano, trocar plano avisa em vez de abrir a lista', (tester) async {
    final state = await _state(_seedPlan());
    await _pumpHome(tester, state);

    await tester.tap(find.byTooltip('Trocar plano'));
    await _settle(tester);

    expect(find.text('Você tem apenas um plano de treino.'), findsOneWidget);
    expect(find.text('Trocar plano'), findsNothing);
    expect(state.activeTrainingPlan?.id, 'p1');
  });
}
