import '../../data/models/training.dart';

/// Regras derivadas da aba Treino — tudo determinístico, calculado apenas a
/// partir de [TrainingSession]s reais persistidas. Nada de contadores
/// manuais, pontos inventados ou IA.
///
/// Convenção de datas: sempre dias locais normalizados (ano, mês, dia).
class TrainingStats {
  const TrainingStats._();

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Dias locais com pelo menos uma sessão concluída.
  static Set<String> completedDays(Iterable<TrainingSession> sessions) {
    final days = <String>{};
    for (final s in sessions) {
      if (s.status == TrainingStatus.completed) days.add(_key(s.date));
    }
    return days;
  }

  /// Sequência atual: dias consecutivos com treino concluído, contando de
  /// hoje para trás. Se hoje ainda não houve treino mas ontem houve, a
  /// sequência continua valer (terminou ontem). Sem treino = 0.
  static int streak(Iterable<TrainingSession> sessions, {DateTime? now}) {
    final days = completedDays(sessions);
    var cursor = _day(now ?? DateTime.now());
    if (!days.contains(_key(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(_key(cursor))) return 0;
    }
    var count = 0;
    while (days.contains(_key(cursor))) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  /// Maior sequência já atingida em todo o histórico.
  static int bestStreak(Iterable<TrainingSession> sessions) {
    final days = completedDays(sessions);
    if (days.isEmpty) return 0;
    final dates = days.map(DateTime.parse).toList()..sort();
    var best = 1;
    var run = 1;
    for (var i = 1; i < dates.length; i++) {
      final gap = _day(dates[i]).difference(_day(dates[i - 1])).inDays;
      if (gap == 1) {
        run++;
        if (run > best) best = run;
      } else {
        run = 1;
      }
    }
    return best;
  }

  static int completedCount(Iterable<TrainingSession> sessions) =>
      sessions.where((s) => s.status == TrainingStatus.completed).length;

  /// Treinos concluídos na semana civil atual (segunda a domingo).
  static int weekCount(Iterable<TrainingSession> sessions, {DateTime? now}) {
    final reference = _day(now ?? DateTime.now());
    final startOfWeek = reference.subtract(Duration(days: reference.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    var count = 0;
    for (final s in sessions) {
      if (s.status != TrainingStatus.completed) continue;
      final d = _day(s.date);
      if (!d.isBefore(startOfWeek) && d.isBefore(endOfWeek)) count++;
    }
    return count;
  }

  /// Janela de consistência: [weeks] semanas civis terminando na semana
  /// atual, começando na segunda-feira. Cada célula é um dia local.
  static List<List<TrainingDayCell>> consistencyGrid(
    Iterable<TrainingSession> sessions, {
    int weeks = 12,
    DateTime? now,
  }) {
    final reference = _day(now ?? DateTime.now());
    final trained = completedDays(sessions);
    final startOfWeek = reference.subtract(Duration(days: reference.weekday - 1));
    final start = startOfWeek.subtract(Duration(days: 7 * (weeks - 1)));

    final grid = <List<TrainingDayCell>>[];
    for (var w = 0; w < weeks; w++) {
      final column = <TrainingDayCell>[];
      for (var d = 0; d < 7; d++) {
        final date = start.add(Duration(days: w * 7 + d));
        if (date.isAfter(reference)) {
          column.add(TrainingDayCell.future);
        } else if (trained.contains(_key(date))) {
          column.add(TrainingDayCell.trained);
        } else {
          column.add(TrainingDayCell.rest);
        }
      }
      grid.add(column);
    }
    return grid;
  }

  /// Progresso da sessão: exercício conta como concluído quando registrou
  /// todas as séries planejadas em [ExerciseDef.sets].
  static ({int done, int total, double fraction}) sessionProgress(
    TrainingSession session,
    TrainingDay day,
  ) {
    final total = day.exercises.length;
    var done = 0;
    for (final ex in day.exercises) {
      if (setsFor(session, ex.id).length >= ex.sets) done++;
    }
    final fraction = total == 0 ? 0.0 : done / total;
    return (done: done, total: total, fraction: fraction);
  }

  /// Séries já registradas para um exercício dentro da sessão.
  static List<TrainingSet> setsFor(TrainingSession session, String exerciseId) {
    for (final es in session.exercises) {
      if (es.exerciseId == exerciseId) return es.sets;
    }
    return const [];
  }

  /// Último desempenho do exercício: séries registradas na sessão anterior
  /// mais recente que tenha registro. [currentSessionId] é excluído para
  /// nunca devolver a própria sessão em andamento. Lista vazia = primeira vez.
  static List<TrainingSet> lastSetsFor(
    Iterable<TrainingSession> sessions,
    String exerciseId, {
    String? currentSessionId,
  }) {
    final ordered = sessions.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    for (final s in ordered) {
      if (s.id == currentSessionId) continue;
      if (s.status == TrainingStatus.active) continue;
      final sets = setsFor(s, exerciseId);
      if (sets.isNotEmpty) return sets;
    }
    return const [];
  }

  /// Sessão anterior (qualquer uma com registro do exercício) — usada para
  /// a linha "Último:" e para o pré-preenchimento de carga.
  static TrainingSession? lastSessionWith(
    Iterable<TrainingSession> sessions,
    String exerciseId, {
    String? currentSessionId,
  }) {
    final ordered = sessions.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    for (final s in ordered) {
      if (s.id == currentSessionId) continue;
      if (s.status == TrainingStatus.active) continue;
      if (setsFor(s, exerciseId).isNotEmpty) return s;
    }
    return null;
  }

  /// Volume total de uma lista de séries (kg × reps).
  static double volume(Iterable<TrainingSet> sets) =>
      sets.fold(0, (sum, s) => sum + s.weight * s.reps);

  /// Volume de uma sessão inteira.
  static double sessionVolume(TrainingSession session) {
    var total = 0.0;
    for (final es in session.exercises) {
      total += volume(es.sets);
    }
    return total;
  }

  /// Feedback de progressão comparando o desempenho anterior com a faixa
  /// planejada. Determinístico, sugestão apenas — nada é alterado sozinho.
  static ProgressionHint progression(ExerciseDef exercise, List<TrainingSet> last) {
    if (last.isEmpty) return ProgressionHint.first;
    final reps = last.map((s) => s.reps).toList();
    if (reps.every((r) => r >= exercise.repsMax)) return ProgressionHint.increase;
    if (reps.any((r) => r < exercise.repsMin)) return ProgressionHint.reduce;
    return ProgressionHint.maintain;
  }

  /// Carga usada na última sessão do exercício (0 quando é a primeira vez).
  static double lastLoad(Iterable<TrainingSet> sets) =>
      sets.isEmpty ? 0 : sets.map((s) => s.weight).reduce((a, b) => a > b ? a : b);

  /// Conquistas derivadas exclusivamente do histórico real.
  /// [weeklyTarget] = dias do plano (meta de uma semana completa).
  static List<Achievement> achievements(
    Iterable<TrainingSession> sessions, {
    int weeklyTarget = 4,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final done = sessions.where((s) => s.status == TrainingStatus.completed).toList();
    final count = done.length;
    final best = bestStreak(done);
    final trained = completedDays(done);

    var fullWeek = false;
    if (weeklyTarget > 0) {
      final referenceDay = _day(reference);
      var cursor = referenceDay.subtract(Duration(days: referenceDay.weekday - 1));
      for (var w = 0; w < 52 && !fullWeek; w++) {
        var inWeek = 0;
        for (var d = 0; d < 7; d++) {
          if (trained.contains(_key(cursor.add(Duration(days: d))))) inWeek++;
        }
        if (inWeek >= weeklyTarget) fullWeek = true;
        cursor = cursor.subtract(const Duration(days: 7));
      }
    }

    final trainedEarly = done.any((s) => (s.startAt ?? s.date).hour < 10);
    final trainedAtNight = done.any((s) => (s.startAt ?? s.date).hour >= 19);

    return [
      Achievement(
        id: 'first',
        title: 'Primeiro treino',
        detail: 'Completei a primeira sessão',
        unlocked: count >= 1,
        progress: count.clamp(0, 1),
        target: 1,
      ),
      Achievement(
        id: 'ten',
        title: '10 treinos',
        detail: 'Dez sessões concluídas',
        unlocked: count >= 10,
        progress: count.clamp(0, 10),
        target: 10,
      ),
      Achievement(
        id: 'fifty',
        title: '50 treinos',
        detail: 'Cinquenta sessões concluídas',
        unlocked: count >= 50,
        progress: count.clamp(0, 50),
        target: 50,
      ),
      Achievement(
        id: 'hundred',
        title: '100 treinos',
        detail: 'Cem sessões concluídas',
        unlocked: count >= 100,
        progress: count.clamp(0, 100),
        target: 100,
      ),
      Achievement(
        id: 'streak7',
        title: '7 dias seguidos',
        detail: 'Sequência de uma semana',
        unlocked: best >= 7,
        progress: best.clamp(0, 7),
        target: 7,
      ),
      Achievement(
        id: 'fullweek',
        title: 'Semana completa',
        detail: 'Meta semanal atingida',
        unlocked: fullWeek,
        progress: fullWeek ? 1 : 0,
        target: 1,
      ),
      Achievement(
        id: 'early',
        title: 'Treino cedo',
        detail: 'Sessão iniciada até 10h',
        unlocked: trainedEarly,
        progress: 1,
        target: 1,
      ),
      Achievement(
        id: 'night',
        title: 'Treino noturno',
        detail: 'Sessão iniciada a partir das 19h',
        unlocked: trainedAtNight,
        progress: 1,
        target: 1,
      ),
    ];
  }
}

/// Célula do grid de consistência.
enum TrainingDayCell { future, rest, trained }

/// Sugestão de progressão — nunca aplicada automaticamente.
enum ProgressionHint { first, increase, maintain, reduce }

extension ProgressionHintX on ProgressionHint {
  String get label => switch (this) {
        ProgressionHint.first => 'Primeira sessão',
        ProgressionHint.increase => '↑ Pode aumentar a carga',
        ProgressionHint.maintain => 'Mantenha a carga',
        ProgressionHint.reduce => '↓ Considere reduzir',
      };
}

/// Conquista derivada do histórico (sem gamificação: só reforço visual).
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.detail,
    required this.unlocked,
    required this.progress,
    required this.target,
  });

  final String id;
  final String title;
  final String detail;
  final bool unlocked;
  final int progress;
  final int target;
}
