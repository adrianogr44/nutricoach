import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/training.dart';
import '../../state/app_state.dart';
import '../../widgets/core_widgets.dart';
import 'training_stats.dart';
import 'training_widgets.dart';

/// Sessão ativa — progresso grande, lista de exercícios com expansão inline,
/// registro por série, descanso automático e finalização com resumo.
///
/// A assinatura `{session, day}` é mantida: o Dashboard também abre esta tela.
class ActiveTrainingScreen extends StatefulWidget {
  const ActiveTrainingScreen({super.key, required this.session, required this.day});
  final TrainingSession session;
  final TrainingDay day;

  @override
  State<ActiveTrainingScreen> createState() => _ActiveTrainingScreenState();
}

class _ActiveTrainingScreenState extends State<ActiveTrainingScreen> {
  /// Descanso em segundos — o rebuild fica isolado na [RestTimerBar].
  final ValueNotifier<int> _restLeft = ValueNotifier(0);
  Timer? _restTimer;

  @override
  void dispose() {
    _restTimer?.cancel();
    _restLeft.dispose();
    super.dispose();
  }

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

  void _adjustRest(int delta) {
    final next = (_restLeft.value + delta).clamp(0, 3600);
    _restLeft.value = next;
    if (next <= 0) _restTimer?.cancel();
  }

  void _skipRest() {
    _restTimer?.cancel();
    _restLeft.value = 0;
  }

  void _restFinished() {
    _restLeft.value = 0;
    HapticFeedback.lightImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.primary,
        content: Text('Próxima série', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, color: AppTheme.textOnPrimary)),
      ),
    );
  }

  void _startRest(int seconds) {
    _restTimer?.cancel();
    _restLeft.value = seconds > 0 ? seconds : 0;
  }

  Future<void> _registerSet(ExerciseDef exercise, double weight, int reps) async {
    final state = context.read<AppState>();
    await state.addSetToSession(
      widget.session.id,
      exercise.id,
      TrainingSet(weight: weight, reps: reps, completedAt: DateTime.now()),
    );
    HapticFeedback.lightImpact();
    final done = TrainingStats.setsFor(_resolve(state), exercise.id).length;
    if (done >= exercise.sets) {
      HapticFeedback.mediumImpact();
    }
    _startRest(exercise.restSeconds);
  }

  Future<void> _finish() async {
    final state = context.read<AppState>();
    final session = _resolve(state);
    final progress = TrainingStats.sessionProgress(session, widget.day);

    if (progress.done < progress.total) {
      final goOn = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          title: Text('Finalizar treino?', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800)),
          content: Text(
            '${progress.total - progress.done} de ${progress.total} exercícios ainda não tiveram todas as séries registradas.',
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Continuar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Finalizar')),
          ],
        ),
      );
      if (goOn != true) return;
    }

    _restTimer?.cancel();
    _restLeft.value = 0;
    final started = session.startAt ?? session.date;
    final duration = DateTime.now().difference(started).inMinutes;
    final volume = TrainingStats.sessionVolume(session);
    final sets = session.totalSets;

    await state.finishTrainingSession(widget.session.id);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: Text('TREINO CONCLUÍDO', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800, letterSpacing: 0.6)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SummaryLine(label: 'Duração', value: '$duration min'),
            _SummaryLine(label: 'Exercícios', value: '${progress.done}/${progress.total}'),
            _SummaryLine(label: 'Séries', value: '$sets'),
            _SummaryLine(label: 'Volume', value: '${volume.toStringAsFixed(0)} kg'),
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final session = _resolve(state);
    final day = widget.day;
    final progress = TrainingStats.sessionProgress(session, day);
    final percent = (progress.fraction * 100).round();

    // exercício aberto por padrão: o primeiro ainda incompleto
    String? firstPendingId;
    for (final ex in day.exercises) {
      if (TrainingStats.setsFor(session, ex.id).length < ex.sets) {
        firstPendingId = ex.id;
        break;
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TREINO ${_letter(state)}', style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppTheme.textPrimary)),
            Text(day.name, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          Padding(padding: EdgeInsets.only(right: 6), child: _SessionTimer(sessionId: widget.session.id)),
          TextButton(onPressed: _finish, child: const Text('Finalizar')),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: _ProgressCard(
                    done: progress.done,
                    total: progress.total,
                    percent: percent,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      Text('EXERCÍCIOS', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w700, letterSpacing: 1)),
                      const SizedBox(height: 10),
                      for (var i = 0; i < day.exercises.length; i++)
                        _ExerciseWorkoutCard(
                          key: ValueKey('exercise-${day.exercises[i].id}'),
                          exercise: day.exercises[i],
                          index: i,
                          session: session,
                          allSessions: state.trainingSessions,
                          totalOf: day.exercises.length,
                          defaultOpen: day.exercises[i].id == firstPendingId,
                          onRegister: (w, r) => _registerSet(day.exercises[i], w, r),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: RestTimerBar(
                listenable: _restLeft,
                onAdjust: _adjustRest,
                onSkip: _skipRest,
                onFinished: _restFinished,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
          Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}

/// Timer decorrido da sessão — widget isolado para não rebuildar a tela.
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
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
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
        if (sess.id == widget.sessionId && sess.startAt != null) return sess.startAt;
      }
      return null;
    });
    final started = startAt ?? DateTime.now();
    final elapsed = DateTime.now().difference(started);
    final h = elapsed.inHours.toString().padLeft(2, '0');
    final m = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final sec = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Text('$h:$m:$sec', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary));
  }
}

