import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/body_track.dart';
import '../../state/app_state.dart';
import '../../widgets/core_widgets.dart';

/// Registro de peso diário + gráfico de evolução.
class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  final _peso = TextEditingController();

  @override
  void dispose() {
    _peso.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final peso = double.tryParse(_peso.text.replaceAll(',', '.'));
    if (peso == null || peso <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o peso.')),
      );
      return;
    }
    final state = context.read<AppState>();
    await state.addWeight(WeightRecord(date: DateTime.now(), weightKg: peso));
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('⚖️ Peso atualizado — $peso kg')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final current = state.latestWeight?.weightKg ?? state.profile?.pesoAtualKg ?? 0;
    final target = state.profile?.pesoDesejadoKg ?? current;
    final perdido = (state.profile?.pesoAtualKg ?? current) - current;

    return Scaffold(
      appBar: AppBar(title: const Text('⚖️ Peso', style: TextStyle(fontSize: 18))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _peso,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Peso de hoje (kg)',
                  suffixText: 'kg',
                  hintText: current > 0 ? 'Atual: $current' : null,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Registrar')),
          const SizedBox(height: 28),
          GlassCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat(current > 0 ? current : 0, 'Atual', 'kg'),
                _stat(target, 'Meta', 'kg'),
                _stat(
                  perdido > 0 ? -perdido : 0,
                  'Perdido',
                  'kg',
                  color: perdido > 0 ? AppTheme.success : AppTheme.textSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const SectionHeader(title: '📉 Evolução do peso'),
          const SizedBox(height: 12),
          _WeightChart(weights: state.weights),
        ],
      ),
    );
  }

  Widget _stat(double value, String label, String unit, {Color color = AppTheme.primary}) {
    return Column(
      children: [
        Text(
          value.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$label ($unit)',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.weights});

  final List<WeightRecord> weights;

  @override
  Widget build(BuildContext context) {
    // Coloca o peso inicial do perfil como ponto de partida.
    final state = context.read<AppState>();
    final startWeight = state.profile?.pesoAtualKg;
    final all = <(DateTime, double)>[
      if (startWeight != null && weights.isEmpty)
        (weights.isNotEmpty ? weights.first.date.subtract(const Duration(days: 1)) : DateTime.now().subtract(const Duration(days: 1)), startWeight),
      for (final w in weights) (w.date, w.weightKg),
    ];

    if (all.length < 2) {
      return const GlassCard(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Registre o peso por alguns dias para ver a evolução gráfica.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    final minW = all.map((e) => e.$2).reduce((a, b) => a < b ? a : b);
    final maxW = all.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
    final pad = (maxW - minW) * 0.15 + 0.5;

    return GlassCard(
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            minY: (minW - pad).clamp(0, double.infinity),
            maxY: maxW + pad,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (v) => FlLine(color: AppTheme.border, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) => Text(
                    value.toStringAsFixed(0),
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= all.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${all[idx].$1.day}/${all[idx].$1.month}',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < all.length; i++) FlSpot(i.toDouble(), all[i].$2),
                ],
                isCurved: true,
                curveSmoothness: 0.35,
                color: AppTheme.warning,
                barWidth: 3,
                dotData: FlDotData(show: true, checkToShowDot: (spot, barData) => false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.warning.withValues(alpha: 0.30),
                      AppTheme.warning.withValues(alpha: 0.02),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}