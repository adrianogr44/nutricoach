import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/tracking.dart';
import '../../state/app_state.dart';
import '../../widgets/core_widgets.dart';

/// Registro de treino (manual ou sincronizado) + gráfico da semana.
class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final _kcal = TextEditingController();
  final _tempo = TextEditingController();
  final _obs = TextEditingController();

  @override
  void dispose() {
    _kcal.dispose();
    _tempo.dispose();
    _obs.dispose();
    super.dispose();
  }

  Future<void> _saveManual() async {
    final kcal = double.tryParse(_kcal.text.replaceAll(',', '.'));
    if (kcal == null || kcal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe as calorias gastas.')),
      );
      return;
    }
    final state = context.read<AppState>();
    await state.addWorkout(Workout(
      id: const Uuid().v4(),
      date: DateTime.now(),
      kcalBurned: kcal,
      durationMinutes: int.tryParse(_tempo.text),
      notes: _obs.text.trim().isEmpty ? null : _obs.text.trim(),
      source: 'manual',
    ));
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('🏋️ Treino registrado — ${kcal.round()} kcal')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🏋️ Academia', style: TextStyle(fontSize: 18))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Sincronizar automaticamente',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary, fontSize: 15),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SyncTile(
                  icon: '⌚',
                  label: 'Mi Fitness',
                  onTap: () => _sync('Mi Fitness'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SyncTile(
                  icon: '🔗',
                  label: 'Health Connect',
                  onTap: () => _sync('Health Connect'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SyncTile(
                  icon: '📱',
                  label: 'Google Fit',
                  onTap: () => _sync('Google Fit'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Ou inserir manualmente',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary, fontSize: 15),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _kcal,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Calorias gastas', suffixText: 'kcal'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _tempo,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Tempo', suffixText: 'min'),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _obs,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Observações (opcional)'),
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: _saveManual, child: const Text('Salvar treino')),
          const SizedBox(height: 28),
          const SectionHeader(title: '📈 Últimos 7 dias'),
          const SizedBox(height: 12),
          _WorkoutChart(),
        ],
      ),
    );
  }

  void _sync(String service) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$service: conectado em breve aos apps de saúde do seu celular.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _SyncTile extends StatelessWidget {
  const _SyncTile({required this.icon, required this.label, required this.onTap});
  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final days = state.lastDays(7);
    final maxKcal = days.fold<double>(0, (m, d) => d.kcalBurned > m ? d.kcalBurned : m);
    final chartMax = (maxKcal * 1.2).clamp(200.0, 4000.0);

    return GlassCard(
      child: SizedBox(
        height: 160,
        child: BarChart(
          BarChartData(
            maxY: chartMax,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (v) => FlLine(color: AppTheme.border, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= days.length) return const SizedBox.shrink();
                    const weekdays = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        weekdays[days[idx].date.weekday - 1],
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: [
              for (var i = 0; i < days.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: days[i].kcalBurned,
                    color: days[i].kcalBurned > 0
                        ? AppTheme.accent
                        : AppTheme.surfaceLight,
                    width: 18,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}