/// Card grande de progresso: `03 / 08` + percentual + barra.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.done, required this.total, required this.percent});
  final int done;
  final int total;
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$done de $total exercícios concluídos, $percent por cento',
      child: Container(
        key: const Key('progress-card'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.surface, AppTheme.surfaceLight]),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.border, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    '${done.toString().padLeft(2, '0')} / ${total.toString().padLeft(2, '0')}',
                    style: GoogleFonts.spaceGrotesk(fontSize: 44, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -2, height: 0.95),
                  ),
                ),
                Text('$percent%', style: GoogleFonts.jetBrainsMono(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primary)),
              ],
            ),
            const SizedBox(height: 14),
            GradientBar(progress: done / (total == 0 ? 1 : total), color: AppTheme.primary, height: 8),
          ],
        ),
      ),
    );
  }
}

/// Card de exercício — estado pendente/em andamento/concluído, expansão
/// inline com a tabela de séries e registro por série.
class _ExerciseWorkoutCard extends StatefulWidget {
  const _ExerciseWorkoutCard({
    super.key,
    required this.exercise,
    required this.index,
    required this.session,
    required this.allSessions,
    required this.totalOf,
    required this.defaultOpen,
    required this.onRegister,
  });

  final ExerciseDef exercise;
  final int index;
  final TrainingSession session;
  final List<TrainingSession> allSessions;
  final int totalOf;
  final bool defaultOpen;
  final Future<void> Function(double weight, int reps) onRegister;

  @override
  State<_ExerciseWorkoutCard> createState() => _ExerciseWorkoutCardState();
}

