import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../services/insight_rules_engine.dart';
import '../../state/app_state.dart';
import '../../widgets/core_widgets.dart';

/// Check-in diário: dados reais + insights determinísticos (sem IA).
class CheckinScreen extends StatelessWidget {
  const CheckinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final today = state.today;
    final insights = state.insights.daily(today);
    final checkInText = state.insights.checkIn(today);

    return Scaffold(
      appBar: AppBar(title: const Text('Check-in', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Formatters.dayLabel(DateTime.now()), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                _statRow('⚖️ Peso', today.weightKg != null ? '${today.weightKg!.toStringAsFixed(1)} kg' : '—'),
                _statRow('🔥 Calorias', '${today.kcalConsumed.round()} / ${today.metaKcal.round()} kcal'),
                _statRow('🏋️ Gastas treino', '${today.kcalBurned.round()} kcal'),
                _statRow('🥩 Proteínas', '${today.protein.round()} / ${today.metaProtein.round()} g'),
                _statRow('🍞 Carboidratos', '${today.carbs.round()} g'),
                _statRow('🥑 Gorduras', '${today.fat.round()} g'),
                _statRow('💧 Água', '${today.waterMl.round()} / ${today.metaWater.round()} ml'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: StatusBadge(
              label: '${today.status.emoji} ${today.status.label} calórico',
              emoji: today.status.emoji,
              color: switch (today.status) {
                DayStatus.deficit => AppTheme.success,
                DayStatus.maintenance => AppTheme.warning,
                DayStatus.surplus => AppTheme.danger,
              },
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Resumo do dia'),
          const SizedBox(height: 12),
          GlassCard(
            child: SelectableText(
              checkInText,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.6, fontFamily: 'monospace'),
            ),
          ),
          if (insights.isNotEmpty) ...[
            const SizedBox(height: 16),
            const SectionHeader(title: 'Orientações'),
            const SizedBox(height: 12),
            for (final ins in insights)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      ins.severity == InsightSeverity.warning
                          ? Icons.warning_amber_rounded
                          : ins.severity == InsightSeverity.success
                              ? Icons.check_circle_outline
                              : Icons.lightbulb_outline,
                      size: 18,
                      color: ins.severity == InsightSeverity.warning
                          ? AppTheme.warning
                          : ins.severity == InsightSeverity.success
                              ? AppTheme.success
                              : AppTheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ins.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary)),
                          Text(ins.message, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
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
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
