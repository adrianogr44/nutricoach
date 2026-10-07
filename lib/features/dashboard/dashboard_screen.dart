import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/daily_summary.dart';
import '../../data/models/diet.dart';
import '../../data/models/food.dart';
import '../../data/models/meal.dart';
import '../../services/household_measure.dart';
import '../../services/insight_rules_engine.dart';
import '../../state/app_state.dart';
import '../diet/diet_meal_editor.dart';
import '../meals/food_search_screen.dart';
import '../training/active_training_screen.dart';

/// Home premium — minimalista, hierarquia clara, sem excesso de cards.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.profile;
    final today = state.today;
    final m = state.dashboardMetrics();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async {},
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 88),
          children: [
            _Greeting(name: profile?.name),
            const SizedBox(height: 24),
            _HeroCalories(summary: today),
            const SizedBox(height: 20),
            _InsightInline(today: today),
            const SizedBox(height: 28),
            _MacroStrip(today: today, metrics: m),
            const SizedBox(height: 28),
            _MealsToday(today: today),
            const SizedBox(height: 28),
            _WaterCompact(today: today, metrics: m),
            const SizedBox(height: 28),
            _SecondaryStats(summary: today),
            const SizedBox(height: 24),
            _CalorieChartMinimal(state: state),
          ],
        ),
      ),
    );
  }
}

/// Saudação — Space Grotesk display, com eyebrow editorial
class _Greeting extends StatelessWidget {
  const _Greeting({this.name});
  final String? name;
  @override
  Widget build(BuildContext context) {
    final firstName = (name ?? '').trim().isEmpty ? null : name!.trim().split(' ').first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(firstName != null ? 'Olá, $firstName' : 'Olá', style: GoogleFonts.spaceGrotesk(fontSize: 32, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -1.0, height: 0.95)),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(width: 24, height: 1.5, color: AppTheme.primary.withValues(alpha: 0.6)),
            const SizedBox(width: 10),
            Text(Formatters.dayLabel(DateTime.now()).toUpperCase(), style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
          ],
        ),
      ],
    );
  }
}

/// Hero calórico — thesis do produto: número como marca, com motion orquestrado
class _HeroCalories extends StatefulWidget {
  const _HeroCalories({required this.summary});
  final DailySummary summary;
  @override
  State<_HeroCalories> createState() => _HeroCaloriesState();
}

