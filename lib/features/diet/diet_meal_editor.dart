import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/diet.dart';
import '../../data/models/food.dart';
import '../../services/household_measure.dart';
import '../../state/app_state.dart';
import '../meals/food_search_screen.dart';

/// Editor de uma refeição da dieta â€” nome, horário, alimentos com medidas caseiras.
class DietMealEditor extends StatefulWidget {
  const DietMealEditor({super.key, required this.diet, this.existing});
  final DietPlan diet;
  final DietMeal? existing;

  @override
  State<DietMealEditor> createState() => _DietMealEditorState();
}

class _DietMealEditorState extends State<DietMealEditor> {
  late TextEditingController _name;
  late TextEditingController _time;
  late List<DietMealItem> _items;

  static const _sugestoes = ['Café da manhã', 'Lanche da manhã', 'Almoço', 'Café da tarde', 'Jantar', 'Ceia', 'Outro'];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? 'Almoço');
    _time = TextEditingController(text: widget.existing?.time ?? '');
    _items = [...?widget.existing?.items];
  }

  @override
  void dispose() {
    _name.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar refeição' : 'Nova refeição', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        actions: [TextButton(onPressed: _save, child: const Text('Salvar', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800)))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // Nome + sugestões rápidas
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nome da refeição', hintText: 'Ex: Almoço')),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [for (final s in _sugestoes) ActionChip(label: Text(s, style: const TextStyle(fontSize: 11)), onPressed: () => setState(() => _name.text = s))],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _time,
            decoration: const InputDecoration(labelText: 'Horário (opcional)', hintText: 'Ex: 12:30', prefixIcon: Icon(Icons.schedule, size: 18)),
            keyboardType: TextInputType.datetime,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Alimentos', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text('${_items.length} itens', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(14)),
              child: const Text('Nenhum alimento ainda. Adicione arroz, feijão, frango...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            )
          else
            for (var i = 0; i < _items.length; i++) _itemTile(i),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _addFood, icon: const Icon(Icons.add), label: const Text('Adicionar alimento')),
          if (isEditing) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Excluir refeição'), content: const Text('Remover esta refeição da dieta?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir'))]));
                if (ok == true && mounted) {
                  await context.read<AppState>().removeDietMeal(widget.diet.id, widget.existing!.id);
                  if (mounted) Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
              label: const Text('Excluir refeição', style: TextStyle(color: AppTheme.danger)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.danger)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemTile(int index) {
    final state = context.watch<AppState>();
    final item = _items[index];
    final food = state.foodById(item.foodId) ?? item.foodSnapshot;
    if (food == null) return const SizedBox.shrink();
    final converter = const HouseholdMeasureConverter();
    final display = converter.displayFor(food, item.quantity, item.unit, customGramsPerUnit: item.customGramsPerUnit);
    final grams = converter.toGrams(food, item.quantity, item.unit, customGramsPerUnit: item.customGramsPerUnit);
    final nutr = food.nutritionFor(grams);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(food.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(display, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                Text('${nutr.kcal.round()} kcal Â· P ${nutr.protein.round()}g Â· C ${nutr.carbs.round()}g Â· G ${nutr.fat.round()}g', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.edit, size: 18, color: AppTheme.textSecondary), onPressed: () => _editItem(index)),
          IconButton(icon: const Icon(Icons.close, size: 18, color: AppTheme.textMuted), onPressed: () => setState(() => _items.removeAt(index))),
        ],
      ),
    );
  }

  Future<void> _addFood() async {
    final food = await Navigator.push<Food>(context, MaterialPageRoute(builder: (_) => FoodSearchScreen(onlyFavorites: false, compactPicker: true, pickerLabel: 'Selecionar alimento')));
    if (food == null || !mounted) return;
    final item = await showDietQuantityPicker(context, food);
    if (item != null) setState(() => _items.add(item));
  }

  Future<void> _editItem(int index) async {
    final state = context.read<AppState>();
    final item = _items[index];
    final food = state.foodById(item.foodId) ?? item.foodSnapshot;
    if (food == null) return;
    final updated = await showDietQuantityPicker(context, food, initial: item);
    if (updated != null) setState(() => _items[index] = updated);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o nome da refeição.')));
      return;
    }
    final state = context.read<AppState>();
    if (widget.existing == null) {
      final newMeal = await state.addDietMeal(widget.diet.id, name: name, time: _time.text.trim().isEmpty ? null : _time.text.trim());
      // adiciona itens
      for (final it in _items) {
        await state.addDietMealItem(widget.diet.id, newMeal.id, it);
      }
    } else {
      final updated = widget.existing!.copyWith(name: name, time: _time.text.trim().isEmpty ? null : _time.text.trim(), items: _items);
      await state.updateDietMeal(widget.diet.id, updated);
    }
    if (mounted) Navigator.pop(context);
  }
}

