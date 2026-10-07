import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/data/models/training.dart';
import 'package:nutricoach_ai/features/training/training_stats.dart';

/// Referência fixa: quarta-feira, 07/10/2026.
final DateTime _today = DateTime(2026, 10, 7);

DateTime _daysAgo(int n) => DateTime(_today.year, _today.month, _today.day - n);

TrainingSession _session(
  String id, {
  required DateTime date,
  TrainingStatus status = TrainingStatus.completed,
  List<ExerciseSession> exercises = const [],
  DateTime? startAt,
}) {
  final start = startAt ?? DateTime(date.year, date.month, date.day, 8);
  return TrainingSession(
    id: id,
    planId: 'p1',
    dayId: 'd1',
    date: date,
    startAt: start,
    endAt: start.add(const Duration(minutes: 50)),
    exercises: exercises,
    status: status,
  );
}

ExerciseDef _def(String id, {int sets = 2, int repsMin = 8, int repsMax = 10}) =>
    ExerciseDef(id: id, name: 'Exercício $id', sets: sets, repsMin: repsMin, repsMax: repsMax);

TrainingSet _set(double weight, int reps) =>
    TrainingSet(weight: weight, reps: reps, completedAt: _today);

ExerciseSession _es(String id, List<TrainingSet> sets) =>
    ExerciseSession(exerciseId: id, sets: sets);

/// 8 exercícios de 1 série, quantas séries registradas (para progresso 0/8).
TrainingDay _dayOfEight() => TrainingDay(
      id: 'd1',
      name: 'A - Peito',
      exercises: [for (var i = 1; i <= 8; i++) _def('e$i', sets: 1)],
    );

TrainingSession _sessionWithSets(String id, DateTime date, int registered) {
  return _session(
    id,
    date: date,
    exercises: [
      for (var i = 1; i <= registered; i++) _es('e$i', [_set(40, 8)]),
    ],
  );
}