class _HeroCaloriesState extends State<_HeroCalories> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progress;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    // respeita reduced motion
    final reduceMotion = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (!reduceMotion) _ctrl.forward();
    else _ctrl.value = 1;
  }

  @override
  void didUpdateWidget(covariant _HeroCalories oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.summary.kcalConsumed != widget.summary.kcalConsumed) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final consumed = widget.summary.kcalConsumed;
    final meta = widget.summary.metaKcal;
    final remaining = (meta - consumed).clamp(-9999, 9999);
    final pct = meta > 0 ? (consumed / meta).clamp(0.0, 1.0) : 0.0;
    final status = widget.summary.status;
    final isOver = remaining < 0;
    final color = switch (status) {
      DayStatus.deficit => AppTheme.primary,
      DayStatus.maintenance => AppTheme.warning,
      DayStatus.surplus => AppTheme.danger,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border, width: 0.8),
        boxShadow: AppTheme.shadowSubtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Número com Space Grotesk + count-up
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: consumed),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, val, _) => Text(val.round().toString(), style: GoogleFonts.spaceGrotesk(fontSize: 52, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -1.8, height: 0.9, fontFeatures: const [FontFeature.tabularFigures()])),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('kcal consumidas', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.2)),
                        Container(width: 20, height: 1, color: AppTheme.borderStrong),
                        Text('de ${meta.round()}', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textFaint, fontFeatures: const [FontFeature.tabularFigures()])),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppTheme.border, width: 0.8)),
                    child: Text(isOver ? '+${remaining.abs().round()}' : '${remaining.round()}', style: GoogleFonts.jetBrainsMono(fontSize: 13, color: isOver ? AppTheme.danger : AppTheme.textPrimary, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
                  ),
                  const SizedBox(height: 4),
                  Text(isOver ? 'acima da meta' : 'restantes', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Barra fina — sem dot duplicado (1 indicador verde só no pill)
          AnimatedBuilder(
            animation: _progress,
            builder: (context, _) {
              final animatedPct = pct * _progress.value;
              return Stack(
                children: [
                  Container(height: 6, decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(999))),
                  FractionallySizedBox(
                    widthFactor: animatedPct,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.75)]),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(status == DayStatus.deficit ? Icons.south_east : status == DayStatus.surplus ? Icons.north_east : Icons.trending_flat, size: 12, color: color.withValues(alpha: 0.9)),
              Text(status == DayStatus.deficit ? 'Déficit estimado' : status == DayStatus.surplus ? 'Superávit estimado' : 'Manutenção', style: GoogleFonts.inter(fontSize: 11, color: color, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
              Text('• ${widget.summary.balanceKcal.round().abs()} kcal', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textMuted, fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
        ],
      ),
    );
  }
}

/// Insight — parte natural do produto, não alerta de sistema
class _InsightInline extends StatelessWidget {
  const _InsightInline({required this.today});
  final DailySummary today;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final insights = state.insights.daily(today);
    if (insights.isEmpty) return const SizedBox.shrink();
    insights.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    final primary = insights.first;
    // Não tratar proteína zero de manhã como erro grave — se for low priority e cedo, mostra como info
    final isMorningLow = primary.priority == InsightPriority.low && DateTime.now().hour < 10;
    final color = isMorningLow ? AppTheme.textSecondary : switch (primary.severity) {
          InsightSeverity.warning => AppTheme.warning,
          InsightSeverity.success => AppTheme.success,
          InsightSeverity.info => AppTheme.primary,
        };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppTheme.surface.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border, width: 0.8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 28, height: 28, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Icon(isMorningLow ? Icons.lightbulb_outline : Icons.auto_awesome, size: 14, color: color)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(primary.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(primary.message, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
              ],
            ),
          ),
          if (primary.action != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: InkWell(
                onTap: () { if (primary.route != null) Navigator.pushNamed(context, primary.route!); },
                child: Text('Ver →', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Macros — três colunas pequenas, sem cards gigantes, tabular, cores moderadas
class _MacroStrip extends StatelessWidget {
  const _MacroStrip({required this.today, required this.metrics});
  final DailySummary today;
  final dynamic metrics;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Macros', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 0.8)),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, c) {
          final isNarrow = c.maxWidth < 360;
          return Row(
            children: [
              Expanded(child: _MacroCell(label: 'Proteína', value: metrics.protein, goal: today.metaProtein, unit: 'g', color: AppTheme.macroProtein)),
              SizedBox(width: isNarrow ? 8 : 12),
              Expanded(child: _MacroCell(label: 'Carbo', value: metrics.carbs, goal: today.metaCarbs, unit: 'g', color: AppTheme.macroCarbs)),
              SizedBox(width: isNarrow ? 8 : 12),
              Expanded(child: _MacroCell(label: 'Gordura', value: metrics.fat, goal: today.metaFat, unit: 'g', color: AppTheme.macroFat)),
            ],
          );
        }),
      ],
    );
  }
}

class _MacroCell extends StatelessWidget {
  const _MacroCell({required this.label, required this.value, required this.goal, required this.unit, required this.color});
  final String label;
  final double value;
  final double goal;
  final String unit;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final pct = goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;
    // Se manhã e zero, não mostrar vermelho — usar muted
    final isEarlyZero = value == 0 && DateTime.now().hour < 11;
    final barColor = isEarlyZero ? AppTheme.textMuted.withValues(alpha: 0.5) : color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(text: value.round().toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, fontFeatures: [FontFeature.tabularFigures()])),
              TextSpan(text: ' / ${goal.round()}$unit', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontFeatures: [FontFeature.tabularFigures()])),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(value: pct, minHeight: 4, backgroundColor: AppTheme.surfaceLight, valueColor: AlwaysStoppedAnimation(barColor)),
        ),
      ],
    );
  }
}

/// Água — barra fina, sem card
class _WaterCompact extends StatelessWidget {
  const _WaterCompact({required this.today, required this.metrics});
  final DailySummary today;
  final dynamic metrics;
  @override
  Widget build(BuildContext context) {
    final water = metrics.water as double;
    final goal = today.metaWater;
    final pct = goal > 0 ? (water / goal).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Água', style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                  Text('${(water / 1000).toStringAsFixed(1).replaceAll('.', ',')} / ${(goal / 1000).toStringAsFixed(1).replaceAll('.', ',')} L', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontFeatures: [FontFeature.tabularFigures()])),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: pct, minHeight: 4, backgroundColor: AppTheme.surfaceLight, valueColor: const AlwaysStoppedAnimation(AppTheme.macroWater))),
            ],
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: () {
            final state = context.read<AppState>();
            state.addWater(DateTime.now(), 250);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('💧 +250 ml')));
          },
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppTheme.macroWater.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: AppTheme.macroWater.withValues(alpha: 0.20))),
            child: const Icon(Icons.add, size: 18, color: AppTheme.macroWater),
          ),
        ),
      ],
    );
  }
}