/// Bottom sheet para escolher quantidade + unidade (com medidas caseiras).
Future<DietMealItem?> showDietQuantityPicker(BuildContext context, Food food, {DietMealItem? initial}) {
  return showModalBottomSheet<DietMealItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _QuantityPickerSheet(food: food, initial: initial),
  );
}

class _QuantityPickerSheet extends StatefulWidget {
  const _QuantityPickerSheet({required this.food, this.initial});
  final Food food;
  final DietMealItem? initial;

  @override
  State<_QuantityPickerSheet> createState() => _QuantityPickerSheetState();
}

class _QuantityPickerSheetState extends State<_QuantityPickerSheet> {
  late double quantity;
  late MeasureUnit unit;
  late TextEditingController qtyController;
  late TextEditingController customController;
  bool showCustom = false;

  @override
  void initState() {
    super.initState();
    quantity = widget.initial?.quantity ?? 1;
    unit = widget.initial?.unit ?? _defaultUnitFor(widget.food);
    qtyController = TextEditingController(text: quantity.toStringAsFixed(quantity == quantity.roundToDouble() ? 0 : 1).replaceAll('.', ','));
    customController = TextEditingController(text: widget.initial?.customGramsPerUnit?.toStringAsFixed(0) ?? '');
    showCustom = widget.initial?.customGramsPerUnit != null;
  }

  MeasureUnit _defaultUnitFor(Food food) {
    if (food.category == 'Bebidas' || food.category == 'Leite e derivados') return MeasureUnit.copo;
    if (food.id.contains('arroz') || food.id.contains('feijao')) return MeasureUnit.concha;
    if (food.id.contains('pao')) return MeasureUnit.fatia;
    if (food.id.contains('ovo')) return MeasureUnit.unidade;
    return MeasureUnit.g;
  }

  @override
  Widget build(BuildContext context) {
    final converter = const HouseholdMeasureConverter();
    final customGrams = double.tryParse(customController.text.replaceAll(',', '.'));
    final grams = converter.toGrams(widget.food, quantity, unit, customGramsPerUnit: showCustom ? customGrams : null);
    final nutr = widget.food.nutritionFor(grams);
    final units = converter.availableFor(widget.food);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(widget.food.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                Text('${widget.food.kcal.round()} kcal/100g', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('â‰ˆ ${grams.round()} g', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primary)),
                  Text('${nutr.kcal.round()} kcal Â· P ${nutr.protein.round()}g Â· C ${nutr.carbs.round()}g Â· G ${nutr.fat.round()}g', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Quantidade', hintText: '1'),
                    onChanged: (v) {
                      final q = double.tryParse(v.replaceAll(',', '.')) ?? quantity;
                      setState(() => quantity = q <= 0 ? 1 : q);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<MeasureUnit>(initialValue: unit,
                    decoration: const InputDecoration(labelText: 'Medida'),
                    items: [for (final u in units) DropdownMenuItem(value: u, child: Text(u.label, style: const TextStyle(fontSize: 13)))],
                    onChanged: (v) => setState(() => unit = v ?? MeasureUnit.g),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(onPressed: () => setState(() { quantity = (quantity - 0.5).clamp(0.5, 999); qtyController.text = quantity.toStringAsFixed(1).replaceAll('.0', '').replaceAll('.', ','); }), icon: const Icon(Icons.remove_circle_outline)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => setState(() { quantity = (quantity + 0.5).clamp(0.5, 999); qtyController.text = quantity.toStringAsFixed(1).replaceAll('.0', '').replaceAll('.', ','); }), icon: const Icon(Icons.add_circle_outline)),
                const SizedBox(width: 8),
                if (unit != MeasureUnit.g && unit != MeasureUnit.kg)
                  Text(converter.displayFor(widget.food, quantity, unit, customGramsPerUnit: showCustom ? customGrams : null), style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: showCustom,
              onChanged: (v) => setState(() => showCustom = v ?? false),
              title: const Text('Medida personalizada (minha concha, meu copo...)', style: TextStyle(fontSize: 12)),
              subtitle: const Text('Informe quantos gramas tem sua medida em casa', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (showCustom)
              TextField(
                controller: customController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Gramas por unidade (ex: 120)', suffixText: 'g'),
                onChanged: (_) => setState(() {}),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final q = double.tryParse(qtyController.text.replaceAll(',', '.')) ?? quantity;
                  final cg = showCustom ? double.tryParse(customController.text.replaceAll(',', '.')) : null;
                  final item = DietMealItem(foodId: widget.food.id, quantity: q, unit: unit, customGramsPerUnit: cg, foodSnapshot: widget.food);
                  Navigator.pop(context, item);
                },
                child: const Text('Adicionar'),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

