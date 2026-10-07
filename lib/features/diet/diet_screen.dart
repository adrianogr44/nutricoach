import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/diet.dart';
import '../../services/household_measure.dart';
import '../../state/app_state.dart';

import 'diet_meal_editor.dart';

/// Tela "Minha Dieta" â€” template planejado separado do diário real.
class DietScreen extends StatelessWidget {
  const DietScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final diet = state.activeDiet;

    if (diet == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Minha Dieta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        body: _EmptyDiet(onCreate: () => _createDiet(context)),
      );
    }

    final foodMap = state.foodByIdMap;
    final totals = diet.totalsWith(foodMap);
    final kcal = totals['kcal']!;
    final protein = totals['protein']!;
    final carbs = totals['carbs']!;
    final fat = totals['fat']!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha Dieta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        actions: [
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // Resumo total
          Text(diet.name, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          Text('${kcal.round()} kcal planejadas', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            children: [
              _macroChip('P ${protein.round()}g', AppTheme.danger),
              _macroChip('C ${carbs.round()}g', AppTheme.warning),
              _macroChip('G ${fat.round()}g', AppTheme.accent),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 20),
          for (final meal in diet.meals) _DietMealCard(meal: meal, foodMap: foodMap, diet: diet),
          const SizedBox(height: 20),
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
      final state = context.read<AppState>();
      await state.deleteDiet(diet.id);
    }
  }

  Future<void> _addMeal(BuildContext context, DietPlan diet) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DietMealEditor(diet: diet)),
    );
  }
}

class _DietMealCard extends StatelessWidget {
  const _DietMealCard({required this.meal, required this.foodMap, required this.diet});
  final DietMeal meal;
  final Map<String, dynamic> foodMap;
  final DietPlan diet;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final fMap = state.foodByIdMap;
    final totals = meal.totals(fMap);
    final kcal = totals['kcal']!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (meal.time != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(8)),
                  child: Text(meal.time!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(meal.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary))),
              Text('${kcal.round()} kcal', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') Navigator.push(context, MaterialPageRoute(builder: (_) => DietMealEditor(diet: diet, existing: meal)));
                  if (v == 'delete') context.read<AppState>().removeDietMeal(diet.id, meal.id);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'delete', child: Text('Excluir')),
                ],
                icon: const Icon(Icons.more_horiz, size: 18, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (meal.items.isEmpty)
            const Text('Nenhum alimento â€” toque em Editar para adicionar.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13))
          else
            for (final item in meal.items) _DietItemRow(item: item, foodMap: fMap),
        ],
      ),
    );
  }
}

class _DietItemRow extends StatelessWidget {
  const _DietItemRow({required this.item, required this.foodMap});
  final DietMealItem item;
  final Map<String, dynamic> foodMap;

  @override
  Widget build(BuildContext context) {
    final food = foodMap[item.foodId];
    if (food == null) return ListTile(title: Text(item.foodId), subtitle: const Text('Alimento não encontrado'));
    final converter = const HouseholdMeasureConverter();
    final display = converter.displayFor(food, item.quantity, item.unit, customGramsPerUnit: item.customGramsPerUnit);
    final grams = converter.toGrams(food, item.quantity, item.unit, customGramsPerUnit: item.customGramsPerUnit);
    final nutr = food.nutritionFor(grams);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.circle, size: 6, color: AppTheme.textMuted)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(food.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                Text(display, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text('${nutr.kcal.round()} kcal', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
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
            const Text('Monte suas refeições padrão uma vez e use "Comi como planejado" no dia a dia. Mais rápido, sem recadastrar tudo.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4)),
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

