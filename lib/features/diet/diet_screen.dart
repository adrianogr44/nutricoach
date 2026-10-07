import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/diet.dart';
import '../../state/app_state.dart';
import '../../widgets/core_widgets.dart';

import 'diet_meal_daily_card.dart';
import 'diet_meal_editor.dart';

/// Tela "Minha Dieta" — foco na rotina alimentar de hoje.
///
/// O dia a dia (refeições, progresso, próximo check-in) é o conteúdo principal;
/// a gestão do plano (renomear, apagar, editar, adicionar) é secundária.
class DietScreen extends StatelessWidget {
  const DietScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final diet = state.activeDiet;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha Dieta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        actions: diet == null
            ? null
            : [
                IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _renameDiet(context, diet)),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'delete') _confirmDeleteDiet(context, diet);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: AppTheme.danger, size: 18), SizedBox(width: 8), Text('Apagar dieta')])),
                  ],
                ),
              ],
      ),
      body: diet == null ? _EmptyDiet(onCreate: () => _createDiet(context)) : _DietDailyList(diet: diet),
    );
  }

  Future<void> _createDiet(BuildContext context) async {
    final controller = TextEditingController(text: 'Minha Dieta');
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Criar dieta'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Nome da dieta'), autofocus: true),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Criar'))],
      ),
    );
    if (name == null) return;
    if (!context.mounted) return;
    final state = context.read<AppState>();
    await state.createDiet(name);
  }

  Future<void> _renameDiet(BuildContext context, DietPlan diet) async {
    final controller = TextEditingController(text: diet.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Renomear dieta'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Nome')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Salvar'))],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    if (!context.mounted) return;
    final state = context.read<AppState>();
    await state.updateDiet(diet.copyWith(name: name));
  }

  Future<void> _confirmDeleteDiet(BuildContext context, DietPlan diet) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Apagar dieta?'),
        content: const Text('Isso remove todas as refeições planejadas. O histórico consumido não é afetado.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(style: FilledButton.styleFrom(backgroundColor: AppTheme.danger), onPressed: () => Navigator.pop(context, true), child: const Text('Apagar'))],
      ),
    );
    if (ok == true) {
      if (!context.mounted) return;
      final state = context.read<AppState>();
      await state.deleteDiet(diet.id);
    }
  }
}

/// Lista diária: progresso do dia, refeições na ordem do plano e check-in por swipe.
class _DietDailyList extends StatefulWidget {
  const _DietDailyList({required this.diet});

  final DietPlan diet;

  @override
  State<_DietDailyList> createState() => _DietDailyListState();
}