/// Stats secundárias — academia, peso, bio — linhas discretas, não cards empilhados
class _SecondaryStats extends StatelessWidget {
  const _SecondaryStats({required this.summary});
  final DailySummary summary;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final burned = summary.kcalBurned;
    final weight = summary.weightKg ?? state.latestWeight?.weightKg ?? 0;
    final perdido = state.pesoPerdidoKg;
    final bio = state.bioimpedances.isNotEmpty ? state.bioimpedances.last : null;
    return Column(
      children: [
        _StatRow(icon: Icons.fitness_center_outlined, label: 'Academia', value: burned > 0 ? '${burned.round()} kcal hoje' : 'Nenhum treino hoje', trailing: const Icon(Icons.chevron_right, size: 16, color: AppTheme.textMuted), onTap: () => Navigator.pushNamed(context, '/workout')),
        const Divider(height: 1, color: AppTheme.border),
        _StatRow(icon: Icons.monitor_weight_outlined, label: 'Peso', value: weight > 0 ? '${weight.toStringAsFixed(1)} kg${perdido > 0 ? "  ·  −${perdido.toStringAsFixed(1)} kg" : ""}' : 'Registrar peso', onTap: () => Navigator.pushNamed(context, '/weight')),
        const Divider(height: 1, color: AppTheme.border),
        _StatRow(icon: Icons.biotech_outlined, label: 'Bioimpedância', value: bio != null ? '${bio.pontuacao ?? "—"} pts · ${bio.tmbKcal?.round() ?? "—"} kcal' : 'Importar laudo InBody', onTap: () => Navigator.pushNamed(context, '/bioimpedance')),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.icon, required this.label, required this.value, this.trailing, this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: AppTheme.textSecondary)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  Text(value, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Gráfico semanal — minimal, sem card pesado
class _CalorieChartMinimal extends StatelessWidget {
  const _CalorieChartMinimal({required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final days = state.lastDays(7);
    final spots = [for (var i = 0; i < days.length; i++) FlSpot(i.toDouble(), days[i].kcalConsumed.roundToDouble())];
    final meta = days.isEmpty ? 2000.0 : days.last.metaKcal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Últimos 7 dias', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 0.4)),
            Text('meta ${meta.round()} kcal', style: const TextStyle(fontSize: 11, color: AppTheme.textFaint, fontFeatures: [FontFeature.tabularFigures()])),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: (meta * 1.4).clamp(500, 4000).toDouble(),
              gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: meta / 2, getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.border, strokeWidth: 0.8)),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (v, meta) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= days.length) return const SizedBox.shrink();
                      const w = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
                      return Padding(padding: const EdgeInsets.only(top: 6), child: Text(w[days[idx].date.weekday - 1], style: const TextStyle(color: AppTheme.textFaint, fontSize: 10, fontWeight: FontWeight.w600)));
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(spots: spots, isCurved: true, curveSmoothness: 0.3, color: AppTheme.primary, barWidth: 2.2, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppTheme.primary.withValues(alpha: 0.18), Colors.transparent]))),
                LineChartBarData(spots: [for (var i = 0; i < days.length; i++) FlSpot(i.toDouble(), meta)], color: AppTheme.textFaint.withValues(alpha: 0.6), barWidth: 1, dashArray: [4, 4], dotData: const FlDotData(show: false)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Refeições — timeline orgânica, sem cards gigantes ──

class _MealsToday extends StatelessWidget {
  const _MealsToday({required this.today});
  final DailySummary today;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final diet = state.activeDiet;

    if (diet == null || diet.meals.isEmpty) {
      final List<Meal> meals = today.meals;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Hoje', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.2)),
              TextButton(onPressed: () => Navigator.pushNamed(context, '/add-meal'), child: const Text('Adicionar', style: TextStyle(fontSize: 12))),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(height: 1, color: AppTheme.border),
          if (meals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Container(width: 56, height: 56, decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.restaurant_outlined, color: AppTheme.textMuted)),
                    const SizedBox(height: 12),
                    const Text('Nenhuma refeição ainda', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    const Text('Quando comer, registre aqui para\nacompanhar seu dia.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
                    const SizedBox(height: 16),
                    FilledButton.icon(onPressed: () => Navigator.pushNamed(context, '/add-meal'), icon: const Icon(Icons.add, size: 16), label: const Text('Registrar refeição')),
                  ],
                ),
              ),
            )
          else
            for (final meal in meals) _MealRowSimple(meal: meal),
        ],
      );
    }

    final foodMap = state.foodByIdMap;
    final todayDate = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Hoje', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary, letterSpacing: -0.2)),
            TextButton(onPressed: () => Navigator.pushNamed(context, '/diet'), child: const Text('Minha Dieta', style: TextStyle(fontSize: 12))),
          ],
        ),
        const Divider(height: 1, color: AppTheme.border),
        const SizedBox(height: 8),
        for (final dietMeal in diet.meals) _DietMealTimelineTile(dietMeal: dietMeal, foodMap: foodMap, todayDate: todayDate),
        _TrainingTimelineTile(todayDate: todayDate),
        _ExtraMeals(today: today, diet: diet),
      ],
    );
  }
}

