import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../services/insight_rules_engine.dart';
import '../../state/app_state.dart';
import '../../widgets/core_widgets.dart';

/// Coach determinístico: insights derivados de regras locais, sem IA generativa.
/// Mostra micro-insights úteis e ações no lugar de conversa.
class CoachScreen extends StatelessWidget {
  const CoachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final today = state.today;
    final week = state.thisWeek();
    final engine = state.insights;
    final dailyInsights = engine.daily(today);
    final weeklyInsights = engine.weekly(week);
    final profile = state.profile;

    // Prioriza: alta → média → baixa, pega 1 principal + lista secundária
    dailyInsights.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    weeklyInsights.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    final primary = dailyInsights.isNotEmpty ? dailyInsights.first : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _Greeting(name: profile?.name, primary: primary, today: today),
          const SizedBox(height: 10),
          const Row(
            children: [
              Icon(Icons.verified_outlined, size: 14, color: AppTheme.success),
              SizedBox(width: 6),
              Text('Insights locais — sem IA generativa', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 20),
          if (primary != null) ...[
            const SectionHeader(title: 'Foco de hoje'),
            const SizedBox(height: 12),
            _PrimaryInsightCard(insight: primary),
            const SizedBox(height: 20),
          ],
          const SectionHeader(title: 'Hoje'),
          const SizedBox(height: 12),
          if (dailyInsights.isEmpty)
            const GlassCard(
              child: Text('Registre sua primeira refeição para ver orientações.', style: TextStyle(color: AppTheme.textSecondary)),
            )
          else
            for (final ins in dailyInsights) _InsightRow(insight: ins),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Sua semana'),
          const SizedBox(height: 12),
          for (final ins in weeklyInsights) _InsightRow(insight: ins),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Ações rápidas'),
          const SizedBox(height: 12),
          _QuickActions(),
          const SizedBox(height: 16),
          const Text(
            'As orientações acima vêm de cálculos do app — calorias restantes, proteína faltante, aderência e histórico. Sem IA generativa.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({this.name, this.primary, required this.today});
  final String? name;
  final Insight? primary;
  final dynamic today;

  String _saudacao() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bom dia';
    if (h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  @override
  Widget build(BuildContext context) {
    final greeting = name != null && name!.trim().isNotEmpty ? '${_saudacao()}, ${name!.trim().split(' ').first}' : _saudacao();
    final subtitle = primary?.message ?? _fallbackSubtitle();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(greeting, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4)),
      ],
    );
  }

  String _fallbackSubtitle() {
    final consumed = (today.kcalConsumed as num?)?.toDouble() ?? 0;
    final meta = (today.metaKcal as num?)?.toDouble() ?? 0;
    if (meta == 0) return 'Defina suas metas para começar a acompanhar seu progresso.';
    if (consumed == 0) return 'Registre sua primeira refeição para ver seu progresso do dia.';
    final pct = ((consumed / meta) * 100).round().clamp(0, 999);
    return 'Você já consumiu $pct% da meta calórica de hoje.';
  }
}

class _PrimaryInsightCard extends StatelessWidget {
  const _PrimaryInsightCard({required this.insight});
  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final color = switch (insight.severity) {
      InsightSeverity.warning => AppTheme.warning,
      InsightSeverity.success => AppTheme.success,
      InsightSeverity.info => AppTheme.primary,
    };
    final icon = switch (insight.severity) {
      InsightSeverity.warning => Icons.warning_amber_rounded,
      InsightSeverity.success => Icons.check_circle_outline,
      InsightSeverity.info => Icons.lightbulb_outline,
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.12), AppTheme.surfaceLight]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text(insight.message, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4)),
                if (insight.action != null) ...[
                  const SizedBox(height: 12),
                  _ActionButton(insight: insight),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.insight});
  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final color = switch (insight.severity) {
      InsightSeverity.warning => AppTheme.warning,
      InsightSeverity.success => AppTheme.success,
      InsightSeverity.info => AppTheme.textSecondary,
    };
    final dot = switch (insight.priority) {
      InsightPriority.high => AppTheme.danger,
      InsightPriority.medium => AppTheme.warning,
      InsightPriority.low => AppTheme.textMuted,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6), decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(insight.message, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.35)),
                if (insight.action != null) ...[
                  const SizedBox(height: 6),
                  _ActionLink(insight: insight, color: color),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.insight});
  final Insight insight;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: FilledButton(
        onPressed: () {
          if (insight.route != null) Navigator.pushNamed(context, insight.route!);
        },
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14)),
        child: Text(insight.action!, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}

class _ActionLink extends StatelessWidget {
  const _ActionLink({required this.insight, required this.color});
  final Insight insight;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (insight.route != null) Navigator.pushNamed(context, insight.route!);
      },
      child: Text(insight.action!, style: TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.restaurant_outlined, 'Registrar refeição', '/add-meal'),
      (Icons.fitness_center_outlined, 'Ver progresso', '/history'),
      (Icons.water_drop_outlined, 'Registrar água', null),
      (Icons.monitor_weight_outlined, 'Registrar peso', '/weight'),
      (Icons.tune_outlined, 'Ajustar metas', '/goals'),
      (Icons.restaurant_menu_outlined, 'Banco de alimentos', '/food-db'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (icon, label, route) in actions)
          ActionChip(
            avatar: Icon(icon, size: 16, color: AppTheme.primary),
            label: Text(label, style: const TextStyle(fontSize: 12)),
            onPressed: () {
              if (route != null) Navigator.pushNamed(context, route);
              if (label == 'Registrar água') {
                final state = context.read<AppState>();
                state.addWater(DateTime.now(), 250);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('💧 +250 ml registrados')));
              }
            },
          ),
      ],
    );
  }
}
