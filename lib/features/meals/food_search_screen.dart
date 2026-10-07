import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/food_db/food_database.dart';
import '../../data/food_db/open_food_facts_api.dart';
import '../../data/models/food.dart';
import '../../data/models/meal.dart';
import '../../services/household_measure.dart';
import '../../state/app_state.dart';
import '../../widgets/core_widgets.dart';
import 'add_meal_screen.dart' show showMealTypePicker;

/// Busca no banco TACO/TBCA + OpenFoodFacts. Em modo [compactPicker],
/// retorna o alimento selecionado via Navigator.pop.
class FoodSearchScreen extends StatefulWidget {
  const FoodSearchScreen({
    super.key,
    this.initialQuery,
    this.compactPicker = false,
    this.pickerLabel,
    this.onlyFavorites = false,
  });

  final String? initialQuery;
  final bool compactPicker;
  final String? pickerLabel;
  final bool onlyFavorites;

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final _search = TextEditingController();
  final OpenFoodFactsApi _off = OpenFoodFactsApi();
  List<Food> _localResults = [];
  List<Food> _offResults = [];
  bool _searchingOff = false;
  String _category = 'Todos';

  @override
  void initState() {
    super.initState();
    _search.text = widget.initialQuery ?? '';
    _refresh();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _refresh() {
    final state = context.read<AppState>();
    final q = _search.text.trim();
    setState(() {
      if (widget.onlyFavorites) {
        _localResults = [
          for (final f in state.favorites)
            if (_category == 'Todos' || f.category == _category) f,
        ];
      } else {
        _localResults = state.allSearchableFoods(q, limit: 50).where((f) {
          return _category == 'Todos' || f.category == _category;
        }).toList();
      }
    });
    _searchOff();
  }

  Future<void> _searchOff() async {
    final q = _search.text.trim();
    if (widget.onlyFavorites || q.length < 3) {
      setState(() => _offResults = []);
      return;
    }
    setState(() => _searchingOff = true);
    final results = await _off.search(q);
    if (!mounted) return;
    setState(() {
      _offResults = results;
      _searchingOff = false;
    });
  }

  Future<void> _onPick(Food food) async {
    if (widget.compactPicker) {
      Navigator.pop(context, food);
      return;
    }
    final quantity = await _askQuantity(food);
    if (quantity == null || !mounted) return;
    final type = await showMealTypePicker(context);
    if (type == null || !mounted) return;

    final state = context.read<AppState>();
    final meal = state.buildMeal(
      date: DateTime.now(),
      type: type,
      items: [MealItem(food: food, quantityGrams: quantity)],
    );
    await state.addMeal(meal);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'âœ… ${food.name} â€” ${meal.totalKcal.round()} kcal',
        ),
      ),
    );
  }

  Future<double?> _askQuantity(Food food) {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _QuantitySheet(food: food),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.pickerLabel ?? (widget.compactPicker ? 'Selecionar alimento' : 'Pesquisar alimento'),
          style: const TextStyle(fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _refresh(),
              onChanged: (_) => _refresh(),
              decoration: InputDecoration(
                hintText: widget.onlyFavorites ? 'Filtrar favoritos' : 'Ex.: peito de frango, feijão...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.textMuted, size: 18),
                        onPressed: () {
                          _search.clear();
                          _refresh();
                        },
                      )
                    : null,
              ),
            ),
          ),
          if (!widget.onlyFavorites)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _CategoryChip('Todos', _category == 'Todos', () => setState(() {
                        _category = 'Todos';
                        _refresh();
                      })),
                  for (final c in _categories())
                    _CategoryChip(c, _category == c, () => setState(() {
                          _category = c;
                          _refresh();
                        })),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                for (final food in _localResults)
                  _FoodTile(
                    food: food,
                    isFavorite: state.isFavorite(food.id),
                    onTap: () => _onPick(food),
                    onFavorite: () => state.toggleFavorite(food.id),
                  ),
                if (_localResults.isEmpty && _offResults.isEmpty && !_searchingOff)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Column(
                      children: [
                        Icon(Icons.search_off, size: 40, color: AppTheme.textMuted),
                        SizedBox(height: 12),
                        Text(
                          'Nenhum alimento encontrado.\nTente outro nome ou verifique o código de barras.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                if (_searchingOff)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primary),
                      ),
                    ),
                  ),
                if (_offResults.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: SectionHeader(title: 'ðŸŒ OpenFoodFacts'),
                  ),
                  for (final food in _offResults)
                    _FoodTile(
                      food: food,
                      isFavorite: state.isFavorite(food.id),
                      onTap: () => _onPick(food),
                      onFavorite: () => state.toggleFavorite(food.id),
                    ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Fonte externa validada. Valores do rótulo do fabricante.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _categories() => FoodDatabase.categories;
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip(this.label, this.selected, this.onTap);
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
    );
  }
}

