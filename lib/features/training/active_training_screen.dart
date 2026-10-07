import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/training.dart';
import '../../state/app_state.dart';

/// Modo Treino — exercício protagonista, registro rápido, descanso, progressão.
/// Uso com 1 mão na academia. Sem formulário corporativo.
class ActiveTrainingScreen extends StatefulWidget {
  const ActiveTrainingScreen({super.key, required this.session, required this.day});
  final TrainingSession session;
  final TrainingDay day;
  @override
  State<ActiveTrainingScreen> createState() => _ActiveTrainingScreenState();
}

class _ActiveTrainingScreenState extends State<ActiveTrainingScreen> {
  int _currentExercise = 0;
  int _currentSet = 1;
  double _weight = 0;
  int _reps = 10;
  Timer? _restTimer;
  int _restLeft = 0;
  bool _isPR = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.day.exercises.isNotEmpty ? widget.day.exercises[_currentExercise] : null;
    if (ex != null) {
      _weight = ex.loadKg;
      _reps = ex.repsMin;
      _checkPR();
    }
  }

  void _checkPR() {
    // verifica se é recorde: compara com histórico
    final state = context.read<AppState>();
    final exId = widget.day.exercises[_currentExercise].id;
    double best = 0;
    for (final s in state.trainingSessions) {
      for (final es in s.exercises) {
        if (es.exerciseId == exId) {
          for (final set in es.sets) {
            final vol = set.weight * set.reps;
            if (vol > best) best = vol;
          }
        }
      }
    }
    final curVol = _weight * _reps;
    setState(() => _isPR = curVol > best && best > 0);
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  void _startRest(int seconds) {
    _restTimer?.cancel();
    setState(() => _restLeft = seconds);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_restLeft <= 1) {
        t.cancel();
        setState(() => _restLeft = 0);
      } else {
        setState(() => _restLeft--);
      }
    });
  }

  Future<void> _concluirSerie() async {
    final state = context.read<AppState>();
    final ex = widget.day.exercises[_currentExercise];
    await state.addSetToSession(widget.session.id, ex.id, TrainingSet(weight: _weight, reps: _reps, completedAt: DateTime.now(), isPR: _isPR));
    // descanso
    _startRest(ex.restSeconds);
    // avança série ou exercício
    if (_currentSet < ex.sets) {
      setState(() => _currentSet++);
    } else if (_currentExercise < widget.day.exercises.length - 1) {
      setState(() {
        _currentExercise++;
        _currentSet = 1;
        final next = widget.day.exercises[_currentExercise];
        _weight = next.loadKg;
        _reps = next.repsMin;
        _checkPR();
      });
    } else {
      // finalizou todos
      _showFinished();
    }
  }

  void _showFinished() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('TREINO CONCLUÍDO', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800, letterSpacing: 0.6)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${widget.day.exercises.length} exercícios', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
            Text('${widget.day.exercises.fold(0, (s, e) => s + e.sets)} séries', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
            if (_isPR) const SizedBox(height: 12),
            if (_isPR) Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)), child: Text('2 progressões', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppTheme.warning, fontWeight: FontWeight.w700))),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              await context.read<AppState>().finishTrainingSession(widget.session.id);
              if (mounted) {
                Navigator.pop(context); // fecha dialog
                Navigator.pop(context); // volta pra home treino
              }
            },
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.day.exercises[_currentExercise];
    final totalEx = widget.day.exercises.length;
    // última vez
    final state = context.watch<AppState>();
    final lastSets = _lastSetsFor(ex.id, state);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.day.name.toUpperCase()}', style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AppTheme.textPrimary)),
            Text('${_currentExercise + 1} de $totalEx', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progresso do treino
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(value: (_currentExercise + (_currentSet / ex.sets)) / totalEx, minHeight: 4, backgroundColor: AppTheme.surfaceLight, valueColor: const AlwaysStoppedAnimation(AppTheme.primary)),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  // Exercício protagonista
                  Text(ex.name.toUpperCase(), style: GoogleFonts.spaceGrotesk(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.8)),
                  if (ex.muscleGroup != null) Text(ex.muscleGroup!.toUpperCase(), style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textFaint, letterSpacing: 0.6)),
                  const SizedBox(height: 6),
                  Text('${ex.sets} × ${ex.repsLabel}', style: GoogleFonts.jetBrainsMono(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  // Última vez
                  if (lastSets.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border, width: 0.8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ÚLTIMA VEZ', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textFaint, letterSpacing: 0.6)),
                          const SizedBox(height: 6),
                          Text(lastSets.map((s) => '${s.weight.round()} kg × ${s.reps}').join('  •  '), style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  // Placa de série — signature
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border, width: 0.8)),
                    child: Column(
                      children: [
                        Text('SÉRIE $_currentSet/${ex.sets}', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textMuted, letterSpacing: 0.6)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _StepperButton(icon: Icons.remove, onTap: () => setState(() => _weight = (_weight - 2.5).clamp(0, 500))),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(_weight.toStringAsFixed(_weight % 1 == 0 ? 0 : 1), style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, fontFeatures: const [FontFeature.tabularFigures()])),
                                  Text('KG', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textMuted)),
                                ],
                              ),
                            ),
                            _StepperButton(icon: Icons.add, onTap: () => setState(() { _weight += 2.5; _checkPR(); })),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _StepperButton(icon: Icons.remove, onTap: () => setState(() => _reps = (_reps - 1).clamp(1, 50))),
                            Expanded(
                              child: Column(
                                children: [
                                  Text('$_reps', style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, fontFeatures: const [FontFeature.tabularFigures()])),
                                  Text('REPS', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textMuted)),
                                ],
                              ),
                            ),
                            _StepperButton(icon: Icons.add, onTap: () => setState(() => _reps++)),
                          ],
                        ),
                        if (_isPR) ...[
                          const SizedBox(height: 12),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.emoji_events, size: 12, color: AppTheme.warning), const SizedBox(width: 4), Text('Novo recorde', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.warning, fontWeight: FontWeight.w700))])),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _concluirSerie,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
                      child: Text('✓ CONCLUIR SÉRIE', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800, letterSpacing: 0.4)),
                    ),
                  ),
                  if (_restLeft > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        children: [
                          Text('DESCANSO', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textFaint, letterSpacing: 0.6)),
                          const SizedBox(height: 6),
                          Text('${(_restLeft ~/ 60).toString().padLeft(2, '0')}:${(_restLeft % 60).toString().padLeft(2, '0')}', style: GoogleFonts.spaceGrotesk(fontSize: 32, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, fontFeatures: const [FontFeature.tabularFigures()])),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: OutlinedButton(onPressed: () { _restTimer?.cancel(); setState(() => _restLeft = 0); }, child: const Text('Pular'))),
                              const SizedBox(width: 12),
                              Expanded(child: Text('Próxima\n${ex.loadKg.round()} kg × ${ex.repsMin}', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Navegação exercícios
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(color: AppTheme.surface, border: Border(top: BorderSide(color: AppTheme.border, width: 0.8))),
              child: Row(
                children: [
                  if (_currentExercise > 0)
                    TextButton(onPressed: () => setState(() { _currentExercise--; _currentSet = 1; }), child: const Text('← Anterior'))
                  else
                    const SizedBox(width: 80),
                  const Spacer(),
                  Text('${_currentExercise + 1} / $totalEx', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppTheme.textMuted)),
                  const Spacer(),
                  TextButton(onPressed: _currentExercise < totalEx - 1 ? () => setState(() { _currentExercise++; _currentSet = 1; }) : null, child: const Text('Próximo →')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<TrainingSet> _lastSetsFor(String exerciseId, AppState state) {
    for (final s in state.trainingSessions) {
      for (final es in s.exercises) {
        if (es.exerciseId == exerciseId && es.sets.isNotEmpty) return es.sets;
      }
    }
    return [];
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(width: 44, height: 44, decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border, width: 0.8)), child: Icon(icon, size: 18, color: AppTheme.textPrimary)),
    );
  }
}
