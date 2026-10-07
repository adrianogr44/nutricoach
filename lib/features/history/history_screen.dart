import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/daily_summary.dart';
import '../../data/models/meal.dart';
import '../../services/insight_rules_engine.dart';
import '../../state/app_state.dart';
import '../../widgets/core_widgets.dart';

/// Histórico em calendário: cada dia tem status 🟢/🟡/🔴.
/// Abrir o dia mostra refeições, macros, água, peso, academia e resumo da IA.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _month = DateTime.now();
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    _selected = DateTime.now();
  }

  void _prevMonth() => setState(() {
        _month = DateTime(_month.year, _month.month - 1, 1);
      });

  void _nextMonth() => setState(() {
        _month = DateTime(_month.year, _month.month + 1, 1);
      });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final selected = _selected ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico', style: TextStyle(fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _month = DateTime.now();
              _selected = DateTime.now();
            }),
            child: const Text('Hoje', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 88),
        children: [
          _MonthHeader(
            month: _month,
            onPrev: _prevMonth,
            onNext: _nextMonth,
          ),
          const SizedBox(height: 12),
          _MonthGrid(
            month: _month,
            selected: selected,
            onSelect: (d) => setState(() => _selected = d),
            state: state,
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: '📋 Detalhe do dia'),
          const SizedBox(height: 12),
          DayDetailCard(summary: state.summaryFor(selected)),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.month, required this.onPrev, required this.onNext});

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    const meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
        Text(
          '${meses[month.month - 1]} ${month.year}',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        IconButton(
          onPressed: month.isBefore(DateTime.now().copyWith(day: 1)) ? onNext : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.onSelect,
    required this.state,
  });

  final DateTime month;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = firstDay.weekday - 1;

    final cells = <Widget>[
      for (final w in ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'])
        Center(
          child: Text(
            w,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var d = 1; d <= daysInMonth; d++) ...[
        _DayCell(
          day: DateTime(month.year, month.month, d),
          isSelected: d == selected.day && month.year == selected.year && month.month == selected.month,
          status: _statusOf(state, DateTime(month.year, month.month, d)),
          onTap: () => onSelect(DateTime(month.year, month.month, d)),
        ),
      ],
    ];

    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        childAspectRatio: 1.05,
        children: cells,
      ),
    );
  }

  DayStatus? _statusOf(AppState state, DateTime day) {
    if (day.isAfter(DateTime.now())) return null;
    final s = state.summaryFor(day);
    if (s.meals.isEmpty && s.workouts.isEmpty && s.kcalConsumed == 0) return null;
    return s.status;
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.isSelected, required this.status, required this.onTap});

  final DateTime day;
  final bool isSelected;
  final DayStatus? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.18) : null,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: AppTheme.primary) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              status?.emoji ?? '·',
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detalhe do dia selecionado: refeições, macros, água, peso, academia, IA.
class DayDetailCard extends StatelessWidget {
  const DayDetailCard({super.key, required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DayHeader(summary: summary),
        const SizedBox(height: 12),
        if (summary.meals.isEmpty && summary.workouts.isEmpty)
          const GlassCard(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Nenhum registro neste dia.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ),
        for (final meal in summary.meals) _MealCard(meal: meal),
        const SizedBox(height: 12),
        _MacrosRow(summary: summary),
        const SizedBox(height: 12),
        _ExtrasRow(summary: summary),
        const SizedBox(height: 12),
        _AiResumo(summary: summary),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.summary});
  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            summary.status.emoji,
            style: const TextStyle(fontSize: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Formatters.dayLabel(summary.date),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${summary.kcalConsumed.round()} / ${summary.metaKcal.round()} kcal · '
                  '${summary.status.label} de ${summary.balanceKcal.abs().round()} kcal',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal});
  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${meal.type.emoji} ${meal.type.label}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                '${meal.totalKcal.round()} kcal',
                style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800),
              ),
              PopupMenuButton<String>(
                color: AppTheme.surfaceLight,
                icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.textMuted),
                onSelected: (v) {
                  if (v == 'delete') state.removeMeal(meal.id);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, color: AppTheme.danger, size: 18),
                      SizedBox(width: 8),
                      Text('Excluir'),
                    ]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final item in meal.items)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '• ${item.food.name} — ${item.quantityGrams.toStringAsFixed(0)} g '
                '(${item.nutrition.kcal.round()} kcal)',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ),
          if (meal.rawText != null && meal.rawText!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '💬 "${meal.rawText}"',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }
}

class _MacrosRow extends StatelessWidget {
  const _MacrosRow({required this.summary});
  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _row('🥩 Proteínas', summary.protein, summary.metaProtein, 'g', AppTheme.danger),
          _row('🍞 Carboidratos', summary.carbs, summary.metaCarbs, 'g', AppTheme.warning),
          _row('🥑 Gorduras', summary.fat, summary.metaFat, 'g', AppTheme.accent),
          _row('🥦 Fibras', summary.fiber, 30, 'g', AppTheme.success),
          _row('🧂 Sódio', summary.sodium, 2000, 'mg', AppTheme.textSecondary),
        ],
      ),
    );
  }

  Widget _row(String label, double value, double meta, String unit, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              Text(
                '${value.round()} / ${meta.round()} $unit',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          GradientBar(progress: meta > 0 ? value / meta : 0, color: color),
        ],
      ),
    );
  }
}

class _ExtrasRow extends StatelessWidget {
  const _ExtrasRow({required this.summary});
  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip('💧 ${summary.waterMl.round()} ml', '${summary.metaWater.round()} ml meta'),
        _chip('🏋️ ${summary.kcalBurned.round()} kcal', 'gastas em treino'),
        if (summary.weightKg != null)
          _chip('⚖️ ${summary.weightKg!.toStringAsFixed(1)} kg', 'peso'),
      ],
    );
  }

  Widget _chip(String label, String sub) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          Text(sub, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}

/// Resumo determinístico do dia — insights derivados de regras locais.
class _AiResumo extends StatelessWidget {
  const _AiResumo({required this.summary});
  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final insights = state.insights.daily(summary);
    if (insights.isEmpty) {
      return const GlassCard(
        child: Text(
          'Nenhuma orientação para este dia. Registre refeições para ver insights.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      );
    }
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 16, color: AppTheme.primary),
              SizedBox(width: 6),
              Text('Orientações', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          for (final ins in insights)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    ins.severity == InsightSeverity.warning ? Icons.warning_amber_rounded : ins.severity == InsightSeverity.success ? Icons.check_circle_outline : Icons.info_outline,
                    size: 16,
                    color: ins.severity == InsightSeverity.warning ? AppTheme.warning : ins.severity == InsightSeverity.success ? AppTheme.success : AppTheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ins.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary)),
                        Text(ins.message, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4)),
                        if (ins.action != null && ins.route != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: InkWell(
                              onTap: () => Navigator.pushNamed(context, ins.route!),
                              child: Text(ins.action!, style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
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
}