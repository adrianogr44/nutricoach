import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/training.dart';
import '../../services/training_transfer.dart';
import '../../state/app_state.dart';
import 'active_training_screen.dart';
import 'training_editor.dart';
import 'training_history_view.dart';
import 'training_stats.dart';
import 'training_widgets.dart';

/// Aba Treino — foco em executar o treino de hoje.
/// Organização interna: Hoje · Ficha · Histórico (nenhuma aba global nova).
class TrainingHomeScreen extends StatefulWidget {
  const TrainingHomeScreen({super.key});

  @override
  State<TrainingHomeScreen> createState() => _TrainingHomeScreenState();
}

class _TrainingHomeScreenState extends State<TrainingHomeScreen> {
  int _tab = 0;
  String? _selectedDayId;

  /// Troca a aba (usado pelas ações do cabeçalho).
  void selectTab(int index) => setState(() => _tab = index);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final plan = state.activeTrainingPlan;

    if (plan == null || plan.days.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: _EmptyTraining(onImport: () => _importTraining()),
      );
    }

    final today = plan.today;
    final selectedId = _selectedDayId ?? today?.id ?? plan.days.first.id;
    final selectedDay = plan.days.where((d) => d.id == selectedId).toList();
    final day = selectedDay.isNotEmpty ? selectedDay.first : plan.days.first;
    final active = state.activeTrainingSession;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 88),
        children: [
          _Header(plan: plan, state: state),
          const SizedBox(height: 14),
          _SegmentedTabs(
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 20),
          switch (_tab) {
            0 => _buildHoje(state, plan, today, day, active),
            1 => _buildFicha(state, plan),
            _ => const TrainingHistoryView(),
          },
        ],
      ),
    );
  }

  // ── HOJE ──

  Widget _buildHoje(
    AppState state,
    TrainingPlan plan,
    TrainingDay? today,
    TrainingDay selectedDay,
    TrainingSession? active,
  ) {
    final sessions = state.trainingSessions;
    final done = sessions.where((s) => s.status == TrainingStatus.completed).toList();
    final weeklyTarget = plan.days.length.clamp(1, 7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (active != null) ...[
          _ActiveBanner(session: active, plan: plan),
          const SizedBox(height: 14),
        ],
        TrainingSummaryCard(
          streak: TrainingStats.streak(done),
          best: TrainingStats.bestStreak(done),
          total: TrainingStats.completedCount(done),
          weekDone: TrainingStats.weekCount(done),
          weekTarget: weeklyTarget,
        ),
        const SizedBox(height: 24),
        _SectionTitle('Escolha a divisão'),
        const SizedBox(height: 12),
        for (var i = 0; i < plan.days.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TrainingDivisionCard(
              day: plan.days[i],
              index: i,
              isToday: today != null && plan.days[i].id == today.id,
              isActive: plan.days[i].id == selectedDay.id,
              lastLabel: _lastLabel(state, plan.days[i]),
              onTap: () => setState(() => _selectedDayId = plan.days[i].id),
            ),
          ),
        if (active == null) ...[
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              key: const Key('start-training'),
              onPressed: () => _start(state, plan, selectedDay),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.textOnPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusFull)),
              ),
              child: Text('INICIAR TREINO', style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
            ),
          ),
        ],
        const SizedBox(height: 28),
        _SectionTitle('Consistência'),
        const SizedBox(height: 12),
        Container(
          key: const Key('consistency-grid'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border, width: 0.8),
          ),
          child: ConsistencyGrid(sessions: done),
        ),
        const SizedBox(height: 28),
        _SectionTitle('Conquistas'),
        const SizedBox(height: 12),
        _AchievementList(sessions: done, weeklyTarget: weeklyTarget),
      ],
    );
  }

  Future<void> _start(AppState state, TrainingPlan plan, TrainingDay day) async {
    final session = await state.startTrainingSession(plan.id, day.id);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ActiveTrainingScreen(session: session, day: day)),
    );
  }

  String? _lastLabel(AppState state, TrainingDay day) {
    TrainingSession? last;
    for (final s in state.trainingSessions) {
      if (s.dayId != day.id || s.status != TrainingStatus.completed) continue;
      if (last == null || s.date.isAfter(last.date)) last = s;
    }
    if (last == null) return null;
    return 'último ${last.date.day.toString().padLeft(2, '0')}/${last.date.month.toString().padLeft(2, '0')}';
  }

  // ── Exportar / importar ──

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Dialog de exportação: copia o JSON para a área de transferência ou
  /// salva em arquivo — os dois caminhos funcionam offline.
  Future<void> _exportTraining(TrainingPlan plan) async {
    final json = TrainingTransfer.export(plan);
    final exerciseCount = plan.days.fold<int>(0, (sum, d) => sum + d.totalExercises);
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Exportar treino', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800)),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${plan.name} · ${plan.days.length} dias · $exerciseCount exercícios',
                style: GoogleFonts.inter(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Copie o JSON ou salve o arquivo e importe em outro aparelho. Funciona sem internet. O histórico de sessões fica neste aparelho.',
                style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: SingleChildScrollView(
                  child: Text(json, style: GoogleFonts.jetBrainsMono(color: AppTheme.textMuted, fontSize: 11, height: 1.4)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Fechar')),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: json));
              if (!dialogCtx.mounted) return;
              Navigator.pop(dialogCtx);
              _snack('JSON do treino copiado');
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copiar'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final feedback = await _saveTrainingFile(json);
              if (feedback == null || !dialogCtx.mounted) return;
              Navigator.pop(dialogCtx);
              _snack(feedback);
            },
            icon: const Icon(Icons.save_alt, size: 16),
            label: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  /// Salva o JSON como arquivo. Retorna o feedback (null = usuário cancelou).
  Future<String?> _saveTrainingFile(String json) async {
    try {
      final uri = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar treino',
        fileName: TrainingTransfer.fileName,
        bytes: Uint8List.fromList(utf8.encode(json)),
      );
      if (uri == null) return null;
      return 'Treino exportado em ${TrainingTransfer.fileName}';
    } catch (e) {
      return 'Falha ao salvar o arquivo: $e';
    }
  }

  /// Lê o arquivo escolhido. Retorna null quando o usuário cancela.
  Future<({String? text, String? error})?> _pickTrainingFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
        dialogTitle: 'Selecionar treino exportado',
      );
      if (result == null || result.files.isEmpty) return null;
      final bytes = result.files.first.bytes;
      if (bytes == null) {
        return (text: null, error: 'Não foi possível ler o conteúdo do arquivo.');
      }
      return (text: utf8.decode(bytes, allowMalformed: true), error: null);
    } catch (e) {
      return (text: null, error: 'Falha ao ler o arquivo: $e');
    }
  }

  /// Dialog de importação: cola o JSON ou escolhe o arquivo exportado.
  Future<void> _importTraining() async {
    final state = context.read<AppState>();
    final controller = TextEditingController();
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text('Importar treino', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cole o JSON exportado em outro aparelho ou escolha o arquivo .json.',
                  style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  maxLines: 5,
                  style: GoogleFonts.jetBrainsMono(fontSize: 11),
                  decoration: const InputDecoration(hintText: '{"format": "nutricoach-treino", ...}'),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await _pickTrainingFile();
                    if (picked == null) return;
                    setState(() {
                      if (picked.text != null) controller.text = picked.text!;
                      error = picked.error;
                    });
                  },
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('Escolher arquivo'),
                ),
                if (error != null)
                  Text(error!, style: GoogleFonts.inter(color: AppTheme.danger, fontSize: 12)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancelar')),
            FilledButton.icon(
              onPressed: () async {
                try {
                  final plan = await state.importTrainingPlan(controller.text);
                  if (!dialogCtx.mounted) return;
                  Navigator.pop(dialogCtx);
                  _snack('Treino importado: ${plan.name} · ${plan.days.length} dias');
                } on FormatException catch (e) {
                  setState(() => error = e.message);
                } catch (e) {
                  setState(() => error = 'Falha ao importar: $e');
                }
              },
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Importar'),
            ),
          ],
        ),
      ),
    );
  }

  // ── FICHA ──

  Widget _buildFicha(AppState state, TrainingPlan plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(plan.name, style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              Text(
                '${plan.days.length} dias · ${plan.days.fold(0, (s, d) => s + d.totalExercises)} exercícios · ${plan.days.fold(0, (s, d) => s + d.totalSets)} séries',
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < plan.days.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      TrainingDivisionCard.letterFor(plan.days[i], i),
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(plan.days[i].name, style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    ),
                    Text('${plan.days[i].totalExercises} ex.', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
                const SizedBox(height: 8),
                for (final ex in plan.days[i].exercises)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(ex.name, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary))),
                        Text('${ex.sets}×${ex.repsLabel}', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                if (plan.days[i].exercises.isEmpty)
                  Text('Sem exercícios cadastrados', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textFaint)),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrainingEditor(plan: plan))),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Editar ficha'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrainingEditor())),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Novo plano'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('export-training'),
                onPressed: () => _exportTraining(plan),
                icon: const Icon(Icons.ios_share_outlined, size: 16),
                label: const Text('Exportar'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('import-training'),
                onPressed: _importTraining,
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Importar'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Leve a ficha para outro aparelho pelo JSON. O histórico de sessões fica neste dispositivo.',
          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, height: 1.4),
        ),
      ],
    );
  }

  // ── Cabeçalho e abas ──
}

