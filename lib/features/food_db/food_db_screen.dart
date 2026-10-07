import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/food_db/food_database.dart';
import '../../state/app_state.dart';

/// Banco de alimentos: busca rápida, categorias e detalhes nutricionais.
class FoodDbScreen extends StatefulWidget {
  const FoodDbScreen({super.key});

  @override
  State<FoodDbScreen> createState() => _FoodDbScreenState();
}

class _FoodDbScreenState extends State<FoodDbScreen> {
  final _search = TextEditingController();
  String _category = 'Todos';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final query = _search.text.trim();
    final foods = (query.isEmpty
        ? FoodDatabase.all.where((f) =>
            _category == 'Todos' || f.category == _category)
        : FoodDatabase.search(query).where((f) =>
            _category == 'Todos' || f.category == _category))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('📚 Banco de alimentos', style: TextStyle(fontSize: 18))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Busca rápida (TACO/TBCA)...',
                prefixIcon: Icon(Icons.search, color: AppTheme.textMuted),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: _category == 'Todos',
                  onSelected: (_) => setState(() => _category = 'Todos'),
                ),
                for (final c in FoodDatabase.categories)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: foods.length,
              itemBuilder: (context, i) => _FoodRow(food: foods[i], state: state),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({required this.food, required this.state});
  final dynamic food;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showDetails(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
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
                  Text(
                    food.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${food.category} · ${food.kcal.round()} kcal/100g',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => state.toggleFavorite(food.id),
              child: Icon(
                state.isFavorite(food.id) ? Icons.favorite : Icons.favorite_border,
                size: 20,
                color: state.isFavorite(food.id) ? AppTheme.danger : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                food.name,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${food.source} · ${food.category}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _value('Energia', '${food.kcal.round()} kcal/100g'),
              _value('Proteínas', '${food.protein.toStringAsFixed(1)} g'),
              _value('Carboidratos', '${food.carbs.toStringAsFixed(1)} g'),
              _value('Gorduras', '${food.fat.toStringAsFixed(1)} g'),
              _value('Fibras', '${food.fiber.toStringAsFixed(1)} g'),
              _value('Sódio', '${food.sodium.toStringAsFixed(0)} mg'),
              _value('Porção padrão', '${food.standardPortionGrams.toStringAsFixed(0)} g'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _value(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}