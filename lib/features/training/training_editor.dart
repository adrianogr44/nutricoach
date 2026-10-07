import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/training.dart';
import '../../state/app_state.dart';

class TrainingEditor extends StatefulWidget {
  const TrainingEditor({super.key, this.plan});
  final TrainingPlan? plan;
  @override
  State<TrainingEditor> createState() => _TrainingEditorState();
}

class _TrainingEditorState extends State<TrainingEditor> {
  late TextEditingController _name;
  late List<TrainingDay> _days;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.plan?.name ?? 'Meu Treino');
    _days = [...?widget.plan?.days];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.plan == null ? 'Criar treino' : 'Editar treino', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w800)), actions: [TextButton(onPressed: _save, child: const Text('Salvar'))]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nome do plano', hintText: 'Ex: Costas + Bíceps')),
          const SizedBox(height: 20),
          Text('Dias'.toUpperCase(), style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textMuted, letterSpacing: 0.8)),
          const SizedBox(height: 12),
          for (var i = 0; i < _days.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border, width: 0.8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(_days[i].name, style: GoogleFonts.inter(fontWeight: FontWeight.w700))),
                      IconButton(
                        icon: const Icon(Icons.arrow_upward, size: 16),
                        tooltip: 'Mover para cima',
                        onPressed: i == 0 ? null : () => _moveDay(i, -1),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_downward, size: 16),
                        tooltip: 'Mover para baixo',
                        onPressed: i == _days.length - 1 ? null : () => _moveDay(i, 1),
                      ),
                      IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _editDay(i)),
                      IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger), onPressed: () => setState(() => _days.removeAt(i))),
                    ],
                  ),
                  if (_days[i].time != null) Text(_days[i].time!, style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textMuted)),
                  const SizedBox(height: 6),
                  Text('${_days[i].exercises.length} exercícios · ${_days[i].totalSets} séries', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  for (final ex in _days[i].exercises)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(ex.name, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary))),
                          Text('${ex.sets}×${ex.repsLabel} ${ex.loadKg > 0 ? "${ex.loadKg.round()}kg" : ""}', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          OutlinedButton.icon(onPressed: _addDay, icon: const Icon(Icons.add), label: const Text('Adicionar dia')),
          const SizedBox(height: 20),
          const Divider(color: AppTheme.border),
          const SizedBox(height: 12),
          Text('Dica: organize por SEG/TER... e deixe o app sugerir o treino de hoje automaticamente.', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textFaint, height: 1.4)),
        ],
      ),
    );
  }

  Future<void> _addDay() async {
    final result = await showDialog<TrainingDay>(
      context: context,
      builder: (_) => _DayDialog(),
    );
    if (result != null) setState(() => _days.add(result));
  }

  Future<void> _editDay(int index) async {
    final result = await showDialog<TrainingDay>(
      context: context,
      builder: (_) => _DayDialog(initial: _days[index]),
    );
    if (result != null) setState(() => _days[index] = result);
  }

  /// Reordena as divisões da ficha.
  void _moveDay(int index, int delta) {
    setState(() {
      final target = index + delta;
      final day = _days.removeAt(index);
      _days.insert(target, day);
    });
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    if (widget.plan == null) {
      final plan = await state.createTrainingPlan(_name.text);
      for (final d in _days) {
        final newDay = await state.addTrainingDay(plan.id, name: d.name, weekday: d.weekday, time: d.time);
        for (final ex in d.exercises) {
          await state.addExerciseToDay(plan.id, newDay.id, ex);
        }
      }
    } else {
      await state.updateTrainingPlan(widget.plan!.copyWith(name: _name.text, days: _days));
    }
    if (mounted) Navigator.pop(context);
  }
}

class _DayDialog extends StatefulWidget {
  const _DayDialog({this.initial});
  final TrainingDay? initial;
  @override
  State<_DayDialog> createState() => _DayDialogState();
}