class _Header extends StatelessWidget {
  const _Header({required this.plan, required this.state});
  final TrainingPlan plan;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'TREINO',
            style: GoogleFonts.spaceGrotesk(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -1),
          ),
        ),
        _HeaderAction(
          icon: Icons.history,
          tooltip: 'Histórico',
          onTap: () => _scrollTab(context, 2),
        ),
        _HeaderAction(
          icon: Icons.edit_outlined,
          tooltip: 'Editar ficha',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrainingEditor(plan: plan))),
        ),
        _HeaderAction(
          icon: Icons.swap_horiz,
          tooltip: 'Trocar plano',
          onTap: () => _pickPlan(context, state),
        ),
      ],
    );
  }

  static void _scrollTab(BuildContext context, int tab) {
    final host = context.findAncestorStateOfType<State<TrainingHomeScreen>>();
    if (host is _TrainingHomeScreenState) host.selectTab(tab);
  }

  Future<void> _pickPlan(BuildContext context, AppState state) async {
    if (state.trainingPlans.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você tem apenas um plano de treino.')),
      );
      return;
    }
    final chosen = await showModalBottomSheet<TrainingPlan>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Trocar plano', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            for (final p in state.trainingPlans)
              ListTile(
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${p.days.length} dias', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textMuted)),
                trailing: p.id == plan.id ? const Icon(Icons.check_circle, color: AppTheme.primary, size: 18) : null,
                onTap: () => Navigator.pop(ctx, p),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen != null) await state.setActiveTrainingPlan(chosen.id);
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      color: AppTheme.textSecondary,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      icon: Icon(icon, size: 20),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  static const _labels = ['Hoje', 'Ficha', 'Histórico'];
  static const _keys = ['hoje', 'ficha', 'historico'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: AppTheme.border, width: 0.8),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: Key('tab-${_keys[i]}'),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: index == i ? AppTheme.primaryMuted : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      border: index == i ? Border.all(color: AppTheme.primary.withValues(alpha: 0.5), width: 1) : null,
                    ),
                    child: Text(
                      _labels[i],
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: index == i ? FontWeight.w700 : FontWeight.w500,
                        color: index == i ? AppTheme.primary : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w700, letterSpacing: 1),
    );
  }
}

