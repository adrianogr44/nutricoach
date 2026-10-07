import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/food_db/food_database.dart';
import '../../data/food_db/open_food_facts_api.dart';
import '../../data/models/food.dart';
import '../../data/models/meal.dart';
import '../../state/app_state.dart';
import '../meals/add_meal_screen.dart' show showMealTypePicker;

/// Escaneia código de barras e busca o produto no OpenFoodFacts.
class BarcodeScreen extends StatefulWidget {
  const BarcodeScreen({super.key});

  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
  final MobileScannerController _scanner = MobileScannerController(
    formats: [BarcodeFormat.qrCode, BarcodeFormat.ean13, BarcodeFormat.ean8],
  );
  final OpenFoodFactsApi _off = OpenFoodFactsApi();
  Food? _found;
  bool _loading = false;
  String? _message;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_loading || _found != null) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null) return;

    setState(() {
      _loading = true;
      _message = 'Buscando produto $barcode...';
    });
    await _scanner.stop();

    // Verifica banco local primeiro.
    var food = FoodDatabase.byBarcode(barcode);
    food ??= await _off.byBarcode(barcode);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _found = food;
      _message = food == null
          ? 'Produto $barcode não encontrado neste banco.'
          : null;
    });
  }

  Future<void> _confirmAdd() async {
    final food = _found!;
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
    // Salva como custom food possível para favoritos
    if (!state.isFavorite(food.id)) {
      await state.addCustomFood(food);
      await state.toggleFavorite(food.id);
    }
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ ${food.name} — ${meal.totalKcal.round()} kcal')),
    );
  }

  Future<double?> _askQuantity(Food food) {
    final controller = TextEditingController(text: '100');
    return showModalBottomSheet<double>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                food.name,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${food.brand ?? food.category} · ${food.kcal.round()} kcal/100g',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Quantidade (g)', suffixText: 'g'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final q = double.tryParse(controller.text.replaceAll(',', '.'));
                  Navigator.pop(context, q);
                },
                child: const Text('Adicionar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Código de barras', style: TextStyle(fontSize: 18))),
      body: Column(
        children: [
          SizedBox(
            height: 320,
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _scanner,
                  onDetect: _onDetect,
                ),
                IgnorePointer(
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.primary, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          if (_message != null && _found == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          if (_found != null)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _found!.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_found!.kcal.round()} kcal · P ${_found!.protein.toStringAsFixed(1)}g · '
                      'C ${_found!.carbs.toStringAsFixed(1)}g · G ${_found!.fat.toStringAsFixed(1)}g',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Fonte: ${_found!.source}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _confirmAdd,
                        child: const Text('Adicionar refeição'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () async {
                        await _scanner.start();
                        setState(() {
                          _found = null;
                          _message = null;
                        });
                      },
                      child: const Text('Escanear novamente'),
                    ),
                  ],
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Aponte a câmera para o código de barras do produto. '
                'O app consulta o OpenFoodFacts para obter dados reais do rótulo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}