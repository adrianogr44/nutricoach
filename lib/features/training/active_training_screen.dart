import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/training.dart';
import '../../state/app_state.dart';
import '../../widgets/core_widgets.dart';
import 'exercise_video.dart';
import 'training_stats.dart';
import 'training_widgets.dart';

/// Sessão de treino — uma tela focada em um exercício por vez.
///
/// Cabeçalho com sessão, progresso e tempo; área 16:9 do vídeo; orientações;
/// tabela de séries editável; botão grande "CONCLUIR SÉRIE"; descanso
/// automático com cronômetro único e finalização com resumo.
///
/// A assinatura `{session, day}` é mantida: o Dashboard também abre esta tela.
class ActiveTrainingScreen extends StatefulWidget {
  const ActiveTrainingScreen({
    super.key,
    required this.session,
    required this.day,
  });
  final TrainingSession session;
  final TrainingDay day;

  @override
  State<ActiveTrainingScreen> createState() => _ActiveTrainingScreenState();
}

class _ActiveTrainingScreenState extends State<ActiveTrainingScreen> {
  /// Descanso em segundos — rebuild isolado no painel [RestTimerBar].
  final ValueNotifier<int> _restLeft = ValueNotifier(0);
  int _restTotal = 0;
  DateTime? _restDeadline;
  Timer? _restTimer;

  final _kg = TextEditingController();
  final _reps = TextEditingController();

  /// Exercício em foco (id). Nulo até o primeiro build.
  String? _focusId;

