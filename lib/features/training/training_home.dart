import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/training.dart';
import '../../state/app_state.dart';
import 'active_training_screen.dart';
import 'training_editor.dart';

/// Treino Home — inspirado em GymRats: energia, ação clara, pouco ruído.
/// Pergunta central: O que vou treinar hoje?
class TrainingHomeScreen extends StatelessWidget {
  const TrainingHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final plan = state.activeTrainingPlan;

    if (plan == null || plan.days.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: _EmptyTraining(onCreate: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrainingEditor(plan: plan)))),
      );
    }

    final today = plan.today;
    final sessions = state.trainingSessions.take(5).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _HeaderGreeting(),
          const SizedBox(height: 20),
          if (today != null) _TodayHero(day: today, plan: plan),
          const SizedBox(height: 28),
          _WeekStrip(plan: plan),
          const SizedBox(height: 28),
          _NextUp(plan: plan),
          const SizedBox(height: 28),
          _RecentHistory(sessions: sessions, plan: plan),
        ],
      ),
    );
  }
}

class _HeaderGreeting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final name = context.watch<AppState>().profile?.name?.split(' ').first ?? 'Atleta';
    final hour = DateTime.now().hour;
    final greet = hour < 12 ? 'Bom dia' : hour < 18 ? 'Boa tarde' : 'Boa noite';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$greet, $name.', style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.6)),
        const SizedBox(height: 4),
        Text('O que vamos treinar hoje?', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _TodayHero extends StatelessWidget {
  const _TodayHero({required this.day, required this.plan});
  final TrainingDay day;
  final TrainingPlan plan;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lastSession = state.trainingSessions.where((s) => s.dayId == day.id).firstOrNull;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.surface, AppTheme.surfaceLight]),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border, width: 0.8),
        boxShadow: AppTheme.shadowSubtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                child: Text('HOJE', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
              ),
              const Spacer(),
              Text(day.time ?? '', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 12),
          Text(day.name.toUpperCase(), style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.6)),
          const SizedBox(height: 6),
          Text('${day.totalExercises} exercícios · ${day.totalSets} séries · ~${day.estimatedMinutes ?? 55} min', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
          if (lastSession != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border, width: 0.8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history, size: 12, color: AppTheme.textMuted),
                  const SizedBox(width: 6),
                  Text('Último: ${_formatDate(lastSession.date)} · ${lastSession.totalSets} séries', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final session = await state.startTrainingSession(plan.id, day.id);
                if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ActiveTrainingScreen(session: session, day: day)));
              },
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: AppTheme.primary, foregroundColor: AppTheme.textOnPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
              child: Text('INICIAR TREINO', style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
            ),
          ),
          const SizedBox(height: 12),
          // Preview exercícios (sem card gigante)
          for (final ex in day.exercises.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(child: Text(ex.name, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w600))),
                  Text('${ex.sets} × ${ex.repsLabel}', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ),
          if (day.exercises.length > 5) Text('+${day.exercises.length - 5} exercícios', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textFaint)),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${_month(d.month)}';
  String _month(int m) => const ['JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', 'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'][m - 1];
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.plan});
  final TrainingPlan plan;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sua semana'.toUpperCase(), style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 7; i++)
              Builder(builder: (_) {
                final date = startOfWeek.add(Duration(days: i));
                final isToday = date.day == now.day && date.month == now.month;
                final hasSession = state.trainingSessions.any((s) => s.date.day == date.day && s.date.month == date.month);
                final dayPlan = plan.days.where((d) => d.weekday == date.weekday % 7).isNotEmpty;
                String label;
                IconData icon;
                Color color;
                if (hasSession) {
                  label = '✓';
                  icon = Icons.check_circle;
                  color = AppTheme.success;
                } else if (isToday) {
                  label = '●';
                  icon = Icons.circle;
                  color = AppTheme.primary;
                } else if (!dayPlan) {
                  label = '—';
                  icon = Icons.remove;
                  color = AppTheme.textFaint;
                } else {
                  label = '○';
                  icon = Icons.circle_outlined;
                  color = AppTheme.textMuted;
                }
                return Column(
                  children: [
                    Text(['S', 'T', 'Q', 'Q', 'S', 'S', 'D'][i], style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: isToday ? AppTheme.primary.withValues(alpha: 0.14) : Colors.transparent, shape: BoxShape.circle, border: isToday ? Border.all(color: AppTheme.primary, width: 1.2) : null),
                      child: Center(child: Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700))),
                    ),
                  ],
                );
              }),
          ],
        ),
        const SizedBox(height: 10),
        Text('${state.trainingSessions.where((s) => s.date.isAfter(startOfWeek.subtract(const Duration(days: 1)))).length} treinos esta semana', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _NextUp extends StatelessWidget {
  const _NextUp({required this.plan});
  final TrainingPlan plan;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming = plan.days.where((d) => d.weekday != null && d.weekday! > now.weekday % 7).take(2).toList();
    if (upcoming.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Próximos'.toUpperCase(), style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        const SizedBox(height: 12),
        for (final day in upcoming)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border, width: 0.8)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(day.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      Text(_weekdayLabel(day.weekday), style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 16, color: AppTheme.textMuted),
              ],
            ),
          ),
      ],
    );
  }

  String _weekdayLabel(int? wd) {
    if (wd == null) return '';
    const days = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    return days[wd % 7];
  }
}

class _RecentHistory extends StatelessWidget {
  const _RecentHistory({required this.sessions, required this.plan});
  final List<TrainingSession> sessions;
  final TrainingPlan plan;
  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) return const SizedBox.shrink();
    // agrupa por mês
    final byMonth = <String, List<TrainingSession>>{};
    for (final s in sessions) {
      final key = '${s.date.month}/${s.date.year}';
      byMonth.putIfAbsent(key, () => []).add(s);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Últimos treinos'.toUpperCase(), style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        const SizedBox(height: 12),
        for (final entry in byMonth.entries.take(2))
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.key.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textFaint, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final s in entry.value)
                Builder(builder: (_) {
                  final day = plan.days.where((d) => d.id == s.dayId).firstOrNull;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppTheme.surfaceLight.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border, width: 0.8)),
                    child: Row(
                      children: [
                        Container(width: 36, height: 36, decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.fitness_center, size: 16, color: AppTheme.primary)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(day?.name ?? 'Treino', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                              Text('${s.date.day.toString().padLeft(2, '0')} ${_month(s.date.month)} · ${s.durationMinutes} min · ${s.totalSets} séries', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 14, color: AppTheme.textFaint),
                      ],
                    ),
                  );
                }),
            ],
          ),
      ],
    );
  }

  String _month(int m) => const ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'][m - 1];
}

class _EmptyTraining extends StatelessWidget {
  const _EmptyTraining({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 72, height: 72, decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.fitness_center, size: 32, color: AppTheme.primary)),
            const SizedBox(height: 16),
            Text('Nenhum treino criado', style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text('Monte sua rotina e deixe o registro\nda academia muito mais rápido.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add, size: 18), label: Text('Criar treino', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