class _DietDailyListState extends State<_DietDailyList> {
  final GlobalKey _listKey = GlobalKey(debugLabel: 'diet-daily-list');
  final Map<String, GlobalKey> _mealKeys = {};
  bool _logging = false;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  GlobalKey _keyFor(String id) => _mealKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'diet-meal-$id'));

  List<DietMeal> get _orderedMeals {
    final meals = [...widget.diet.meals];
    meals.sort((a, b) => a.order.compareTo(b.order));
    return meals;
  }

  String _progressLabel(int done, int total) =>
      '$done de $total ${total == 1 ? 'refeição concluída' : 'refeições concluídas'}';

  /// Conclusão por swipe: registra no diário (identidade própria, desacoplada).
  Future<bool> _complete(DietMeal meal) async {
    if (_logging) return false;
    final state = context.read<AppState>();
    if (state.dietMealStatusFor(_today, meal) == 'consumed') return true;
    _logging = true;
    try {
      final created = await state.logDietMeal(dietMeal: meal, date: _today);
      if (created == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não foi possível registrar esta refeição. Edite a refeição e confira os alimentos.')),
          );
        }
        return false;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${meal.name} registrado')));
        _scrollToNextSoon();
      }
      return true;
    } finally {
      _logging = false;
    }
  }

  /// Desfazer remove somente o registro desta refeição deste dia (identidade exata).
  Future<void> _undo(DietMeal meal) async {
    final state = context.read<AppState>();
    final marker = 'Dieta:${meal.id}:${meal.name}';
    final legacyMarker = 'Dieta: ${meal.name}';
    final targets = state
        .mealsOn(_today)
        .where((m) => m.rawText == marker || m.rawText == legacyMarker)
        .toList();
    if (targets.isEmpty) return;
    for (final target in targets) {
      await state.removeMeal(target.id);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${meal.name} desfeita')));
  }

  /// Rola até a próxima refeição não concluída, depois que a animação do swipe acaba.
  void _scrollToNextSoon() {
    Future.delayed(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      final state = context.read<AppState>();
      DietMeal? next;
      for (final meal in _orderedMeals) {
        if (state.dietMealStatusFor(_today, meal) != 'consumed') {
          next = meal;
          break;
        }
      }
      if (next == null) return;
      final cardCtx = _mealKeys[next.id]?.currentContext;
      if (cardCtx == null || !cardCtx.mounted) return;
      final listRender = _listKey.currentContext?.findRenderObject();
      if (listRender is! RenderBox) return;
      final cardRender = cardCtx.findRenderObject();
      if (cardRender is! RenderBox || !cardRender.hasSize) return;
      final top = cardRender.localToGlobal(Offset.zero, ancestor: listRender);
      final visible = top.dy >= 0 && top.dy + cardRender.size.height <= listRender.size.height;
      if (visible) return;
      Scrollable.ensureVisible(
        cardCtx,
        alignment: 0.25,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final diet = widget.diet;
    final foodMap = state.foodByIdMap;
    final meals = _orderedMeals;

    if (meals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(22)),
                child: const Icon(Icons.restaurant_menu, size: 34, color: AppTheme.primary),
              ),
              const SizedBox(height: 16),
              Text(diet.name, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              const Text('Sua dieta ainda não possui refeições.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              const Text('Adicione as refeições do plano para acompanhar o dia a dia.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4)),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => _addMeal(context, diet),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar refeição'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), side: const BorderSide(color: AppTheme.border)),
              ),
            ],
          ),
        ),
      );
    }

    final statuses = {for (final m in meals) m.id: state.dietMealStatusFor(_today, m)};
    final total = meals.length;
    final done = statuses.values.where((s) => s == 'consumed').length;
    String? nextId;
    for (final meal in meals) {
      if (statuses[meal.id] != 'consumed') {
        nextId = meal.id;
        break;
      }
    }
    final allDone = done == total;
    final totals = diet.totalsWith(foodMap);

    // SingleChildScrollView + Column: todos os cards ficam montados, o que
    // permite rolar até qualquer refeição (inclusive as fora da tela).
    return SingleChildScrollView(
      key: _listKey,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(diet.name, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          const Text('Dieta de hoje', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  _progressLabel(done, total),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                ),
              ),
              if (allDone) ...[
                const Icon(Icons.check_circle, size: 18, color: AppTheme.primary),
                const SizedBox(width: 6),
                const Text('Dieta do dia concluída', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primary)),
              ],
            ],
          ),
          const SizedBox(height: 10),
          GradientBar(progress: total == 0 ? 0 : done / total, color: AppTheme.primary, height: 8),
          const SizedBox(height: 20),
          for (final meal in meals)
            DietMealDailyCard(
              key: _keyFor(meal.id),
              meal: meal,
              status: statuses[meal.id]!,
              isNext: meal.id == nextId,
              onCompleted: () => _complete(meal),
              onUndo: () => _undo(meal),
              onEdit: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DietMealEditor(diet: diet, existing: meal))),
              onDelete: () => context.read<AppState>().removeDietMeal(diet.id, meal.id),
            ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 18),
          const Text('Plano', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textMuted)),
          const SizedBox(height: 8),
          Text('${totals['kcal']!.round()} kcal planejadas', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            children: [
              _macroChip('P ${totals['protein']!.round()}g', AppTheme.macroProtein),
              _macroChip('C ${totals['carbs']!.round()}g', AppTheme.macroCarbs),
              _macroChip('G ${totals['fat']!.round()}g', AppTheme.macroFat),
            ],
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => _addMeal(context, diet),
            icon: const Icon(Icons.add),
            label: const Text('Adicionar refeição'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), side: const BorderSide(color: AppTheme.border)),
          ),
        ],
      ),
    );
  }

  Widget _macroChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }

  Future<void> _addMeal(BuildContext context, DietPlan diet) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DietMealEditor(diet: diet)),
    );
  }
}

class _EmptyDiet extends StatelessWidget {
  const _EmptyDiet({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 80, height: 80, decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(24)), child: const Icon(Icons.restaurant_menu, size: 40, color: AppTheme.primary)),
            const SizedBox(height: 16),
            const Text('Crie sua dieta', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            const Text('Você ainda não possui uma dieta ativa. Monte suas refeições padrão uma vez e acompanhe o dia a dia com swipe.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4)),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Criar dieta')),
            const SizedBox(height: 12),
            const Text('Você pode registrar refeições manualmente mesmo sem dieta.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