  /// Série concluída que está sendo editada (null = registro normal).
  int? _editingSet;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final session = _resolve(state);
    _focusId = _initialFocus(session);
    final exercise = _exerciseById(_focusId);
    if (exercise != null) _prefill(state, session, exercise);
  }

  @override
  void dispose() {
    _cancelRest();
    _restLeft.dispose();
    _kg.dispose();
    _reps.dispose();
    super.dispose();
  }

  // ───────────────────────────── sessão ─────────────────────────────

  TrainingSession _resolve(AppState state) {
    for (final s in state.trainingSessions) {
      if (s.id == widget.session.id) return s;
    }
    return widget.session;
  }

  String _letter(AppState state) {
    final plan = state.activeTrainingPlan;
    if (plan != null) {
      final idx = plan.days.indexWhere((d) => d.id == widget.day.id);
      if (idx >= 0) return TrainingDivisionCard.letterFor(widget.day, idx);
    }
    final name = widget.day.name.trim();
    return name.isEmpty ? 'A' : name[0].toUpperCase();
  }

  ExerciseDef? _exerciseById(String? id) {
    if (id == null) return null;
    for (final ex in widget.day.exercises) {
      if (ex.id == id) return ex;
    }
    return null;
  }

  String? _initialFocus(TrainingSession session) {
    if (widget.day.exercises.isEmpty) return null;
    final pending = TrainingStats.firstPendingIndex(session, widget.day);
    if (pending >= 0) return widget.day.exercises[pending].id;
    return widget.day.exercises.last.id;
  }

  ExerciseDef get _focus {
    final found = _exerciseById(_focusId);
    if (found != null) return found;
    return widget.day.exercises.first;
  }

  int get _focusIndex {
    final idx = widget.day.exercises.indexWhere((e) => e.id == _focus.id);
    return idx < 0 ? 0 : idx;
  }

  void _prefill(AppState state, TrainingSession session, ExerciseDef exercise) {
    final done = TrainingStats.setsFor(session, exercise.id);
    if (done.isNotEmpty) {
      final last = done.last;
      _kg.text = _formatWeight(last.weight);
      _reps.text = '${last.reps}';
      return;
    }
    final lastSets = TrainingStats.lastSetsFor(
      state.trainingSessions,
      exercise.id,
      currentSessionId: session.id,
    );
    final lastLoad = TrainingStats.lastLoad(lastSets);
    _kg.text = _formatWeight(lastLoad > 0 ? lastLoad : exercise.loadKg);
    _reps.text = lastSets.isNotEmpty
        ? '${lastSets.first.reps}'
        : '${exercise.repsMin}';
  }

  static String _formatWeight(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  void _moveFocus(int delta) {
    final target = _focusIndex + delta;
    if (target < 0 || target >= widget.day.exercises.length) return;
    final state = context.read<AppState>();
    final session = _resolve(state);
    setState(() {
      _focusId = widget.day.exercises[target].id;
      _editingSet = null;
    });
    _prefill(state, session, widget.day.exercises[target]);
  }

  /// Vai para o primeiro exercício com séries pendentes (a partir do atual).
  Future<void> _goToNextPending() async {
    final state = context.read<AppState>();
    final session = _resolve(state);
    final day = widget.day;

    int? next;
    for (var i = _focusIndex + 1; i < day.exercises.length; i++) {
      if (TrainingStats.setsFor(session, day.exercises[i].id).length <
          day.exercises[i].sets) {
        next = i;
        break;
      }
    }
    if (next == null) {
      for (var i = 0; i < day.exercises.length; i++) {
        if (TrainingStats.setsFor(session, day.exercises[i].id).length <
            day.exercises[i].sets) {
          next = i;
          break;
        }
      }
    }
    if (next == null) {
      await _finish();
      return;
    }
    final exercise = day.exercises[next];
    if (exercise.id == _focus.id) {
      setState(() => _editingSet = null);
      return;
    }
    setState(() {
      _focusId = exercise.id;
      _editingSet = null;
    });
    _prefill(state, session, exercise);
  }

  // ───────────────────────────── descanso ─────────────────────────────

  void _startRest(int seconds) {
    _restTimer?.cancel();
    _restTimer = null;
    if (seconds <= 0) {
      _restDeadline = null;
      _restTotal = 0;
      _restLeft.value = 0;
      return;
    }
    _restTotal = seconds;
    _restDeadline = DateTime.now().add(Duration(seconds: seconds));
    _restLeft.value = seconds;
    _restTimer = Timer.periodic(const Duration(seconds: 1), _tickRest);
  }

  void _tickRest(Timer timer) {
    final deadline = _restDeadline;
    if (deadline == null) {
      timer.cancel();
      _restTimer = null;
      return;
    }
    final left = deadline.difference(DateTime.now()).inSeconds;
    if (left <= 0) {
      _cancelRest();
      _restFinished();
    } else {
      _restLeft.value = left;
    }
  }

  void _adjustRest(int delta) {
    final next = (_restLeft.value + delta).clamp(0, 3600);
    if (next <= 0) {
      _cancelRest();
      return;
    }
    _restDeadline = DateTime.now().add(Duration(seconds: next));
    _restLeft.value = next;
    _restTimer ??= Timer.periodic(const Duration(seconds: 1), _tickRest);
  }

  void _skipRest() => _cancelRest();

  void _cancelRest() {
    _restTimer?.cancel();
    _restTimer = null;
    _restDeadline = null;
    _restTotal = 0;
    if (_restLeft.value != 0) _restLeft.value = 0;
  }

  void _restFinished() {
    HapticFeedback.lightImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.primary,
        content: Text(
          'Descanso concluído — pode ir para a próxima série',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: AppTheme.textOnPrimary,
          ),
        ),
      ),
    );
  }

  // ───────────────────────────── registro ─────────────────────────────

  double _parseWeight(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0;
  }

  Future<void> _confirm(ExerciseDef exercise) async {
    if (_saving) return;
    final state = context.read<AppState>();
    final session = _resolve(state);
    final sets = TrainingStats.setsFor(session, exercise.id);

    final weight = _parseWeight(_kg.text);
    final reps = int.tryParse(_reps.text.trim()) ?? 0;
    if (reps <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe as repetições para concluir a série.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (_editingSet != null && _editingSet! < sets.length) {
        final index = _editingSet!;
        await state.replaceSetInSession(
          widget.session.id,
          exercise.id,
          index,
          TrainingSet(weight: weight, reps: reps, completedAt: DateTime.now()),
        );
        if (!mounted) return;
        setState(() => _editingSet = null);
        HapticFeedback.selectionClick();
      } else {
        await state.addSetToSession(
          widget.session.id,
          exercise.id,
          TrainingSet(weight: weight, reps: reps, completedAt: DateTime.now()),
        );
        HapticFeedback.lightImpact();
        final now = TrainingStats.setsFor(_resolve(state), exercise.id).length;
        if (now >= exercise.sets) HapticFeedback.mediumImpact();
        _startRest(exercise.restSeconds);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _editSet(int index, TrainingSet set) {
    setState(() {
      _editingSet = index;
      _kg.text = _formatWeight(set.weight);
      _reps.text = '${set.reps}';
    });
  }

  void _cancelEdit() {
    final state = context.read<AppState>();
    final session = _resolve(state);
    setState(() => _editingSet = null);
    _prefill(state, session, _focus);
  }

  // ───────────────────────────── finalização ─────────────────────────────

  Future<void> _finish() async {
    final state = context.read<AppState>();
    final session = _resolve(state);
    final progress = TrainingStats.sessionProgress(session, widget.day);

    if (progress.done < progress.total) {
      final goOn = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          title: Text(
            'Finalizar treino?',
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800),
          ),
          content: Text(
            '${progress.total - progress.done} de ${progress.total} exercícios ainda não tiveram todas as séries registradas.',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: AppTheme.textSecondary,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continuar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Finalizar'),
            ),
          ],
        ),
      );
      if (goOn != true) return;
    }

    _cancelRest();
    final started = session.startAt ?? session.date;
    final duration = DateTime.now().difference(started).inMinutes;
    final volume = TrainingStats.sessionVolume(session);
    final sets = session.totalSets;
    final setsProg = TrainingStats.setsProgress(session, widget.day);

    await state.finishTrainingSession(widget.session.id);
    if (!mounted) return;
    HapticFeedback.mediumImpact();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.primaryMuted,
                borderRadius: BorderRadius.circular(AppTheme.radiusXs),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 20,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'TREINO CONCLUÍDO',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SummaryRow(label: 'Duração', value: '$duration min'),
            _SummaryRow(
              label: 'Exercícios',
              value: '${progress.done}/${progress.total}',
            ),
            _SummaryRow(
              label: 'Séries',
              value:
                  '$sets${setsProg.total > 0 ? ' de ${setsProg.total}' : ''}',
            ),
            _SummaryRow(
              label: 'Volume',
              value: '${volume.toStringAsFixed(0)} kg',
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Concluir'),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────── build ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = _resolve(state);
    final day = widget.day;

    if (day.exercises.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Treino'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Este dia não tem exercícios cadastrados.\nEdite a ficha para adicionar.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ),
      );
    }

    final focus = _focus;
    final index = _focusIndex;
    final sets = TrainingStats.setsFor(session, focus.id);
    final progress = TrainingStats.sessionProgress(session, day);
    final percent = (progress.fraction * 100).round();
    final setProgress = TrainingStats.setsProgress(session, day);
    final completed = sets.length >= focus.sets;
    final lastSets = TrainingStats.lastSetsFor(
      state.trainingSessions,
      focus.id,
      currentSessionId: session.id,
    );
    final hint = TrainingStats.progression(focus, lastSets);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TREINO ${_letter(state)}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              day.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _finish,
            child: Text(
              'Finalizar',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              key: const Key('progress-card'),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${progress.done.toString().padLeft(2, '0')} / ${progress.total.toString().padLeft(2, '0')}',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -1,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$percent%',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.schedule,
                        size: 14,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: _SessionTimer(sessionId: widget.session.id),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GradientBar(
                    progress: progress.total == 0
                        ? 0
                        : progress.done / progress.total,
                    color: AppTheme.primary,
                    height: 6,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${setProgress.done} de ${setProgress.total} séries · exercício ${index + 1} de ${day.exercises.length}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _FocusNavigator(
              index: index,
              total: day.exercises.length,
              onPrevious: index > 0 ? () => _moveFocus(-1) : null,
              onNext: index < day.exercises.length - 1
                  ? () => _moveFocus(1)
                  : null,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                children: [
                  ExerciseVideo(exercise: focus),
                  const SizedBox(height: 16),
                  Text(
                    focus.name,
                    key: Key('exercise-${focus.id}'),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      height: 1.15,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if ((focus.muscleGroup ?? '').trim().isNotEmpty)
                        _InfoPill(
                          icon: Icons.accessibility_new,
                          label: focus.muscleGroup!.trim(),
                        ),
                      _InfoPill(
                        icon: Icons.repeat_rounded,
                        label: '${focus.sets} séries',
                      ),
                      _InfoPill(
                        icon: Icons.format_list_numbered,
                        label: '${focus.repsLabel} reps',
                      ),
                      _InfoPill(
                        icon: Icons.timer_outlined,
                        label: '${focus.restSeconds}s',
                      ),
                    ],
                  ),
                  if ((focus.notes ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(color: AppTheme.border, width: 0.8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lightbulb_outline,
                            size: 16,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              focus.notes!.trim(),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (lastSets.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.history,
                          size: 14,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Última vez: ${lastSets.map((s) => '${_formatWeight(s.weight)} kg × ${s.reps}').join(' · ')}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (hint != ProgressionHint.first) ...[
                      const SizedBox(height: 4),
                      Text(
                        hint.label,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: hint == ProgressionHint.increase
                              ? AppTheme.primary
                              : hint == ProgressionHint.reduce
                              ? AppTheme.warning
                              : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 18),
                  _SetsCard(
                    exercise: focus,
                    sets: sets,
                    lastSets: lastSets,
                    editingIndex: _editingSet,
                    kgController: _kg,
                    repsController: _reps,
                    onEdit: _editSet,
                    onCancelEdit: _cancelEdit,
                    onConfirm: () => _confirm(focus),
                    saving: _saving,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use o lápis de uma série concluída para corrigir carga ou repetições.',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: AppTheme.textFaint,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: _restLeft,
              builder: (context, rest, _) => RestTimerBar(
                seconds: rest,
                totalSeconds: _restTotal,
                onAdjust: _adjustRest,
                onSkip: _skipRest,
              ),
            ),
            _PrimaryAction(
              editingSet: _editingSet,
              saving: _saving,
              exerciseCompleted: completed,
              allCompleted:
                  progress.total > 0 && progress.done >= progress.total,
              nextSetNumber: sets.length + 1,
              onPressed: _editingSet != null || !completed
                  ? () => _confirm(focus)
                  : _goToNextPending,
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── widgets ─────────────────────────────

class _SessionTimer extends StatefulWidget {
  const _SessionTimer({required this.sessionId});
  final String sessionId;
  @override
  State<_SessionTimer> createState() => _SessionTimerState();
}

class _SessionTimerState extends State<_SessionTimer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startAt = context.select<AppState, DateTime?>((s) {
      for (final sess in s.trainingSessions) {
        if (sess.id == widget.sessionId && sess.startAt != null) {
          return sess.startAt;
        }
      }
      return null;
    });
    final started = startAt ?? DateTime.now();
    final elapsed = DateTime.now().difference(started);
    final h = elapsed.inHours;
    final m = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final sec = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Text(
      h > 0 ? '$h:$m:$sec' : '$m:$sec',
      style: GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppTheme.textSecondary,
      ),
    );
  }
}

class _FocusNavigator extends StatelessWidget {
  const _FocusNavigator({
    required this.index,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  final int index;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          IconButton(
            key: const Key('previous-exercise'),
            onPressed: onPrevious,
            tooltip: 'Exercício anterior',
            iconSize: 22,
            icon: const Icon(Icons.chevron_left_rounded),
            color: AppTheme.textSecondary,
          ),
          Expanded(
            child: Text(
              'EXERCÍCIO ${index + 1} DE $total',
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          IconButton(
            key: const Key('next-exercise'),
            onPressed: onNext,
            tooltip: 'Próximo exercício',
            iconSize: 22,
            icon: const Icon(Icons.chevron_right_rounded),
            color: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: AppTheme.border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.textMuted),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tabela de séries do exercício em foco.
class _SetsCard extends StatelessWidget {
  const _SetsCard({
    required this.exercise,
    required this.sets,
    required this.lastSets,
    required this.editingIndex,
    required this.kgController,
    required this.repsController,
    required this.onEdit,
    required this.onCancelEdit,
    required this.onConfirm,
    required this.saving,
  });

  final ExerciseDef exercise;
  final List<TrainingSet> sets;
  final List<TrainingSet> lastSets;
  final int? editingIndex;
  final TextEditingController kgController;
  final TextEditingController repsController;
  final void Function(int index, TrainingSet set) onEdit;
  final VoidCallback onCancelEdit;
  final VoidCallback onConfirm;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final pendingIndex = sets.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border, width: 0.8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _Head('SÉRIE', flex: 2),
              _Head('CARGA (KG)', flex: 4, align: TextAlign.center),
              _Head('REPS', flex: 3, align: TextAlign.center),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < exercise.sets; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _SetRow(
              number: i + 1,
              registered: i < sets.length ? sets[i] : null,
              last: i < lastSets.length ? lastSets[i] : null,
              exercise: exercise,
              isEditing: editingIndex == i,
              isCurrent: i == pendingIndex && editingIndex == null,
              kgController: kgController,
              repsController: repsController,
              onEdit: i < sets.length ? () => onEdit(i, sets[i]) : null,
              onCancelEdit: onCancelEdit,
              onConfirm: onConfirm,
              saving: saving,
            ),
          ],
          if (exercise.sets == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Este exercício está sem séries definidas na ficha.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.label, {required this.flex, this.align = TextAlign.left});
  final String label;
  final int flex;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: align,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 9.5,
          color: AppTheme.textMuted,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.number,
    required this.registered,
    required this.last,
    required this.exercise,
    required this.isEditing,
    required this.isCurrent,
    required this.kgController,
    required this.repsController,
    required this.onEdit,
    required this.onCancelEdit,
    required this.onConfirm,
    required this.saving,
  });

  final int number;
  final TrainingSet? registered;
  final TrainingSet? last;
  final ExerciseDef exercise;
  final bool isEditing;
  final bool isCurrent;
  final TextEditingController kgController;
  final TextEditingController repsController;
  final VoidCallback? onEdit;
  final VoidCallback onCancelEdit;
  final VoidCallback onConfirm;
  final bool saving;

  bool get _editable => isEditing || isCurrent;

  @override
  Widget build(BuildContext context) {
    final done = registered != null && !isEditing;
    return AnimatedContainer(
      key: Key('set-row-$number'),
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppTheme.primaryMuted.withValues(alpha: 0.55)
            : (done ? AppTheme.backgroundElevated : Colors.transparent),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: isCurrent
              ? AppTheme.primary.withValues(alpha: 0.7)
              : Colors.transparent,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                if (done)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AppTheme.primary,
                  )
                else
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppTheme.primary
                          : AppTheme.surfaceLight,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$number',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: isCurrent
                            ? AppTheme.textOnPrimary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                if (editingIconVisible) ...[
                  const SizedBox(width: 2),
                  IconButton(
                    key: Key('set-cancel-edit-$number'),
                    onPressed: onCancelEdit,
                    icon: const Icon(Icons.close_rounded, size: 15),
                    color: AppTheme.textMuted,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 26,
                      minHeight: 26,
                    ),
                    padding: EdgeInsets.zero,
                    tooltip: 'Cancelar edição',
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: _editable
                ? _InputField(
                    key: Key('set-kg-${exercise.id}-$number'),
                    controller: kgController,
                    hint: last != null ? _format(last!.weight) : 'kg',
                  )
                : _ValueCell(
                    key: Key('set-value-kg-$number'),
                    text: registered != null
                        ? _format(registered!.weight)
                        : (last != null ? _format(last!.weight) : '—'),
                    muted: registered == null,
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: _editable
                ? _InputField(
                    key: Key('set-reps-${exercise.id}-$number'),
                    controller: repsController,
                    hint: '${exercise.repsMin}',
                    decimal: false,
                  )
                : _ValueCell(
                    key: Key('set-value-reps-$number'),
                    text: registered != null
                        ? '${registered!.reps}'
                        : '${exercise.repsMin}',
                    muted: registered == null,
                  ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: done
                ? IconButton(
                    key: Key('set-edit-$number'),
                    onPressed: onEdit,
                    tooltip: 'Editar série $number',
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: AppTheme.textMuted,
                  )
                : IconButton(
                    key: Key('set-confirm-${exercise.id}-$number'),
                    onPressed: saving || !(isCurrent || isEditing)
                        ? null
                        : onConfirm,
                    tooltip: 'Concluir série $number',
                    icon: Icon(
                      isCurrent || isEditing
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked,
                      size: 22,
                      color: isCurrent || isEditing
                          ? AppTheme.primary
                          : AppTheme.textFaint,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  bool get editingIconVisible => isEditing;

  static String _format(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }
}

class _ValueCell extends StatelessWidget {
  const _ValueCell({super.key, required this.text, this.muted = false});
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: muted ? AppTheme.textFaint : AppTheme.textPrimary,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    super.key,
    required this.controller,
    required this.hint,
    this.decimal = true,
  });
  final TextEditingController controller;
  final String hint;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            RegExp(decimal ? r'[0-9.,]' : r'[0-9]'),
          ),
        ],
        style: GoogleFonts.jetBrainsMono(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            color: AppTheme.textFaint,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 12,
          ),
          filled: true,
          fillColor: AppTheme.backgroundElevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXs),
            borderSide: const BorderSide(color: AppTheme.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXs),
            borderSide: const BorderSide(color: AppTheme.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXs),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.4),
          ),
        ),
      ),
    );
  }
}

/// Botão principal fixo no rodapé — sempre visível, alvo grande.
class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.editingSet,
    required this.saving,
    required this.exerciseCompleted,
    required this.allCompleted,
    required this.nextSetNumber,
    required this.onPressed,
  });

  final int? editingSet;
  final bool saving;
  final bool exerciseCompleted;
  final bool allCompleted;
  final int nextSetNumber;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final String label;
    final IconData icon;
    if (editingSet != null) {
      label = 'SALVAR SÉRIE ${editingSet! + 1}';
      icon = Icons.save_outlined;
    } else if (!exerciseCompleted) {
      label = 'CONCLUIR SÉRIE $nextSetNumber';
      icon = Icons.check_rounded;
    } else if (allCompleted) {
      label = 'FINALIZAR TREINO';
      icon = Icons.flag_rounded;
    } else {
      label = 'PRÓXIMO EXERCÍCIO';
      icon = Icons.arrow_forward_rounded;
    }

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: FilledButton.icon(
          key: const Key('primary-action'),
          onPressed: saving ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: AppTheme.textOnPrimary,
            disabledBackgroundColor: AppTheme.surfaceHover,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
          ),
          icon: Icon(icon, size: 22),
          label: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