class _MealRowSimple extends StatelessWidget {
  const _MealRowSimple({required this.meal});
  final Meal meal;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_timeLabel(meal.date), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(width: 14),
          Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6), decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(meal.type.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
                    Text('${meal.totalKcal.round()} kcal', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontFeatures: [FontFeature.tabularFigures()])),
                  ],
                ),
                const SizedBox(height: 2),
                Text(_itemsPreview(meal), style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  String _itemsPreview(Meal meal) {
    final items = meal.items;
    if (items.isEmpty) return '';
    final names = [for (final it in items.take(3)) it.food.name.split(' ').take(2).join(' ')].join(', ');
    final extra = items.length > 3 ? ' +${items.length - 3}' : '';
    return names + extra;
  }
}

class _DietMealTimelineTile extends StatelessWidget {
  const _DietMealTimelineTile({required this.dietMeal, required this.foodMap, required this.todayDate});
  final DietMeal dietMeal;
  final Map<String, Food> foodMap;
  final DateTime todayDate;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final status = state.dietMealStatusFor(todayDate, dietMeal);
    final totals = dietMeal.totals(foodMap);
    final kcal = totals['kcal']!;
    final isConsumed = status == 'consumed';
    final isPartial = status == 'partially';
    final dotColor = isConsumed ? AppTheme.success : isPartial ? AppTheme.warning : AppTheme.textFaint;
    final timeLabel = dietMeal.time ?? '--:--';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha do tempo — hora + dot + linha
          Column(
            children: [
              Text(timeLabel, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontFeatures: [FontFeature.tabularFigures()])),
              const SizedBox(height: 6),
              Container(width: 10, height: 10, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle, border: Border.all(color: AppTheme.background, width: 2), boxShadow: [BoxShadow(color: dotColor.withValues(alpha: 0.3), blurRadius: 6)])),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(dietMeal.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isConsumed ? AppTheme.textSecondary : AppTheme.textPrimary, decoration: isConsumed ? TextDecoration.lineThrough : null))),
                    Text('${kcal.round()} kcal', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontFeatures: [FontFeature.tabularFigures()])),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_dietItemsPreview(), style: TextStyle(fontSize: 12, color: isConsumed ? AppTheme.textFaint : AppTheme.textSecondary, height: 1.3)),
                const SizedBox(height: 10),
                if (!isConsumed)
                  Row(
                    children: [
                      FilledButton(onPressed: () async { await state.logDietMeal(dietMeal: dietMeal, date: todayDate); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${dietMeal.name} registrado'))); }, style: FilledButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), child: const Text('Registrar')),
                      const SizedBox(width: 8),
                      OutlinedButton(onPressed: () => _openPartial(context, dietMeal), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 12), textStyle: const TextStyle(fontSize: 12)), child: const Text('Editar')),
                    ],
                  )
                else
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check, size: 12, color: AppTheme.success), SizedBox(width: 4), Text('Registrado', style: TextStyle(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.w700))])),
                      const Spacer(),
                      TextButton(onPressed: () => _openPartial(context, dietMeal), child: const Text('Ajustar', style: TextStyle(fontSize: 12))),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dietItemsPreview() {
    if (dietMeal.items.isEmpty) return 'Sem alimentos';
    final converter = const HouseholdMeasureConverter();
    final parts = <String>[];
    for (final it in dietMeal.items.take(3)) {
      final food = foodMap[it.foodId] ?? it.foodSnapshot;
      if (food == null) continue;
      final display = converter.displayFor(food, it.quantity, it.unit, customGramsPerUnit: it.customGramsPerUnit);
      // mostra só nome curto
      parts.add('${food.name.split(' ').first} $display');
    }
    var s = parts.join(' · ');
    if (dietMeal.items.length > 3) s += ' +${dietMeal.items.length - 3}';
    return s;
  }

  void _openPartial(BuildContext context, DietMeal meal) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: AppTheme.surface, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl))), builder: (_) => _PartialDietSheet(dietMeal: meal));
  }
}

