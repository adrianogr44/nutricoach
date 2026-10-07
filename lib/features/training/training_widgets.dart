import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/training.dart';
import 'training_stats.dart';

/// Bloco de resumo superior — sequência, recorde, treinos e semana.
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
      label: 'Sequência de $streak dias, recorde de $best, $total treinos concluídos, '
          '$weekDone de $weekTarget esta semana',
      child: Container(
        key: const Key('summary-card'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.surface, AppTheme.surfaceLight],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.border, width: 0.8),
          boxShadow: AppTheme.shadowSubtle,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SEQUÊNCIA', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w700, letterSpacing: 1)),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(streak.toString().padLeft(2, '0'), style: GoogleFonts.spaceGrotesk(fontSize: 46, fontWeight: FontWeight.w800, color: AppTheme.primary, letterSpacing: -2, height: 0.9)),
                          const SizedBox(width: 6),
                          Text(streak == 1 ? 'dia' : 'dias', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                _MiniStat(label: 'RECORDE', value: best.toString().padLeft(2, '0')),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _BarStat(label: 'TREINOS', value: total.toString().padLeft(2, '0'))),
                const SizedBox(width: 10),
                Expanded(
                  child: _BarStat(
                    label: 'SEMANA',
                    value: '$weekDone/$weekTarget',
                    color: weekDone >= weekTarget && weekTarget > 0 ? AppTheme.primary : AppTheme.textPrimary,
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

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
      ],
    );
  }
}

class _BarStat extends StatelessWidget {
  const _BarStat({required this.label, required this.value, this.color = AppTheme.textPrimary});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.backgroundElevated,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.border, width: 0.8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.w700, letterSpacing: 1)),
          Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

/// Card de divisão (A/B/C, Push/Pull/Legs...). O identificador é derivado
/// da posição no plano ou de uma letra única já usada no nome do dia.
/// Um toque seleciona o dia e expande a lista de exercícios; tocar de
/// novo recolhe.
class TrainingDivisionCard extends StatefulWidget {
  const TrainingDivisionCard({
    super.key,
    required this.day,
    required this.index,
    required this.isToday,
    required this.isActive,
    required this.onTap,
    this.lastLabel,
  });

  final TrainingDay day;
  final int index;
  final bool isToday;
  final bool isActive;
  final VoidCallback onTap;
  final String? lastLabel;

  static String letterFor(TrainingDay day, int index) {
    final name = day.name.trim();
    if (name.length == 1 && RegExp(r'^[A-Za-zÀ-ÿ]$').hasMatch(name)) {
      return name.toUpperCase();
    }
    if (index < 26) return String.fromCharCode(65 + index);
    return '•';
  }

  @override
  State<TrainingDivisionCard> createState() => _TrainingDivisionCardState();
}

class _TrainingDivisionCardState extends State<TrainingDivisionCard> {
  late bool _open;

  @override
  void initState() {
    super.initState();
    _open = widget.isActive;
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final letter = TrainingDivisionCard.letterFor(day, widget.index);
    final selected = widget.isActive || widget.isToday;
    final borderColor = selected ? AppTheme.primary : AppTheme.border;
    return Semantics(
      button: true,
      label: 'Treino $letter, ${day.name}, ${day.totalExercises} exercícios${widget.isToday ? ', treino de hoje' : ''}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('division-card-${widget.index}'),
          onTap: () {
            widget.onTap();
            setState(() => _open = !_open);
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? AppTheme.primaryMuted : AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: borderColor, width: selected ? 1.4 : 0.8),
              boxShadow: widget.isToday ? [const BoxShadow(color: Color(0x2200E6A0), blurRadius: 18, spreadRadius: -2)] : null,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: widget.isToday ? AppTheme.primary : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                        border: Border.all(color: widget.isToday ? AppTheme.primary : AppTheme.border, width: 0.8),
                      ),
                      child: Text(letter, style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w800, color: widget.isToday ? AppTheme.textOnPrimary : AppTheme.textPrimary)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(day.name, overflow: TextOverflow.ellipsis, style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                              ),
                              if (widget.isToday) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(999)),
                                  child: Text('HOJE', style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.textOnPrimary, letterSpacing: 0.6)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${day.totalExercises} exercícios · ${day.totalSets} séries'
                            '${widget.lastLabel != null ? ' · ${widget.lastLabel}' : ''}',
                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 22, color: selected ? AppTheme.primary : AppTheme.textMuted),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: _open
                      ? Container(
                          key: Key('division-exercises-${widget.index}'),
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: AppTheme.border, width: 0.6)),
                          ),
                          child: day.exercises.isEmpty
                              ? Text('Sem exercícios cadastrados', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted))
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (var i = 0; i < day.exercises.length; i++)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          '${(i + 1).toString().padLeft(2, '0')}  ${day.exercises[i].name} · ${day.exercises[i].sets} × ${day.exercises[i].repsLabel}'
                                          '${day.exercises[i].loadKg > 0 ? ' · ${day.exercises[i].loadKg.round()} kg' : ''}',
                                          style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textSecondary),
                                        ),
                                      ),
                                  ],
                                ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grid de consistência — janela de [weeks] semanas civis, só sessões reais.
