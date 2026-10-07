import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/food.dart';
import '../../data/models/meal.dart';
import '../../services/meal_text_parser.dart';
import '../../state/app_state.dart';
import 'food_search_screen.dart';
import 'add_meal_screen.dart' show showMealTypePicker;

/// Fluxo de registro por texto: parser local interpreta → valida contra o banco
/// nutricional → revisa e salva. Itens sem correspondência no banco são
/// destacados e exigem seleção manual (nunca se inventa valor).
class MealTextEntryScreen extends StatefulWidget {
  const MealTextEntryScreen({super.key});

  @override
  State<MealTextEntryScreen> createState() => _MealTextEntryScreenState();
}

class _MealTextEntryScreenState extends State<MealTextEntryScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  bool _done = false;
  String? _error;

  List<ParsedFoodItem> _parsed = [];
  final Map<int, Food?> _resolved = {}; // índice → alimento escolhido

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _analyze() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final state = context.read<AppState>();
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _done = false;
    });
    final parsed = state.mealParser.parse(text);
    if (!mounted) return;
    if (parsed.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Não identifiquei alimentos nessa descrição. Use o formato: "200g arroz, 100g feijão, 150g frango".';
      });
      return;
    }
    setState(() {
      _parsed = parsed;
      _resolved
        ..clear()
        ..addAll({for (var i = 0; i < parsed.length; i++) i: parsed[i].match()});
      _loading = false;
      _done = true;
    });
  }

  Future<void> _resolveItem(int index) async {
    final name = _parsed[index].name;
    final picked = await Navigator.push<Food>(
      context,
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(
          initialQuery: name,
          compactPicker: true,
          pickerLabel: 'Selecionar: $name',
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _resolved[index] = picked);
    }
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final type = await showMealTypePicker(context);
    if (type == null || !mounted) return;

    final items = <MealItem>[];
    for (var i = 0; i < _parsed.length; i++) {
      final food = _resolved[i];
      if (food == null) continue;
      items.add(MealItem(food: food, quantityGrams: _parsed[i].quantityInGrams(food)));
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum alimento válido para salvar.')),
      );
      return;
    }

    final meal = state.buildMeal(
      date: DateTime.now(),
      type: type,
      items: items,
      rawText: _controller.text.trim(),
    );
    await state.addMeal(meal);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ ${type.emoji} ${type.label} salvo — ${meal.totalKcal.round()} kcal')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Descrever refeição', style: TextStyle(fontSize: 18))),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Ex.: Comi 200g de arroz, 100g de feijão e 300g de peito de frango.',
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Icon(Icons.keyboard_alt_outlined, color: AppTheme.textMuted),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _analyze,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.background),
                      )
                    : const Text('🔍 Analisar descrição'),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.danger.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.danger),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.textPrimary))),
                  ],
                ),
              ),
            if (_loading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppTheme.primary),
                      SizedBox(height: 16),
                      Text('Interpretando alimentos e quantidades...',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ),
            if (_done && !_loading) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Revisão — confira os alimentos identificados:',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(child: _buildReviewList()),
              const SizedBox(height: 12),
              FilledButton(onPressed: _save, child: const Text('Salvar refeição')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReviewList() {
    return ListView.builder(
      itemCount: _parsed.length,
      itemBuilder: (context, i) {
        final item = _parsed[i];
        final food = _resolved[i];
        final hasMatch = food != null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasMatch ? AppTheme.border : AppTheme.warning,
              ),
            ),
            child: Row(
              children: [
                !hasMatch
                    ? const Icon(Icons.warning_amber, color: AppTheme.warning)
                    : const Icon(Icons.check_circle, color: AppTheme.success),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 1)} ${item.unit} de '
                        '${item.name}',
                        style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      if (hasMatch)
                        Text(
                          '→ ${food.name} (${food.kcal.round()} kcal/100g)',
                          style: const TextStyle(color: AppTheme.primary, fontSize: 12),
                        )
                      else
                        Text(
                          'Sem correspondência no banco — toque para selecionar',
                          style: const TextStyle(color: AppTheme.warning, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: AppTheme.textSecondary),
                  onPressed: () => _resolveItem(i),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}