class _TrainingTimelineTile extends StatelessWidget {
  const _TrainingTimelineTile({required this.todayDate});
  final DateTime todayDate;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final day = state.activeTrainingPlan?.today;
    if (day == null) return const SizedBox.shrink();
    final hasTodaySession = state.trainingSessions.any((s) => s.dayId == day.id && s.date.day == todayDate.day);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Text(day.time ?? '19:00', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontFeatures: [FontFeature.tabularFigures()])),
              const SizedBox(height: 6),
              Container(width: 10, height: 10, decoration: BoxDecoration(color: hasTodaySession ? AppTheme.success : AppTheme.primary, shape: BoxShape.circle, border: Border.all(color: AppTheme.background, width: 2), boxShadow: [BoxShadow(color: (hasTodaySession ? AppTheme.success : AppTheme.primary).withValues(alpha: 0.35), blurRadius: 8)])),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(day.name.toUpperCase(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: hasTodaySession ? AppTheme.textSecondary : AppTheme.textPrimary, letterSpacing: 0.4, decoration: hasTodaySession ? TextDecoration.lineThrough : null))),
                    Text('${day.totalSets} séries', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(day.exercises.take(3).map((e) => e.name).join(' · ') + (day.exercises.length > 3 ? ' +${day.exercises.length - 3}' : ''), style: TextStyle(fontSize: 12, color: hasTodaySession ? AppTheme.textFaint : AppTheme.textSecondary, height: 1.3)),
                const SizedBox(height: 10),
                if (!hasTodaySession)
                  Row(
                    children: [
                      FilledButton(onPressed: () async { final s = await state.startTrainingSession(state.activeTrainingPlan!.id, day.id); if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => ActiveTrainingScreen(session: s, day: day))); }, style: FilledButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 14), textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), child: const Text('Iniciar treino →')),
                      const SizedBox(width: 8),
                      Text('~${day.estimatedMinutes ?? 55} min', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  )
                else
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check, size: 12, color: AppTheme.success), SizedBox(width: 4), Text('Concluído', style: TextStyle(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.w700))])),
                      const Spacer(),
                      TextButton(onPressed: () => Navigator.pushNamed(context, '/training'), child: const Text('Ver', style: TextStyle(fontSize: 12))),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtraMeals extends StatelessWidget {
  const _ExtraMeals({required this.today, required this.diet});
  final DailySummary today;
  final DietPlan diet;
  @override
  Widget build(BuildContext context) {
    final meals = today.meals;
    final extras = meals.where((m) => m.rawText == null || !m.rawText!.startsWith('Dieta:')).toList();
    if (extras.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24, color: AppTheme.border),
        const Text('Extras do dia', style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
        const SizedBox(height: 8),
        for (final meal in extras)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.add, size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 8),
                Expanded(child: Text('${meal.type.label} · ${meal.totalKcal.round()} kcal', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
              ],
            ),
          ),
      ],
    );
  }
}

class _PartialDietSheet extends StatefulWidget {
  const _PartialDietSheet({required this.dietMeal});
  final DietMeal dietMeal;
  @override
  State<_PartialDietSheet> createState() => _PartialDietSheetState();
}