class ConsistencyGrid extends StatelessWidget {
  const ConsistencyGrid({super.key, required this.sessions, this.weeks = 12, this.now});

  final List<TrainingSession> sessions;
  final int weeks;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final grid = TrainingStats.consistencyGrid(sessions, weeks: weeks, now: now);
    final trained = grid.expand((c) => c).where((c) => c == TrainingDayCell.trained).length;
    return Semantics(
      label: 'Consistência: $trained dias com treino nas últimas $weeks semanas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 3.0;
              final size = ((constraints.maxWidth - gap * (weeks - 1)) / weeks).clamp(6.0, 16.0);
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
                                  TrainingDayCell.future => AppTheme.backgroundElevated,
                                },
                                borderRadius: BorderRadius.circular(3),
                                border: cell == TrainingDayCell.future ? Border.all(color: AppTheme.border, width: 0.6) : null,
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
              _LegendDot(color: AppTheme.backgroundElevated, label: 'Ainda não ocorreu', outlined: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label, this.outlined = false});
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
            border: outlined ? Border.all(color: AppTheme.border, width: 0.6) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
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
          border: Border.all(color: unlocked ? AppTheme.primary.withValues(alpha: 0.4) : AppTheme.border, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(unlocked ? Icons.emoji_events_rounded : Icons.lock_outline, size: 18, color: color),
            const SizedBox(height: 8),
            Text(achievement.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: unlocked ? AppTheme.textPrimary : AppTheme.textMuted)),
            const SizedBox(height: 2),
            Text(
              unlocked ? achievement.detail : '${achievement.progress}/${achievement.target}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jetBrainsMono(fontSize: 10, color: unlocked ? AppTheme.primary : AppTheme.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra de descanso — flutuante na parte inferior da sessão ativa.
/// O timer vive aqui (rebuilda só a si mesma); a tela é notificada por
/// [onFinished] quando o descanso zera.
class RestTimerBar extends StatefulWidget {
  const RestTimerBar({
    super.key,
    required this.listenable,
    required this.onAdjust,
    required this.onSkip,
    required this.onFinished,
  });

  final ValueListenable<int> listenable;
  final ValueChanged<int> onAdjust;
  final VoidCallback onSkip;
  final VoidCallback onFinished;

  @override
  State<RestTimerBar> createState() => _RestTimerBarState();
}

class _RestTimerBarState extends State<RestTimerBar> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_onChange);
    _sync();
  }

  @override
  void didUpdateWidget(covariant RestTimerBar old) {
    super.didUpdateWidget(old);
    if (old.listenable != widget.listenable) {
      old.listenable.removeListener(_onChange);
      widget.listenable.addListener(_onChange);
      _sync();
    }
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_onChange);
    _timer?.cancel();
    super.dispose();
  }

  void _onChange() {
    _sync();
    setState(() {});
  }

  void _sync() {
    _timer?.cancel();
    _timer = null;
    if (widget.listenable.value <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (widget.listenable.value <= 1) {
        t.cancel();
        widget.onFinished();
      } else {
        widget.onAdjust(-1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.listenable,
      builder: (context, seconds, _) {
        if (seconds <= 0) return const SizedBox.shrink();
        final mm = (seconds ~/ 60).toString().padLeft(2, '0');
        final ss = (seconds % 60).toString().padLeft(2, '0');
        return SafeArea(
          top: false,
          child: Container(
            key: const Key('rest-timer'),
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4), width: 1),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16)],
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('DESCANSO', style: GoogleFonts.jetBrainsMono(fontSize: 8, color: AppTheme.textMuted, fontWeight: FontWeight.w700, letterSpacing: 1)),
                    Text('$mm:$ss', style: GoogleFonts.jetBrainsMono(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primary, height: 1.1)),
                  ],
                ),
                const Spacer(),
                _RestButton(label: '-15', onTap: () => widget.onAdjust(-15)),
                const SizedBox(width: 6),
                _RestButton(label: '+15', onTap: () => widget.onAdjust(15)),
                const SizedBox(width: 6),
                _RestButton(label: 'Pular', onTap: widget.onSkip, wide: true),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RestButton extends StatelessWidget {
  const _RestButton({required this.label, required this.onTap, this.wide = false});
  final String label;
  final VoidCallback onTap;
  final bool wide;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: wide ? 12 : 8),
          foregroundColor: AppTheme.textPrimary,
          backgroundColor: AppTheme.surfaceHover,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXs)),
          minimumSize: const Size(44, 44),
        ),
        child: Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
