import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/device_health.dart';
import '../../state/app_state.dart';
import '../../widgets/core_widgets.dart';

/// Saúde do dispositivo — conecta ao Health Connect (Android) / Apple Health
/// (iOS), mostra passos, sono, frequência cardíaca e treinos do relógio.
/// Todos os dados ficam no aparelho; nada é enviado para servidores.
class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  bool _busy = false;

  Future<void> _connect() async {
    final state = context.read<AppState>();
    setState(() => _busy = true);
    final ok = await state.connectHealth();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Saúde conectada! Dados sincronizados.'
              : 'Permissão não concedida. Você pode tentar de novo.',
        ),
      ),
    );
  }

  Future<void> _sync() async {
    final state = context.read<AppState>();
    await state.syncHealthData();
    if (!mounted) return;
    final last = state.healthSyncHistory.isNotEmpty ? state.healthSyncHistory.first : null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          last?.status == 'error'
              ? 'Não foi possível sincronizar: ${last?.error ?? 'erro'}'
              : 'Dados sincronizados.',
        ),
      ),
    );
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Desconectar saúde?'),
        content: const Text(
          'Os dados já sincronizados continuam no aparelho. Novas leituras '
          'só acontecem depois de reconectar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desconectar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<AppState>().disconnectHealth();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final config = state.healthConfig;
    final connected = config.connected;
    final today = DateTime.now();
    final steps = state.todaySteps;
    final sleep = state.sleepForDay(today) ??
        state.sleepForDay(today.subtract(const Duration(days: 1)));
    final workouts = state.deviceWorkouts.reversed.take(5).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Saúde e dispositivo',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          _statusCard(state, connected),
          if (!state.healthSupported) ...[
            const SizedBox(height: 16),
            const _InfoCard(
              icon: Icons.devices_other_outlined,
              title: 'Disponível no app Android e iOS',
              text: 'No navegador não há acesso ao Health Connect nem ao Apple '
                  'Health. Instale o app no celular para sincronizar o relógio.',
            ),
          ],
          if (connected) ...[
            const SizedBox(height: 24),
            const SectionHeader(title: 'Hoje'),
            const SizedBox(height: 12),
            GlassCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _metric('${steps?.steps ?? 0}', 'Passos', Icons.directions_walk),
                  _metric(
                    steps == null ? '—' : (steps.distanceMeters / 1000).toStringAsFixed(1),
                    'km',
                    Icons.route_outlined,
                  ),
                  _metric(
                    steps == null ? '—' : steps.caloriesBurned.round().toString(),
                    'kcal ativas',
                    Icons.local_fire_department_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                children: [
                  _line(
                    Icons.bedtime_outlined,
                    'Sono',
                    sleep == null
                        ? 'Sem registro'
                        : '${(sleep.durationMinutes / 60).toStringAsFixed(1)} h',
                  ),
                  const Divider(height: 20, color: AppTheme.border),
                  _line(
                    Icons.favorite_outline,
                    'FC de repouso',
                    state.healthRestingHr == null
                        ? 'Sem registro'
                        : '${state.healthRestingHr!.round()} bpm',
                  ),
                  const Divider(height: 20, color: AppTheme.border),
                  _line(
                    Icons.monitor_weight_outlined,
                    'Peso do dispositivo',
                    state.healthWeightKg == null
                        ? 'Sem registro'
                        : '${state.healthWeightKg!.toStringAsFixed(1)} kg',
                    action: state.healthWeightKg == null
                        ? null
                        : TextButton(
                            onPressed: () async {
                              await state.applyDeviceWeight();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Peso do dispositivo aplicado ao histórico.'),
                                ),
                              );
                            },
                            child: const Text('Aplicar'),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SectionHeader(title: 'Treinos do dispositivo'),
            const SizedBox(height: 12),
            if (workouts.isEmpty)
              const GlassCard(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Nenhum treino sincronizado ainda. Registre a atividade no '
                    'relógio e toque em sincronizar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ),
              )
            else
              GlassCard(
                child: Column(
                  children: [
                    for (var i = 0; i < workouts.length; i++) ...[
                      if (i > 0) const Divider(height: 20, color: AppTheme.border),
                      _workoutLine(workouts[i]),
                    ],
                  ],
                ),
              ),
          ],
          const SizedBox(height: 24),
          const _InfoCard(
            icon: Icons.lock_outline,
            title: 'Privacidade',
            text: 'A leitura acontece no próprio aparelho, pelo Health Connect ou '
                'Apple Health. O NutriCoach não envia esses dados para servidores '
                'e funciona offline.',
          ),
        ],
      ),
    );
  }

  Widget _statusCard(AppState state, bool connected) {
    final lastSync = state.healthConfig.lastSyncAt;
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                connected ? Icons.link : Icons.link_off,
                color: connected ? AppTheme.primary : AppTheme.textMuted,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  connected ? 'Conectado' : 'Não conectado',
                  style: TextStyle(
                    color: connected ? AppTheme.primary : AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              if (state.healthSyncing)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            connected
                ? 'Última sincronização: ${lastSync == null ? '—' : _fmtDateTime(lastSync)}'
                : 'Conecte para importar passos, sono, frequência cardíaca e treinos '
                    'do seu relógio ou balança.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          if (!state.healthSupported)
            const SizedBox.shrink()
          else if (_busy)
            const FilledButton(
              onPressed: null,
              child: Text('Aguardando permissões...'),
            )
          else if (!connected)
            FilledButton.icon(
              onPressed: _connect,
              icon: const Icon(Icons.favorite_border),
              label: const Text('Conectar saúde'),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: state.healthSyncing ? null : _sync,
                  icon: const Icon(Icons.sync),
                  label: const Text('Sincronizar agora'),
                ),
                OutlinedButton(
                  onPressed: state.healthSyncing ? null : _disconnect,
                  child: const Text('Desconectar'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _metric(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primary, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11.5),
        ),
      ],
    );
  }

  Widget _line(IconData icon, String label, String value, {Widget? action}) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13.5),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
        ?action,
      ],
    );
  }

  Widget _workoutLine(DeviceWorkoutSession w) {
    final minutes = w.durationMinutes ?? w.endAt.difference(w.startAt).inMinutes;
    return Row(
      children: [
        const Icon(Icons.fitness_center, color: AppTheme.primary, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                w.activityType,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
              Text(
                '${_fmtDate(w.startAt)} · $minutes min',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        if (w.caloriesBurned != null)
          Text(
            '${w.caloriesBurned!.round()} kcal',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
          ),
      ],
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  static String _fmtDateTime(DateTime d) =>
      '${_fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.textMuted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