/// Banner do treino em andamento — tempo decorrido e continuar.
class _ActiveBanner extends StatefulWidget {
  const _ActiveBanner({required this.session, required this.plan});
  final TrainingSession session;
  final TrainingPlan plan;
  @override
  State<_ActiveBanner> createState() => _ActiveBannerState();
}

class _ActiveBannerState extends State<_ActiveBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    TrainingDay? day;
    for (final d in widget.plan.days) {
      if (d.id == widget.session.dayId) day = d;
    }
    if (day == null) return const SizedBox.shrink();
    final activeDay = day;

    final state = context.watch<AppState>();
    TrainingSession session = widget.session;
    for (final s in state.trainingSessions) {
      if (s.id == widget.session.id) session = s;
    }
    final progress = TrainingStats.sessionProgress(session, day);

    final elapsed = DateTime.now().difference(session.startAt ?? session.date);
    final mm = elapsed.inMinutes.toString().padLeft(2, '0');
    final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');

    return Semantics(
      label: 'Treino em andamento, ${day.name}, ${progress.done} de ${progress.total} exercícios',
      child: Container(
        key: const Key('active-session-banner'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primaryMuted,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.primary, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fitness_center, size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('TREINO EM ANDAMENTO', overflow: TextOverflow.ellipsis, style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.primary, letterSpacing: 1)),
                ),
                const SizedBox(width: 8),
                Text('$mm:$ss', style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primary)),
              ],
            ),
            const SizedBox(height: 10),
            Text(day.name.toUpperCase(), style: GoogleFonts.spaceGrotesk(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text('${progress.done}/${progress.total} exercícios · ${session.totalSets} séries', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                key: const Key('continue-training'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ActiveTrainingScreen(session: widget.session, day: activeDay)),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.textOnPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusFull)),
                ),
                child: const Text('CONTINUAR TREINO'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementList extends StatelessWidget {
  const _AchievementList({required this.sessions, required this.weeklyTarget});
  final List<TrainingSession> sessions;
  final int weeklyTarget;

  @override
  Widget build(BuildContext context) {
    final list = TrainingStats.achievements(sessions, weeklyTarget: weeklyTarget);
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.95,
      children: [for (final a in list) AchievementCard(achievement: a)],
    );
  }
}

class _EmptyTraining extends StatelessWidget {
  const _EmptyTraining({required this.onImport});
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.fitness_center, size: 32, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            Text('Você ainda não possui um treino cadastrado', textAlign: TextAlign.center, style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text('Monte sua rotina e deixe o registro\nda academia muito mais rápido.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('create-training'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrainingEditor())),
              icon: const Icon(Icons.add, size: 18),
              label: Text('Criar treino', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('import-training-empty'),
              onPressed: onImport,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Importar treino'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: const BorderSide(color: AppTheme.border),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Já montou a ficha em outro aparelho? Importe o arquivo JSON exportado de lá.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
