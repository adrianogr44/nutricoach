import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/training.dart';
import '../../widgets/core_widgets.dart';
import 'training_stats.dart';

/// Bloco de resumo semanal — leitura rápida, sem competir com o treino do dia.
class TrainingSummaryCard extends StatelessWidget {
  const TrainingSummaryCard({
    super.key,
    required this.streak,
    required this.best,
    required this.total,
    required this.weekDone,
    required this.weekTarget,
  });

  final int streak;
  final int best;
  final int total;
  final int weekDone;
  final int weekTarget;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Sequência de $streak dias, recorde de $best, $total treinos concluídos, '
          '$weekDone de $weekTarget esta semana',
      child: Container(
        key: const Key('summary-card'),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.border, width: 0.8),
        ),
        child: Wrap(
          spacing: 26,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SEQUÊNCIA',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      streak.toString().padLeft(2, '0'),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                        letterSpacing: -1.5,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      streak == 1 ? 'dia' : 'dias',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            _SummaryStat(
              label: 'SEMANA',
              value: '$weekDone/$weekTarget',
              highlight: weekTarget > 0 && weekDone >= weekTarget,
            ),
            _SummaryStat(
              label: 'TREINOS',
              value: total.toString().padLeft(2, '0'),
            ),
            _SummaryStat(
              label: 'RECORDE',
              value: best.toString().padLeft(2, '0'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    this.highlight = false,
  });
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: highlight ? AppTheme.primary : AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Chip compacto de divisão (A/B/C). Seleciona o dia; o detalhe dos
/// exercícios fica na lista abaixo.
class TrainingDivisionCard extends StatelessWidget {
  const TrainingDivisionCard({
    super.key,
    required this.day,
    required this.index,
    required this.isToday,
    required this.isActive,
    required this.onTap,
  });

  final TrainingDay day;
  final int index;
  final bool isToday;
  final bool isActive;
  final VoidCallback onTap;

  static String letterFor(TrainingDay day, int index) {
    final name = day.name.trim();
    if (name.length == 1 && RegExp(r'^[A-Za-zÀ-ÿ]$').hasMatch(name)) {
      return name.toUpperCase();
    }
    if (index < 26) return String.fromCharCode(65 + index);
    return '•';
  }

