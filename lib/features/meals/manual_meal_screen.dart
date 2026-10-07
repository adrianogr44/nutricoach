import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/food.dart';
import '../../data/models/meal.dart';
import '../../services/household_measure.dart';
import '../../state/app_state.dart';
import 'food_search_screen.dart';
import '../diet/diet_meal_editor.dart' show showDietQuantityPicker;
import '../../data/models/diet.dart';

/// Builder manual de refeição inteira — vários alimentos com medidas caseiras antes de salvar.
/// Atende: "Permitir cadastrar vários alimentos antes de salvar" + medidas caseiras.
class ManualMealScreen extends StatefulWidget {
  const ManualMealScreen({super.key});
  @override
  State<ManualMealScreen> createState() => _ManualMealScreenState();
}

class _ManualMealScreenState extends State<ManualMealScreen> {
  final List<MealItem> _items = [];
  MealType _type = MealType.almoco;

  @override
  Widget build(BuildContext context) {
    final totals = _totals();
    return Scaffold(
      appBar: AppBar(title: const Text('Montar refeição', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // Tipo
          Row(
            children: [
              const Text('Refeição:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(width: 12),
              DropdownButton<MealType>(
                value: _type,
                items: [for (final t in MealType.values) DropdownMenuItem(value: t, child: Text('${t.emoji} ${t.label}'))],
                onChanged: (v) => setState(() => _type = v ?? MealType.almoco),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_items.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(14)),
              child: const Text('Nenhum alimento adicionado. Toque abaixo para começar.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            )
          else
            for (var i = 0; i < _items.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_items[i].food.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          Text('${_items[i].quantityGrams.round()} g · ${ _items[i].nutrition.kcal.round()} kcal · P ${_items[i].nutrition.protein.round()}g', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _editItem(i)),
                    IconButton(icon: const Icon(Icons.close, size: 18, color: AppTheme.danger), onPressed: () => setState(() => _items.removeAt(i))),
                  ],
                ),
              ),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: _addFood, icon: const Icon(Icons.add), label: const Text('Adicionar alimento')),
          const SizedBox(height: 20),
          if (_items.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total · ${_items.length} itens', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('${totals.kcal.round()} kcal', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  Text('P ${totals.protein.round()}g · C ${totals.carbs.round()}g · G ${totals.fat.round()}g', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: Text('Registrar ${_type.label}'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  ({double kcal, double protein, double carbs, double fat}) _totals() {
    double kcal = 0, p = 0, c = 0, f = 0;
    for (final it in _items) {
      kcal += it.nutrition.kcal;
      p += it.nutrition.protein;
      c += it.nutrition.carbs;
      f += it.nutrition.fat;
    }
    return (kcal: kcal, protein: p, carbs: c, fat: f);
  }

  Future<void> _addFood() async {
    final food = await Navigator.push<Food>(context, MaterialPageRoute(builder: (_) => const FoodSearchScreen(compactPicker: true, pickerLabel: 'Selecionar alimento')));
    if (food == null || !mounted) return;
    final picked = await showDietQuantityPicker(context, food);
    if (picked == null || !mounted) return;
    final grams = const HouseholdMeasureConverter().toGrams(food, picked.quantity, picked.unit, customGramsPerUnit: picked.customGramsPerUnit);
    setState(() => _items.add(MealItem(food: food, quantityGrams: grams)));
  }

  Future<void> _editItem(int index) async {
    final current = _items[index];
    // Recria DietMealItem temporário para re-usar picker
    final temp = DietMealItem(foodId: current.food.id, quantity: current.quantityGrams, unit: MeasureUnit.g, foodSnapshot: current.food);
    final picked = await showDietQuantityPicker(context, current.food, initial: temp);
    if (picked == null) return;
    final grams = const HouseholdMeasureConverter().toGrams(current.food, picked.quantity, picked.unit, customGramsPerUnit: picked.customGramsPerUnit);
    setState(() => _items[index] = MealItem(food: current.food, quantityGrams: grams));
  }

  Future<void> _save() async {
    if (_items.isEmpty) return;
    final state = context.read<AppState>();
    final meal = state.buildMeal(date: DateTime.now(), type: _type, items: [..._items]);
    await state.addMeal(meal);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ ${_type.label} registrado — ${meal.totalKcal.round()} kcal')));
  }
}