class _DayDialogState extends State<_DayDialog> {
  late TextEditingController _name;
  late TextEditingController _time;
  int? _weekday;
  late List<ExerciseDef> _exs;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? 'Costas + Bíceps');
    _time = TextEditingController(text: widget.initial?.time ?? '19:00');
    _weekday = widget.initial?.weekday;
    _exs = [...?widget.initial?.exercises];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text(widget.initial == null ? 'Novo dia' : 'Editar dia', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nome', hintText: 'Costas + Bíceps')),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: _weekday,
                decoration: const InputDecoration(labelText: 'Dia da semana'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Sem dia fixo')),
                  DropdownMenuItem(value: 1, child: Text('Segunda')),
                  DropdownMenuItem(value: 2, child: Text('Terça')),
                  DropdownMenuItem(value: 3, child: Text('Quarta')),
                  DropdownMenuItem(value: 4, child: Text('Quinta')),
                  DropdownMenuItem(value: 5, child: Text('Sexta')),
                  DropdownMenuItem(value: 6, child: Text('Sábado')),
                  DropdownMenuItem(value: 0, child: Text('Domingo')),
                ],
                onChanged: (v) => setState(() => _weekday = v),
              ),
              const SizedBox(height: 12),
              TextField(controller: _time, decoration: const InputDecoration(labelText: 'Horário', hintText: '19:00')),
              const SizedBox(height: 16),
              ..._exs.asMap().entries.map((entry) {
                final i = entry.key;
                final ex = entry.value;
                return ListTile(
                  dense: true,
                  title: Text(ex.name, style: GoogleFonts.inter(fontSize: 12)),
                  subtitle: Text('${ex.sets}×${ex.repsLabel} ${ex.loadKg.round()}kg', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textMuted)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_upward, size: 15),
                        tooltip: 'Mover para cima',
                        onPressed: i == 0 ? null : () => setState(() => _exs.insert(i - 1, _exs.removeAt(i))),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_downward, size: 15),
                        tooltip: 'Mover para baixo',
                        onPressed: i == _exs.length - 1 ? null : () => setState(() => _exs.insert(i + 1, _exs.removeAt(i))),
                      ),
                      IconButton(icon: const Icon(Icons.close, size: 16), tooltip: 'Remover', onPressed: () => setState(() => _exs.removeAt(i))),
                    ],
                  ),
                );
              }),
              OutlinedButton.icon(onPressed: _addExercise, icon: const Icon(Icons.add, size: 16), label: const Text('Adicionar exercício')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final day = TrainingDay(id: widget.initial?.id ?? DateTime.now().millisecondsSinceEpoch.toString(), name: _name.text, weekday: _weekday, time: _time.text, exercises: _exs);
            Navigator.pop(context, day);
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }

  Future<void> _addExercise() async {
    final ex = await showDialog<ExerciseDef>(
      context: context,
      builder: (_) => _ExerciseDialog(),
    );
    if (ex != null) setState(() => _exs.add(ex));
  }
}

class _ExerciseDialog extends StatefulWidget {
  @override
  State<_ExerciseDialog> createState() => _ExerciseDialogState();
}

class _ExerciseDialogState extends State<_ExerciseDialog> {
  final _name = TextEditingController(text: 'Puxada alta');
  final _sets = TextEditingController(text: '3');
  final _repsMin = TextEditingController(text: '10');
  final _repsMax = TextEditingController(text: '12');
  final _load = TextEditingController(text: '55');
  final _rest = TextEditingController(text: '90');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text('Exercício', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nome')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _sets, decoration: const InputDecoration(labelText: 'Séries'), keyboardType: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _repsMin, decoration: const InputDecoration(labelText: 'Reps min'), keyboardType: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _repsMax, decoration: const InputDecoration(labelText: 'Reps max'), keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _load, decoration: const InputDecoration(labelText: 'Carga kg'), keyboardType: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _rest, decoration: const InputDecoration(labelText: 'Descanso s'), keyboardType: TextInputType.number)),
            ]),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final ex = ExerciseDef(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: _name.text,
              sets: int.tryParse(_sets.text) ?? 3,
              repsMin: int.tryParse(_repsMin.text) ?? 10,
              repsMax: int.tryParse(_repsMax.text) ?? 12,
              loadKg: double.tryParse(_load.text.replaceAll(',', '.')) ?? 0,
              restSeconds: int.tryParse(_rest.text) ?? 90,
            );
            Navigator.pop(context, ex);
          },
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}
