import '../core/constants.dart';
import '../data/models/daily_summary.dart';

enum InsightSeverity { info, success, warning }
enum InsightPriority { high, medium, low }

class Insight {
  const Insight({
    required this.message,
    this.title = 'Orientação',
    this.severity = InsightSeverity.info,
    this.priority = InsightPriority.medium,
    this.action,
    this.route,
  });

  final String title;
  final String message;
  final InsightSeverity severity;
  final InsightPriority priority;
  final String? action;
  final String? route;
}

class InsightRulesEngine {
  const InsightRulesEngine();

  List<Insight> daily(DailySummary day) {
    final insights = <Insight>[];
    final excess = day.kcalConsumed - day.metaKcal;
    if (day.metaKcal > 0 && excess >= day.metaKcal * 0.05) {
      insights.add(Insight(
        title: 'Meta diária ultrapassada',
        message: 'Meta diária ultrapassada em ${excess.round()} kcal.',
        severity: InsightSeverity.warning,
        priority: InsightPriority.high,
        action: 'Ver refeições',
        route: '/history',
      ));
    }
    final proteinRemaining = (day.metaProtein - day.protein).clamp(0, double.infinity);
    if (proteinRemaining > 0) {
      if (proteinRemaining >= 30) {
        insights.add(Insight(
          title: 'Proteína abaixo da meta',
          message: 'Ainda faltam ${proteinRemaining.round()} g de proteína para sua meta de hoje.',
          severity: InsightSeverity.warning,
          priority: InsightPriority.high,
          action: 'Ver opções',
          route: '/add-meal',
        ));
      } else {
        insights.add(Insight(
          title: 'Proteína quase na meta',
          message: 'Faltam apenas ${proteinRemaining.round()} g de proteína para completar a meta.',
          severity: InsightSeverity.success,
          priority: InsightPriority.medium,
        ));
      }
    }
    final waterRemaining = (day.metaWater - day.waterMl).clamp(0, double.infinity);
    if (waterRemaining > 0) {
      if (waterRemaining >= 500) {
        insights.add(Insight(
          title: 'Hidratação abaixo da meta',
          message: 'Faltam ${waterRemaining.round()} ml de água para sua meta de hoje.',
          severity: InsightSeverity.warning,
          priority: InsightPriority.medium,
          action: 'Registrar água',
        ));
      }
    }
    final kcalRemaining = (day.metaKcal - day.kcalConsumed).clamp(0, double.infinity);
    if (kcalRemaining > 0 && day.meals.isNotEmpty) {
      insights.add(Insight(
        title: 'Calorias disponíveis',
        message: 'Você ainda pode distribuir aproximadamente ${kcalRemaining.round()} kcal entre suas próximas refeições.',
        severity: InsightSeverity.info,
        priority: InsightPriority.low,
      ));
    }
    if (day.meals.isEmpty && day.metaKcal > 0) {
      insights.add(Insight(
        title: 'Nenhuma refeição registrada',
        message: 'Registre sua primeira refeição do dia para acompanhar seu progresso.',
        severity: InsightSeverity.info,
        priority: InsightPriority.high,
        action: 'Adicionar refeição',
        route: '/add-meal',
      ));
    }
    return insights;
  }

  List<Insight> weekly(WeeklySummary week) {
    return [
      Insight(
        title: 'Aderência semanal',
        message: 'Aderência calórica da semana: ${week.aderenciaKcal}%.',
        severity: week.aderenciaKcal >= 80
            ? InsightSeverity.success
            : InsightSeverity.warning,
        priority: InsightPriority.high,
      ),
      Insight(
        title: 'Dias em déficit',
        message: 'Dias em déficit: ${week.deficitDays} de ${week.days.length}.',
        severity: week.deficitDays >= 4 ? InsightSeverity.success : InsightSeverity.info,
        priority: InsightPriority.medium,
      ),
      Insight(
        title: 'Proteína média',
        message: 'Média diária de proteína: ${week.avgProtein.round()} g.',
        severity: InsightSeverity.info,
        priority: InsightPriority.low,
      ),
      Insight(
        title: 'Gasto médio em treino',
        message: 'Média de gasto em treino: ${week.avgKcalBurned.round()} kcal/dia.',
        severity: InsightSeverity.info,
        priority: InsightPriority.low,
      ),
    ];
  }

  String checkIn(DailySummary day) {
    final lines = <String>[
      'CHECK-IN — ${_date(day.date)}',
      'Calorias: ${day.kcalConsumed.round()} / ${day.metaKcal.round()} kcal',
      'Proteínas: ${day.protein.round()} / ${day.metaProtein.round()} g',
      'Água: ${day.waterMl.round()} / ${day.metaWater.round()} ml',
      'Status: ${day.status.label}',
      '',
      ...daily(day).map((insight) => insight.message),
    ];
    return lines.join('\n');
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