class _FoodTile extends StatelessWidget {
  const _FoodTile({
    required this.food,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
  });

  final Food food;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(
                        food.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (food.source == 'OpenFoodFacts') ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.public, size: 12, color: AppTheme.textMuted),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    '${food.kcal.round()} kcal/100g Â· P ${food.protein.toStringAsFixed(1)} Â· C ${food.carbs.toStringAsFixed(1)} Â· G ${food.fat.toStringAsFixed(1)}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? AppTheme.danger : AppTheme.textMuted,
                size: 20,
              ),
              onPressed: onFavorite,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantitySheet extends StatefulWidget {
  const _QuantitySheet({required this.food});
  final Food food;
  @override
  State<_QuantitySheet> createState() => _QuantitySheetState();
}

class _QuantitySheetState extends State<_QuantitySheet> {
  double qty = 1;
  MeasureUnit unit = MeasureUnit.g;
  late TextEditingController qtyController;
  double? customGrams;
  bool showCustom = false;

  @override
  void initState() {
    super.initState();
    unit = _defaultUnitFor(widget.food);
    qty = unit == MeasureUnit.g ? widget.food.standardPortionGrams : 1;
    qtyController = TextEditingController(text: qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 1).replaceAll('.', ','));
  }

  MeasureUnit _defaultUnitFor(Food f) {
    if (f.category == 'Bebidas' || f.category == 'Leite e derivados') return MeasureUnit.copo;
    if (f.id.contains('arroz') || f.id.contains('feijao')) return MeasureUnit.concha;
    if (f.id.contains('pao')) return MeasureUnit.fatia;
    if (f.id.contains('ovo')) return MeasureUnit.unidade;
    return MeasureUnit.g;
  }

  @override
  Widget build(BuildContext context) {
    final converter = const HouseholdMeasureConverter();
    final grams = converter.toGrams(widget.food, qty, unit, customGramsPerUnit: showCustom ? customGrams : null);
    final nutr = widget.food.nutritionFor(grams);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.food.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text('${widget.food.kcal.round()} kcal / 100g', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('â‰ˆ ${grams.round()} g', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primary)),
                  Text('${nutr.kcal.round()} kcal Â· P ${nutr.protein.round()}g Â· C ${nutr.carbs.round()}g', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
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
                    decoration: const InputDecoration(labelText: 'Quantidade'),
                    onChanged: (v) => setState(() => qty = double.tryParse(v.replaceAll(',', '.')) ?? qty),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<MeasureUnit>(initialValue: unit,
                    decoration: const InputDecoration(labelText: 'Medida'),
                    items: [for (final u in converter.availableFor(widget.food)) DropdownMenuItem(value: u, child: Text(u.label, style: const TextStyle(fontSize: 12)))],
                    onChanged: (v) => setState(() => unit = v ?? MeasureUnit.g),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(onPressed: () => setState(() { qty = (qty - 0.5).clamp(0.5, 999); qtyController.text = qty.toStringAsFixed(1).replaceAll('.0', '').replaceAll('.', ','); }), icon: const Icon(Icons.remove_circle_outline)),
                Text('$qty', style: const TextStyle(fontWeight: FontWeight.w800)),
                IconButton(onPressed: () => setState(() { qty = (qty + 0.5).clamp(0.5, 999); qtyController.text = qty.toStringAsFixed(1).replaceAll('.0', '').replaceAll('.', ','); }), icon: const Icon(Icons.add_circle_outline)),
                const SizedBox(width: 8),
                Expanded(child: Text(converter.displayFor(widget.food, qty, unit, customGramsPerUnit: showCustom ? customGrams : null), style: const TextStyle(color: AppTheme.textMuted, fontSize: 11))),
              ],
            ),
            CheckboxListTile(
              value: showCustom,
              onChanged: (v) => setState(() => showCustom = v ?? false),
              title: const Text('Minha medida personalizada', style: TextStyle(fontSize: 12)),
              subtitle: const Text('Ex: minha concha â‰ˆ 120g', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              dense: true, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
            ),
            if (showCustom)
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Gramas por unidade'),
                onChanged: (v) => setState(() => customGrams = double.tryParse(v.replaceAll(',', '.'))),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final q = double.tryParse(qtyController.text.replaceAll(',', '.')) ?? qty;
                  final g = converter.toGrams(widget.food, q, unit, customGramsPerUnit: showCustom ? customGrams : null);
                  Navigator.pop(context, g);
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