void main() {
  group('streak (sequência atual)', () {
    test('sem treinos concluídos = 0', () {
      expect(TrainingStats.streak([], now: _today), 0);
    });

    test('treino só de ontem mantém a sequência viva em 1', () {
      final sessions = [_session('s1', date: _daysAgo(1))];
      expect(TrainingStats.streak(sessions, now: _today), 1);
    });

    test('três dias consecutivos incluindo hoje = 3', () {
      final sessions = [
        _session('s1', date: _today),
        _session('s2', date: _daysAgo(1)),
        _session('s3', date: _daysAgo(2)),
      ];
      expect(TrainingStats.streak(sessions, now: _today), 3);
    });

    test('hoje treinado mas ontem não = 1 (não atravessa buraco)', () {
      final sessions = [
        _session('s1', date: _today),
        _session('s2', date: _daysAgo(2)),
      ];
      expect(TrainingStats.streak(sessions, now: _today), 1);
    });

    test('sequência quebrada não soma os dias anteriores', () {
      final sessions = [
        _session('s1', date: _today),
        _session('s2', date: _daysAgo(1)),
        _session('s3', date: _daysAgo(3)),
      ];
      expect(TrainingStats.streak(sessions, now: _today), 2);
    });

    test('sessão em andamento não conta para a sequência', () {
      final sessions = [
        _session('s1', date: _today, status: TrainingStatus.active),
      ];
      expect(TrainingStats.streak(sessions, now: _today), 0);
    });
  });

  group('bestStreak (recorde)', () {
    test('vazio = 0', () {
      expect(TrainingStats.bestStreak([]), 0);
    });

    test('maior corrida consecutiva do histórico', () {
      final sessions = [
        _session('s1', date: _daysAgo(0)),
        _session('s2', date: _daysAgo(1)),
        _session('s3', date: _daysAgo(2)),
        _session('s4', date: _daysAgo(5)),
        _session('s5', date: _daysAgo(6)),
      ];
      expect(TrainingStats.bestStreak(sessions), 3);
    });
  });

  group('weekCount (semana civil)', () {
    test('conta apenas seg..dom da semana de referência', () {
      // 07/10/2026 é quarta: a semana vai de 05/10 (seg) a 11/10 (dom).
      final sessions = [
        _session('s1', date: DateTime(2026, 10, 5)), // segunda
        _session('s2', date: _today),                 // quarta
        _session('s3', date: DateTime(2026, 10, 4)), // domingo anterior: fora
        _session('s4', date: DateTime(2026, 10, 12)), // segunda seguinte: fora
        _session('s5', date: DateTime(2026, 10, 6), status: TrainingStatus.active), // fora
      ];
      expect(TrainingStats.weekCount(sessions, now: _today), 2);
    });
  });

  group('consistencyGrid', () {
    test('12 semanas, célula de hoje treinado e dias futuros', () {
      final grid = TrainingStats.consistencyGrid(
        [_session('s1', date: _today)],
        now: _today,
      );
      expect(grid.length, 12);
      expect(grid.every((column) => column.length == 7), isTrue);
      // Última semana: segunda 05/10 .. domingo 11/10.
      // Hoje (quarta, 07/10) = índice 2.
      expect(grid.last[2], TrainingDayCell.trained);
      expect(grid.last[0], TrainingDayCell.rest); // segunda sem treino
      expect(grid.last[3], TrainingDayCell.future); // quinta ainda não chegou
    });

    test('sessão em dia anterior marca treino na semana certa', () {
      // 29/09/2026 (terça) fica na semana iniciada em 28/09 = penúltima coluna.
      final grid = TrainingStats.consistencyGrid(
        [_session('s1', date: DateTime(2026, 9, 29))],
        now: _today,
      );
      expect(grid[10][1], TrainingDayCell.trained);
      expect(grid[11][1], TrainingDayCell.rest);
    });

    test('sessão em andamento não pinta a célula', () {
      final grid = TrainingStats.consistencyGrid(
        [_session('s1', date: _today, status: TrainingStatus.active)],
        now: _today,
      );
      expect(grid.last[2], TrainingDayCell.rest);
    });
  });

  group('sessionProgress (0% · 50% · 100%)', () {
    final day = _dayOfEight();

    test('nenhum exercício completo = 0/8 e 0%', () {
      final p = TrainingStats.sessionProgress(_session('s1', date: _today), day);
      expect(p.done, 0);
      expect(p.total, 8);
      expect(p.fraction, 0.0);
    });

    test('quatro de oito = 4/8 e 50%', () {
      final p = TrainingStats.sessionProgress(_sessionWithSets('s1', _today, 4), day);
      expect(p.done, 4);
      expect(p.total, 8);
      expect(p.fraction, 0.5);
    });

    test('oito de oito = 8/8 e 100%', () {
      final p = TrainingStats.sessionProgress(_sessionWithSets('s1', _today, 8), day);
      expect(p.done, 8);
      expect(p.total, 8);
      expect(p.fraction, 1.0);
    });

    test('série parcial não conta o exercício como concluído', () {
      final day = TrainingDay(id: 'dp', name: 'Parcial', exercises: [_def('e1', sets: 2)]);
      final session = _session(
        's1',
        date: _today,
        exercises: [
          // e1 planejado com 2 séries, só 1 registrada
          _es('e1', [_set(40, 8)]),
        ],
      );
      final p = TrainingStats.sessionProgress(session, day);
      expect(p.done, 0);
      expect(p.total, 1);
      expect(p.fraction, 0.0);
    });
  });

  group('lastSetsFor / lastSessionWith (último treino)', () {
    final older = _session(
      's-old',
      date: _daysAgo(7),
      exercises: [_es('e1', [_set(30, 8), _set(30, 8)])],
    );
    final recent = _session(
      's-new',
      date: _daysAgo(2),
      exercises: [_es('e1', [_set(35, 8), _set(35, 9)])],
    );

    test('devolve as séries da sessão anterior mais recente', () {
      final last = TrainingStats.lastSetsFor([older, recent], 'e1');
      expect(last, hasLength(2));
      expect(TrainingStats.lastLoad(last), 35);
    });

    test('exclui a própria sessão em andamento', () {
      final current = _session(
        's-current',
        date: _today,
        status: TrainingStatus.active,
        exercises: [_es('e1', [_set(99, 10)])],
      );
      final last = TrainingStats.lastSetsFor(
        [current, recent, older],
        'e1',
        currentSessionId: 's-current',
      );
      expect(TrainingStats.lastLoad(last), 35);
    });

    test('sessão ativa nunca serve de referência', () {
      final active = _session(
        's-active',
        date: _today,
        status: TrainingStatus.active,
        exercises: [_es('e1', [_set(99, 10)])],
      );
      final last = TrainingStats.lastSetsFor([active, older], 'e1');
      expect(TrainingStats.lastLoad(last), 30);
    });

    test('primeira vez não tem referência', () {
      expect(TrainingStats.lastSetsFor([recent], 'e2'), isEmpty);
      expect(TrainingStats.lastSessionWith([recent], 'e2'), isNull);
    });

    test('lastSessionWith devolve a sessão anterior com registro', () {
      final s = TrainingStats.lastSessionWith([older, recent], 'e1');
      expect(s?.id, 's-new');
    });
  });

  group('sessionProgress e volume', () {
    test('volume soma kg × reps de todas as séries', () {
      final session = _session(
        's1',
        date: _today,
        exercises: [
          _es('e1', [_set(40, 10), _set(40, 10)]),
          _es('e2', [_set(20, 12)]),
        ],
      );
      expect(TrainingStats.sessionVolume(session), 40 * 10 + 40 * 10 + 20 * 12);
      expect(session.totalSets, 3);
    });
  });

  group('progression (sugestão determinística)', () {
    test('sem registro anterior = primeira sessão', () {
      expect(
        TrainingStats.progression(_def('e1'), []),
        ProgressionHint.first,
      );
    });

    test('todas as séries no topo da faixa = pode aumentar', () {
      final last = [_set(40, 10), _set(40, 10)]; // repsMax = 10
      expect(
        TrainingStats.progression(_def('e1'), last),
        ProgressionHint.increase,
      );
    });

    test('alguma série abaixo do mínimo = considerar reduzir', () {
      final last = [_set(40, 10), _set(40, 6)]; // repsMin = 8
      expect(
        TrainingStats.progression(_def('e1'), last),
        ProgressionHint.reduce,
      );
    });

    test('dentro da faixa = manter a carga', () {
      final last = [_set(40, 9), _set(40, 9)];
      expect(
        TrainingStats.progression(_def('e1'), last),
        ProgressionHint.maintain,
      );
    });
  });

  group('achievements (derivadas do histórico real)', () {
    test('histórico vazio mantém tudo bloqueado', () {
      final list = TrainingStats.achievements([], now: _today);
      expect(list, hasLength(8));
      expect(list.every((a) => !a.unlocked), isTrue);
      expect(list.firstWhere((a) => a.id == 'first').progress, 0);
    });

    test('primeiro treino destrava a conquista first', () {
      final list = TrainingStats.achievements(
        [_session('s1', date: _today, startAt: DateTime(2026, 10, 7, 7, 30))],
        now: _today,
      );
      expect(list.firstWhere((a) => a.id == 'first').unlocked, isTrue);
      expect(list.firstWhere((a) => a.id == 'ten').unlocked, isFalse);
      expect(list.firstWhere((a) => a.id == 'early').unlocked, isTrue);
      expect(list.firstWhere((a) => a.id == 'night').unlocked, isFalse);
    });

    test('sequência de 7 dias destrava streak7', () {
      final sessions = [
        for (var i = 0; i < 7; i++) _session('s$i', date: _daysAgo(i)),
      ];
      final list = TrainingStats.achievements(sessions, now: _today);
      expect(list.firstWhere((a) => a.id == 'streak7').unlocked, isTrue);
      expect(list.firstWhere((a) => a.id == 'ten').progress, 7);
    });

    test('meta semanal cheia destrava fullweek', () {
      final sessions = [
        for (var i = 0; i < 4; i++) _session('s$i', date: DateTime(2026, 10, 5 + i)),
      ];
      final list =
          TrainingStats.achievements(sessions, weeklyTarget: 4, now: _today);
      expect(list.firstWhere((a) => a.id == 'fullweek').unlocked, isTrue);
    });

    test('sessão noturna destrava night', () {
      final list = TrainingStats.achievements(
        [_session('s1', date: _today, startAt: DateTime(2026, 10, 7, 19, 45))],
        now: _today,
      );
      expect(list.firstWhere((a) => a.id == 'night').unlocked, isTrue);
    });
  });

  group('completedCount / completedDays', () {
    test('conta só sessões concluídas e normaliza as datas', () {
      final sessions = [
        _session('s1', date: _today),
        _session('s2', date: _daysAgo(1)),
        _session('s3', date: _today), // mesmo dia: não duplica
        _session('s4', date: _daysAgo(3), status: TrainingStatus.active), // não conta
      ];
      expect(TrainingStats.completedCount(sessions), 3);
      expect(TrainingStats.completedDays(sessions), hasLength(2));
    });
  });
}
