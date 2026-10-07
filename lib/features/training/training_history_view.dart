import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/training.dart';
import '../../state/app_state.dart';
import 'training_stats.dart';

/// Aba Histórico — só sessões reais de [AppState.trainingSessions],
/// com a evolução carga a carga por exercício.
class TrainingHistoryView extends StatefulWidget {
  const TrainingHistoryView({super.key});

  @override
  State<TrainingHistoryView> createState() => _TrainingHistoryViewState();
}

class _TrainingHistoryViewState extends State<TrainingHistoryView> {
  String? _exerciseId;
  String? _openSessionId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final plan = state.activeTrainingPlan;
    final sessions = state.trainingSessions
        .where((s) => s.status == TrainingStatus.completed)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (sessions.isEmpty) {
      return Container(
        key: const Key('history-empty'),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border, width: 0.8),
        ),
        child: Center(
          child: Text(
            'Nenhum treino concluído ainda.\nSeu histórico aparece aqui após a primeira sessão.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
          ),
        ),
      );
    }

    final exercises = _allExercises(plan);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('${sessions.length}', style: GoogleFonts.jetBrainsMono(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primary)),
            const SizedBox(width: 8),
            Text('sessões concluídas', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
          ],
        ),
        const SizedBox(height: 16),
        if (exercises.isNotEmpty) ...[
          _SectionLabel('Evolução por exercício'),
          const SizedBox(height: 10),
          _ExerciseEvolution(
            exercises: exercises,
            sessions: sessions,
            selectedId: _exerciseId ?? exercises.first.id,
            onChanged: (id) => setState(() => _exerciseId = id),
          ),
          const SizedBox(height: 24),
        ],
        _SectionLabel('Sessões'),
        const SizedBox(height: 10),
        for (final session in sessions)
          _SessionTile(
            session: session,
            plan: plan,
            expanded: _openSessionId == session.id,
            onTap: () => setState(() => _openSessionId = _openSessionId == session.id ? null : session.id),
          ),
      ],
    );
  }

  List<ExerciseDef> _allExercises(TrainingPlan? plan) {
    if (plan == null) return const [];
    final seen = <String>{};
    final list = <ExerciseDef>[];
    for (final day in plan.days) {
      for (final ex in day.exercises) {
        if (seen.add(ex.id)) list.add(ex);
      }
    }
    return list;
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w700, letterSpacing: 1),
    );
  }
}

/// Histórico de um exercício: carga máxima por sessão, em ordem cronológica.
class _ExerciseEvolution extends StatelessWidget {
  const _ExerciseEvolution({
    required this.exercises,
    required this.sessions,
    required this.selectedId,
    required this.onChanged,
  });

  final List<ExerciseDef> exercises;
  final List<TrainingSession> sessions;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final exercise = exercises.where((e) => e.id == selectedId).toList();
    final def = exercise.isNotEmpty ? exercise.first : exercises.first;

    final history = <({DateTime date, double load, int reps})>[];
    final ordered = sessions.toList()..sort((a, b) => a.date.compareTo(b.date));
    for (final s in ordered) {
      final sets = TrainingStats.setsFor(s, def.id);
      if (sets.isEmpty) continue;
      history.add((date: s.date, load: TrainingStats.lastLoad(sets), reps: sets.last.reps));
    }

    return Container(
      key: const Key('exercise-evolution'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            key: Key('evolution-picker-$selectedId'),
            initialValue: selectedId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Exercício',
              labelStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
              isDense: true,
              filled: true,
              fillColor: AppTheme.backgroundElevated,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXs), borderSide: const BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXs), borderSide: const BorderSide(color: AppTheme.border)),
            ),
            dropdownColor: AppTheme.surfaceLight,
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary),
            items: [
              for (final e in exercises)
                DropdownMenuItem(value: e.id, child: Text(e.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => onChanged(v ?? selectedId),
          ),
          const SizedBox(height: 12),
          if (history.isEmpty)
            Text('Sem registros para este exercício', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textFaint))
          else ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final h in history)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryMuted,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 0.8),
                    ),
                    child: Text(
                      '${h.load.toStringAsFixed(0)} kg · ${h.reps} reps',
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.primary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Carga máxima por sessão (${history.length} registro${history.length == 1 ? '' : 's'})',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.plan, required this.expanded, required this.onTap});
  final TrainingSession session;
  final TrainingPlan? plan;
  final bool expanded;
  final VoidCallback onTap;

  String get _dayName {
    final days = plan?.days ?? const <TrainingDay>[];
    for (final d in days) {
      if (d.id == session.dayId) return d.name;
    }
    return 'Treino';
  }

  @override
  Widget build(BuildContext context) {
    final volume = TrainingStats.sessionVolume(session);
    final exercisesDone = session.exercises.where((e) => e.sets.isNotEmpty).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border, width: 0.8),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppTheme.primaryMuted, borderRadius: BorderRadius.circular(AppTheme.radiusXs)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(session.date.day.toString().padLeft(2, '0'), style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                        Text(_month(session.date.month), style: GoogleFonts.jetBrainsMono(fontSize: 8, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_dayName, style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        const SizedBox(height: 3),
                        Text(
                          '${session.durationMinutes} min · $exercisesDone exercícios · ${session.totalSets} séries',
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 20, color: AppTheme.textMuted),
                ],
              ),
            ),
          ),
          if (expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppTheme.border, width: 0.8))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text('VOLUME ${volume.toStringAsFixed(0)} KG', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primary, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  for (final es in session.exercises)
                    if (es.sets.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text(_exerciseName(es.exerciseId), style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary))),
                            Text(
                              es.sets.map((s) => '${s.weight.toStringAsFixed(0)}×${s.reps}').join('  '),
                              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _exerciseName(String id) {
    final days = plan?.days ?? const <TrainingDay>[];
    for (final d in days) {
      for (final e in d.exercises) {
        if (e.id == id) return e.name;
      }
    }
    return id;
  }

  String _month(int m) =>
      const ['JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', 'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'][m - 1];
}