class _ExerciseWorkoutCardState extends State<_ExerciseWorkoutCard> {
  late bool _open;
  late final TextEditingController _kg;
  late final TextEditingController _reps;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _open = widget.defaultOpen;
    final last = TrainingStats.lastSetsFor(widget.allSessions, widget.exercise.id, currentSessionId: widget.session.id);
    final prefilled = TrainingStats.lastLoad(last);
    _kg = TextEditingController(text: (prefilled > 0 ? prefilled : widget.exercise.loadKg).toStringAsFixed(0));
    _reps = TextEditingController(text: '${widget.exercise.repsMin}');
  }

  @override
  void dispose() {
    _kg.dispose();
    _reps.dispose();
    super.dispose();
  }

  List<TrainingSet> get _doneSets =>
      TrainingStats.setsFor(widget.session, widget.exercise.id);

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final sets = _doneSets;
    final doneCount = sets.length;
    final completed = doneCount >= exercise.sets;
    final last = TrainingStats.lastSetsFor(widget.allSessions, exercise.id, currentSessionId: widget.session.id);
    final hint = TrainingStats.progression(exercise, last);

    final color = completed ? AppTheme.primary : (_open ? AppTheme.borderStrong : AppTheme.border);

    return Semantics(
      label: '${exercise.name}, exercício ${widget.index + 1} de ${widget.totalOf}, '
          '$doneCount de ${exercise.sets} séries concluídas',
      button: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: completed ? AppTheme.primaryMuted.withValues(alpha: 0.5) : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: color, width: completed || _open ? 1.2 : 0.8),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Text(
                      (widget.index + 1).toString().padLeft(2, '0'),
                      style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: completed ? AppTheme.primary : AppTheme.textMuted),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exercise.name.toUpperCase(),
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: completed ? AppTheme.textSecondary : AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${exercise.sets} × ${exercise.repsLabel} · $doneCount/${exercise.sets} séries',
                            style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    if (completed)
                      const Icon(Icons.check_circle_rounded, size: 20, color: AppTheme.primary)
                    else if (_doneSets.isNotEmpty)
                      Icon(Icons.expand_less_rounded, size: 22, color: AppTheme.textMuted)
                    else
                      Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 22, color: AppTheme.textMuted),
                  ],
                ),
              ),
            ),
            if (_open) _buildDetail(sets, last, hint, completed),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail(List<TrainingSet> sets, List<TrainingSet> last, ProgressionHint hint, bool completed) {
    final exercise = widget.exercise;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.border, width: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.backgroundElevated, borderRadius: BorderRadius.circular(AppTheme.radiusXs)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ÚLTIMA SESSÃO', style: GoogleFonts.jetBrainsMono(fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(
                  last.isEmpty
                      ? 'Primeira vez'
                      : '${last.map((s) => s.weight.toStringAsFixed(0)).join('/')} kg · ${last.map((s) => s.reps).join('/')}',
                  style: GoogleFonts.jetBrainsMono(fontSize: 12, color: last.isEmpty ? AppTheme.textFaint : AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          if (hint != ProgressionHint.first) ...[
            const SizedBox(height: 8),
            Text(
              hint.label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: hint == ProgressionHint.increase
                    ? AppTheme.primary
                    : hint == ProgressionHint.reduce
                        ? AppTheme.warning
                        : AppTheme.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _SetHead(label: 'SÉRIE', flex: 2),
              _SetHead(label: 'ÚLTIMO', flex: 3),
              _SetHead(label: 'KG', flex: 2, align: TextAlign.center),
              _SetHead(label: 'REPS', flex: 2, align: TextAlign.center),
              const SizedBox(width: 32),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < exercise.sets; i++)
            _SetLine(
              number: i + 1,
              keyPrefix: exercise.id,
              registered: i < sets.length ? sets[i] : null,
              last: i < last.length ? last[i] : null,
              isCurrent: i == sets.length && !completed,
              kgController: _kg,
              repsController: _reps,
              saving: _saving,
              onConfirm: () async {
                final weight = double.tryParse(_kg.text.replaceAll(',', '.')) ?? 0;
                final reps = int.tryParse(_reps.text) ?? exercise.repsMin;
                setState(() => _saving = true);
                await widget.onRegister(weight, reps);
                if (mounted) setState(() => _saving = false);
              },
            ),
          if (completed) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text('Exercício concluído', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.primary)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SetHead extends StatelessWidget {
  const _SetHead({required this.label, required this.flex, this.align = TextAlign.left});
  final String label;
  final int flex;
  final TextAlign align;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(label, textAlign: align, style: GoogleFonts.jetBrainsMono(fontSize: 8, color: AppTheme.textFaint, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
    );
  }
}

/// Linha da tabela de série — registrada, atual (inputs) ou pendente.
class _SetLine extends StatelessWidget {
  const _SetLine({
    required this.number,
    required this.keyPrefix,
    required this.registered,
    required this.last,
    required this.isCurrent,
    required this.kgController,
    required this.repsController,
    required this.onConfirm,
    required this.saving,
  });

  final int number;
  final String keyPrefix;
  final TrainingSet? registered;
  final TrainingSet? last;
  final bool isCurrent;
  final TextEditingController kgController;
  final TextEditingController repsController;
  final Future<void> Function() onConfirm;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final lastLabel = last == null ? '—' : '${last!.weight.toStringAsFixed(0)}×${last!.reps}';

    if (registered != null) {
      return Semantics(
        label: 'Série $number concluída, ${registered!.weight.toStringAsFixed(0)} quilos, ${registered!.reps} repetições',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              _cell('$number', flex: 2, color: AppTheme.textMuted),
              _cell(lastLabel, flex: 3, color: AppTheme.textMuted),
              _cell(registered!.weight.toStringAsFixed(0), flex: 2, center: true, color: AppTheme.textPrimary),
              _cell('${registered!.reps}', flex: 2, center: true, color: AppTheme.textPrimary),
              const SizedBox(
                width: 32,
                height: 32,
                child: Icon(Icons.check_circle_rounded, size: 18, color: AppTheme.primary),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _cell('$number', flex: 2, color: isCurrent ? AppTheme.primary : AppTheme.textFaint),
          _cell(lastLabel, flex: 3, color: AppTheme.textMuted),
          Expanded(
            flex: 2,
            child: _input(kgController, Key('set-kg-$keyPrefix-$number'), 'kg'),
          ),
          Expanded(
            flex: 2,
            child: _input(repsController, Key('set-reps-$keyPrefix-$number'), 'reps'),
          ),
          SizedBox(
            width: 32,
            height: 36,
            child: IconButton(
              key: Key('set-confirm-$keyPrefix-$number'),
              padding: EdgeInsets.zero,
              iconSize: 22,
              onPressed: saving ? null : onConfirm,
              tooltip: 'Concluir série $number',
              icon: Icon(Icons.check_circle_outline_rounded, color: isCurrent ? AppTheme.primary : AppTheme.textFaint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _input(TextEditingController controller, Key key, String hint) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: SizedBox(
        height: 36,
        child: TextField(
          key: key,
          controller: controller,
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textFaint),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            filled: true,
            fillColor: AppTheme.backgroundElevated,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXs), borderSide: const BorderSide(color: AppTheme.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXs), borderSide: const BorderSide(color: AppTheme.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXs), borderSide: const BorderSide(color: AppTheme.primary)),
          ),
        ),
      ),
    );
  }

  Widget _cell(String text, {required int flex, bool center = false, required Color color}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.left,
        style: GoogleFonts.jetBrainsMono(fontSize: 12, color: color),
      ),
    );
  }
}