  @override
  Widget build(BuildContext context) {
    final letter = letterFor(day, index);
    final selected = isActive;
    return Semantics(
      button: true,
      selected: selected,
      label:
          'Treino $letter, ${day.name}, ${day.totalExercises} exercícios'
          '${isToday ? ', treino de hoje' : ''}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('division-card-$index'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppTheme.primaryMuted : AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(
                color: selected ? AppTheme.primary : AppTheme.border,
                width: selected ? 1.4 : 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  letter,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: selected ? AppTheme.primary : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        day.emphasis,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${day.totalExercises} ex · ${day.totalSets} séries',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Destaque do treino selecionado: letra, ênfase, volume e ação principal.
class TrainingHeroCard extends StatelessWidget {
  const TrainingHeroCard({
    super.key,
    required this.day,
    required this.letter,
    required this.isToday,
    required this.exerciseCount,
    required this.setCount,
    required this.estimatedMinutes,
    required this.doneExercises,
    required this.active,
    required this.onStart,
    this.lastLabel,
  });

  final TrainingDay day;
  final String letter;
  final bool isToday;
  final int exerciseCount;
  final int setCount;
  final int? estimatedMinutes;
  final int doneExercises;
  final bool active;
  final VoidCallback onStart;
  final String? lastLabel;

  @override
  Widget build(BuildContext context) {
    final total = exerciseCount == 0 ? 1 : exerciseCount;
    final fraction = (doneExercises / total).clamp(0.0, 1.0);

    return Semantics(
      label:
          '${isToday ? 'Treino de hoje' : 'Treino selecionado'}: ${day.name}. '
          '$exerciseCount exercícios, $setCount séries.',
      child: Container(
        key: const Key('training-hero'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.surfaceLight, AppTheme.surface],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.borderStrong, width: 0.8),
          boxShadow: AppTheme.shadowSubtle,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Text(
                    letter,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textOnPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isToday ? 'TREINO DE HOJE' : 'DIVISÃO SELECIONADA',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary,
                              letterSpacing: 1,
                            ),
                          ),
                          if (lastLabel != null) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                lastLabel!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        day.name,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          height: 1.15,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        day.emphasis,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HeroPill(
                  icon: Icons.fitness_center,
                  label: '$exerciseCount exercícios',
                ),
                _HeroPill(
                  icon: Icons.repeat_rounded,
                  label: '$setCount séries',
                ),
                if (estimatedMinutes != null)
                  _HeroPill(
                    icon: Icons.schedule,
                    label: '~$estimatedMinutes min',
                  ),
              ],
            ),
            if (active) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GradientBar(
                      progress: fraction,
                      color: AppTheme.primary,
                      height: 6,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$doneExercises/$exerciseCount',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                key: const Key('start-training'),
                onPressed: exerciseCount == 0 ? null : onStart,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.textOnPrimary,
                  disabledBackgroundColor: AppTheme.surfaceHover,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                ),
                icon: Icon(
                  active ? Icons.play_arrow_rounded : Icons.bolt_rounded,
                  size: 22,
                ),
                label: Text(
                  active ? 'CONTINUAR TREINO' : 'INICIAR TREINO',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
            if (exerciseCount == 0) ...[
              const SizedBox(height: 8),
              Text(
                'Este dia ainda não tem exercícios. Edite a ficha para adicionar.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.backgroundElevated,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: AppTheme.border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card compacto de exercício na home: número, nome, séries × reps e status.
/// Toque para expandir detalhes (carga sugerida, descanso, orientações).
class ExerciseListCard extends StatefulWidget {
  const ExerciseListCard({
    super.key,
    required this.exercise,
    required this.index,
    this.doneSets = 0,
    this.tracking = false,
    this.lastLabel,
  });

  final ExerciseDef exercise;
  final int index;

  /// Séries registradas na sessão ativa (0 quando não há sessão).
  final int doneSets;

  /// `true` quando há sessão em andamento para este dia.
  final bool tracking;
  final String? lastLabel;

  @override
  State<ExerciseListCard> createState() => _ExerciseListCardState();
}

class _ExerciseListCardState extends State<ExerciseListCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final completed = widget.tracking && widget.doneSets >= exercise.sets;
    final inProgress = widget.tracking && widget.doneSets > 0 && !completed;
    final accent = completed
        ? AppTheme.primary
        : (inProgress ? AppTheme.primarySoft : AppTheme.textMuted);

    return Container(
      key: Key('exercise-card-${exercise.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: completed
            ? AppTheme.primaryMuted.withValues(alpha: 0.45)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: completed || inProgress
              ? AppTheme.primary.withValues(alpha: 0.55)
              : AppTheme.border,
          width: completed || inProgress ? 1.2 : 0.8,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundElevated,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                      border: Border.all(color: AppTheme.border, width: 0.8),
                    ),
                    child: Text(
                      (widget.index + 1).toString().padLeft(2, '0'),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.name,
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${exercise.sets} séries · ${exercise.repsLabel} reps'
                          '${exercise.loadKg > 0 ? ' · ${exercise.loadKg.toStringAsFixed(0)} kg' : ''}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (completed)
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: AppTheme.primary,
                    )
                  else if (inProgress)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryMuted,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusFull,
                        ),
                      ),
                      child: Text(
                        '${widget.doneSets}/${exercise.sets}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                    )
                  else
                    Icon(
                      _open
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 20,
                      color: AppTheme.textMuted,
                    ),
                ],
              ),
            ),
          ),
          if (_open)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppTheme.border, width: 0.8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (exercise.muscleGroup != null &&
                          exercise.muscleGroup!.isNotEmpty)
                        _DetailChip(
                          icon: Icons.accessibility_new,
                          label: exercise.muscleGroup!,
                        ),
                      _DetailChip(
                        icon: Icons.timer_outlined,
                        label: '${exercise.restSeconds}s descanso',
                      ),
                      _DetailChip(
                        icon: Icons.repeat_rounded,
                        label: '${exercise.repsMin}–${exercise.repsMax} reps',
                      ),
                    ],
                  ),
                  if (widget.lastLabel != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Última vez: ${widget.lastLabel!}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                  if (exercise.notes != null &&
                      exercise.notes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          size: 15,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            exercise.notes!,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (exercise.videoUrl != null &&
                      exercise.videoUrl!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.play_circle_outline,
                          size: 15,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Vídeo demonstrativo disponível no treino',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.backgroundElevated,
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.textMuted),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid de consistência — janela de [weeks] semanas civis, só sessões reais.
class ConsistencyGrid extends StatelessWidget {
  const ConsistencyGrid({
    super.key,
    required this.sessions,
    this.weeks = 12,
    this.now,
  });

  final List<TrainingSession> sessions;
  final int weeks;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final grid = TrainingStats.consistencyGrid(
      sessions,
      weeks: weeks,
      now: now,
    );
    final trained = grid
        .expand((c) => c)
        .where((c) => c == TrainingDayCell.trained)
        .length;
    return Semantics(
      label:
          'Consistência: $trained dias com treino nas últimas $weeks semanas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 3.0;
              final size = ((constraints.maxWidth - gap * (weeks - 1)) / weeks)
                  .clamp(6.0, 16.0);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final column in grid)
                    Column(
                      children: [
                        for (final cell in column)
                          Padding(
                            padding: const EdgeInsets.only(bottom: gap),
                            child: Container(
                              width: size,
                              height: size,
                              decoration: BoxDecoration(
                                color: switch (cell) {
                                  TrainingDayCell.trained => AppTheme.primary,
                                  TrainingDayCell.rest => AppTheme.surfaceHover,
                                  TrainingDayCell.future =>
                                    AppTheme.backgroundElevated,
                                },
                                borderRadius: BorderRadius.circular(3),
                                border: cell == TrainingDayCell.future
                                    ? Border.all(
                                        color: AppTheme.border,
                                        width: 0.6,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _LegendDot(color: AppTheme.primary, label: 'Treino'),
              _LegendDot(color: AppTheme.surfaceHover, label: 'Descanso'),
              _LegendDot(
                color: AppTheme.backgroundElevated,
                label: 'Ainda não ocorreu',
                outlined: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    this.outlined = false,
  });
  final Color color;
  final String label;
  final bool outlined;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: outlined
                ? Border.all(color: AppTheme.border, width: 0.6)
                : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10.5, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}

/// Conquista — desbloqueada usa primary; bloqueada fica em baixo contraste.
class AchievementCard extends StatelessWidget {
  const AchievementCard({super.key, required this.achievement});
  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    final color = unlocked ? AppTheme.primary : AppTheme.textFaint;
    return Semantics(
      label: '${achievement.title}${unlocked ? '' : ', bloqueada'}',
      child: Container(
        key: Key('achievement-${achievement.id}'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: unlocked ? AppTheme.primaryMuted : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: unlocked
                ? AppTheme.primary.withValues(alpha: 0.4)
                : AppTheme.border,
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              unlocked ? Icons.emoji_events_rounded : Icons.lock_outline,
              size: 18,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              achievement.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: unlocked ? AppTheme.textPrimary : AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              unlocked
                  ? achievement.detail
                  : '${achievement.progress}/${achievement.target}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: unlocked ? AppTheme.primary : AppTheme.textFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Painel de descanso — flutuante, com contagem regressiva e progresso.
/// Puramente visual: o cronômetro (um único intervalo) vive na tela de
/// execução, então a contagem continua correta mesmo com rebuilds.
class RestTimerBar extends StatelessWidget {
  const RestTimerBar({
    super.key,
    required this.seconds,
    required this.onAdjust,
    required this.onSkip,
    this.totalSeconds,
  });

  final int seconds;
  final ValueChanged<int> onAdjust;
  final VoidCallback onSkip;
  final int? totalSeconds;

  @override
  Widget build(BuildContext context) {
    if (seconds <= 0) return const SizedBox.shrink();
    final total = (totalSeconds ?? seconds) <= 0
        ? seconds
        : (totalSeconds ?? seconds);
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 4),
      child: Container(
        key: const Key('rest-timer'),
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'DESCANSO',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Text(
                  '$mm:$ss',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                    height: 1,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GradientBar(
              progress: total <= 0 ? 0 : seconds / total,
              color: AppTheme.primary,
              height: 5,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _RestButton(label: '−15s', onTap: () => onAdjust(-15)),
                const SizedBox(width: 8),
                _RestButton(label: '+15s', onTap: () => onAdjust(15)),
                const Spacer(),
                Semantics(
                  button: true,
                  label: 'Pular descanso',
                  child: SizedBox(
                    height: 44,
                    child: FilledButton(
                      key: const Key('skip-rest'),
                      onPressed: onSkip,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryMuted,
                        foregroundColor: AppTheme.primary,
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusFull,
                          ),
                        ),
                      ),
                      child: Text(
                        'Pular',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RestButton extends StatelessWidget {
  const _RestButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor: AppTheme.textPrimary,
          backgroundColor: AppTheme.surfaceHover,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          ),
          minimumSize: const Size(52, 44),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