class _PartialDietSheetState extends State<_PartialDietSheet> {
  late Set<int> selected;
  late Map<int, double> qtyOverrides;
  late Map<int, ({Food food, double quantity, MeasureUnit unit, double? customGrams})> subs;
  @override
  void initState() {
    super.initState();
    selected = {for (var i = 0; i < widget.dietMeal.items.length; i++) i};
    qtyOverrides = {};
    subs = {};
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final foodMap = state.foodByIdMap;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.borderStrong, borderRadius: BorderRadius.circular(4)), alignment: Alignment.center),
            const SizedBox(height: 16),
            Text('${widget.dietMeal.name} — hoje', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.3)),
            const SizedBox(height: 4),
            const Text('Desmarque o que não comeu, ajuste quantidades ou troque alimentos. Só o diário de hoje será afetado.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4)),
            const SizedBox(height: 16),
            for (var i = 0; i < widget.dietMeal.items.length; i++)
              Builder(builder: (_) {
                final dietItem = widget.dietMeal.items[i];
                final isSub = subs.containsKey(i);
                final food = isSub ? subs[i]!.food : (foodMap[dietItem.foodId] ?? dietItem.foodSnapshot);
                if (food == null) return const SizedBox.shrink();
                final qty = qtyOverrides[i] ?? (isSub ? subs[i]!.quantity : dietItem.quantity);
                final unit = isSub ? subs[i]!.unit : dietItem.unit;
                final custom = isSub ? subs[i]!.customGrams : dietItem.customGramsPerUnit;
                final display = const HouseholdMeasureConverter().displayFor(food, qty, unit, customGramsPerUnit: custom);
                final checked = selected.contains(i);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: checked ? AppTheme.surface : AppTheme.surfaceLight.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(12), border: Border.all(color: checked ? AppTheme.border : Colors.transparent, width: 0.8)),
                  child: Row(
                    children: [
                      Checkbox(value: checked, onChanged: (v) => setState(() { if (v == true) selected.add(i); else selected.remove(i); }), activeColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(food.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: checked ? AppTheme.textPrimary : AppTheme.textMuted)), Text(display, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11))])),
                      IconButton(icon: const Icon(Icons.edit_outlined, size: 16), onPressed: () => _editQty(i, food, qty, unit, custom)),
                      IconButton(icon: const Icon(Icons.swap_horiz, size: 16), onPressed: () => _swap(i)),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: selected.isEmpty ? null : () async { final s = context.read<AppState>(); await s.logDietMeal(dietMeal: widget.dietMeal, date: DateTime.now(), selectedIndices: selected, quantityOverrides: qtyOverrides, substitutions: subs); if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refeição registrada'))); } }, child: const Text('Registrar refeição'))),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _editQty(int index, Food food, double qty, MeasureUnit unit, double? custom) async {
    final controller = TextEditingController(text: qty.toStringAsFixed(1).replaceAll('.0', '').replaceAll('.', ','));
    MeasureUnit curUnit = unit;
    double? curCustom = custom;
    final res = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => StatefulBuilder(builder: (context, setD) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Quantidade — ${food.name}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantidade'))),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<MeasureUnit>(initialValue: curUnit, decoration: const InputDecoration(labelText: 'Unidade'), items: [for (final u in const HouseholdMeasureConverter().availableFor(food)) DropdownMenuItem(value: u, child: Text(u.label, style: const TextStyle(fontSize: 11)))], onChanged: (v) => setD(() => curUnit = v ?? MeasureUnit.g))),
            ]),
            if (curUnit != MeasureUnit.g && curUnit != MeasureUnit.kg) ...[
              const SizedBox(height: 8),
              TextField(decoration: const InputDecoration(labelText: 'Gramas por unidade (opcional)', hintText: 'Ex: 120'), controller: TextEditingController(text: curCustom?.toString() ?? ''), keyboardType: TextInputType.number, onChanged: (v) => curCustom = double.tryParse(v.replaceAll(',', '.'))),
            ],
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, {'qty': double.tryParse(controller.text.replaceAll(',', '.')) ?? qty, 'unit': curUnit, 'custom': curCustom}), child: const Text('Salvar'))],
        )));
    if (res != null) {
      setState(() {
        qtyOverrides[index] = res['qty'] as double;
        final newUnit = res['unit'] as MeasureUnit;
        final cg = res['custom'] as double?;
        if (newUnit != unit || cg != custom) {
          subs[index] = (food: food, quantity: res['qty'] as double, unit: newUnit, customGrams: cg);
          qtyOverrides.remove(index);
        }
      });
    }
  }

  Future<void> _swap(int index) async {
    final newFood = await Navigator.push<Food>(context, MaterialPageRoute(builder: (_) => const FoodSearchScreen(compactPicker: true, pickerLabel: 'Trocar alimento')));
    if (newFood == null) return;
    final picked = await showDietQuantityPicker(context, newFood);
    if (picked != null) {
      setState(() {
        subs[index] = (food: newFood, quantity: picked.quantity, unit: picked.unit, customGrams: picked.customGramsPerUnit);
        selected.add(index);
      });
    }
  }
}
