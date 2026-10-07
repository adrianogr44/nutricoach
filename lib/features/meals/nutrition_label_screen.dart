import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/food.dart';
import '../../data/models/meal.dart';
import '../../services/bioimpedance_text_parser.dart';
import '../../services/device_text_recognizer.dart';
import '../../services/nutrition_label_text_parser.dart';
import '../../state/app_state.dart';
import 'add_meal_screen.dart' show showMealTypePicker;

/// Usa OCR local para ler a tabela nutricional e exige revisão antes de salvar.
class NutritionLabelScreen extends StatefulWidget {
  const NutritionLabelScreen({super.key});

  @override
  State<NutritionLabelScreen> createState() => _NutritionLabelScreenState();
}

class _NutritionLabelScreenState extends State<NutritionLabelScreen> {
  final _picker = ImagePicker();
  bool _loading = false;
  String? _error;
  ParsedNutritionLabel? _label;
  String? _name;
  String? _category = 'Outros';

  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _fiber = TextEditingController();
  final _sodium = TextEditingController();

  static const _categories = [
    'Cereais e grãos',
    'Leguminosas',
    'Carnes e aves',
    'Peixes e frutos do mar',
    'Leite e derivados',
    'Frutas',
    'Legumes e verduras',
    'Oleaginosas',
    'Açúcares e doces',
    'Bebidas',
    'Pratos prontos',
    'Outros',
  ];

  @override
  void dispose() {
    _kcal.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    _fiber.dispose();
    _sodium.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      const ocr = DeviceTextRecognizer();
      final text = await ocr.recognizeFile(file.path);
      final label = const NutritionLabelTextParser().parse(text);
      if (!mounted) return;
      setState(() {
        _label = label;
        _name = label.name;
        _category = 'Outros';
        _fillFields(label);
      });
    } on LocalParseException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e, st) {
      if (mounted) setState(() => _error = 'Falha ao ler a imagem: $e\n$st');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fillFields(ParsedNutritionLabel l) {
    _kcal.text = _fmt(l.kcal);
    _protein.text = _fmt(l.protein);
    _carbs.text = _fmt(l.carbs);
    _fat.text = _fmt(l.fat);
    _fiber.text = _fmt(l.fiber);
    _sodium.text = _fmt(l.sodium);
  }

  String _fmt(double? v) =>
      v == null ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1));

  double? _parse(String text) {
    final s = text.trim().replaceAll(',', '.');
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  Future<void> _save() async {
    final name = _name?.trim() ?? '';
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite o nome do produto.')),
      );
      return;
    }
    final kcal = _parse(_kcal.text);
    if (kcal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o valor energético (kcal/100g).')),
      );
      return;
    }

    final state = context.read<AppState>();
    final suffix = DateTime.now().millisecondsSinceEpoch;
    final food = Food(
      id: 'prod-$suffix',
      name: name,
      category: _category ?? 'Outros',
      aliases: [name.toLowerCase()],
      kcal: kcal,
      protein: _parse(_protein.text) ?? 0,
      carbs: _parse(_carbs.text) ?? 0,
      fat: _parse(_fat.text) ?? 0,
      fiber: _parse(_fiber.text) ?? 0,
      sodium: _parse(_sodium.text) ?? 0,
      source: 'Rótulo do produto',
      brand: _label?.brand,
    );
    await state.addCustomFood(food);
    if (!mounted) return;

    // Agenda a adição como refeição: quantidade + tipo.
    final quantity = await _askQuantity(food);
    if (!mounted) return;
    if (quantity == null) {
      _leaveUnregistered(name);
      return;
    }
    final type = await showMealTypePicker(context);
    if (!mounted) return;
    if (type == null) {
      _leaveUnregistered(name);
      return;
    }

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
        content: Text('✅ $name — ${meal.totalKcal.round()} kcal registradas '
            '(${type.label}).'),
      ),
    );
  }

  void _leaveUnregistered(String name) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ $name adicionado aos seus alimentos (não registrado hoje).')),
    );
  }

  Future<double?> _askQuantity(Food food) {
    final controller = TextEditingController(
      text: food.standardPortionGrams.toStringAsFixed(0),
    );
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
                '${food.name}\n${food.kcal.round()} kcal / 100g',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'P ${food.protein.toStringAsFixed(1)}g · C ${food.carbs.toStringAsFixed(1)}g · G ${food.fat.toStringAsFixed(1)}g',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Quantidade consumida (g)',
                  suffixText: 'g',
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () {
                  final q = double.tryParse(controller.text.replaceAll(',', '.'));
                  Navigator.pop(context, q);
                },
                child: const Text('Registrar'),
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
      appBar: AppBar(title: const Text('📷 Tabela nutricional', style: TextStyle(fontSize: 18))),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: 16),
                  Text('Lendo a tabela nutricional da foto...',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.danger.withValues(alpha: 0.4)),
                    ),
                    child: Text(_error!,
                        style: const TextStyle(color: AppTheme.textPrimary)),
                  ),
                if (_label == null)
                  ..._pickButtons()
                else
                  ..._reviewForm(),
              ],
            ),
    );
  }

  List<Widget> _pickButtons() {
    return [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: const Column(
          children: [
            Icon(Icons.food_bank_outlined, size: 56, color: AppTheme.primary),
            SizedBox(height: 12),
            Text(
              'Fotografe a tabela nutricional do produto',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'O OCR local lê os valores do rótulo sem enviar a foto para '
              'servidores; revise todos os campos antes de salvar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        icon: const Icon(Icons.photo_camera),
        label: const Text('Tirar foto'),
        onPressed: () => _pickPhoto(ImageSource.camera),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        icon: const Icon(Icons.photo_library_outlined),
        label: const Text('Escolher da galeria'),
        onPressed: () => _pickPhoto(ImageSource.gallery),
      ),
      const SizedBox(height: 24),
      const Text(
        'Os valores são transcritos do rótulo e podem ser editados antes de salvar.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
      ),
    ];
  }

  List<Widget> _reviewForm() {
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((_label?.brand ?? '').isNotEmpty)
              Text(_label!.brand!,
                  style: const TextStyle(color: AppTheme.primary, fontSize: 13)),
            const SizedBox(height: 4),
            TextField(
              controller: TextEditingController(text: _name),
              onChanged: (v) => _name = v,
              decoration: const InputDecoration(labelText: 'Nome do produto'),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: [
                for (final c in _categories)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => _category = v,
            ),
            const SizedBox(height: 18),
            const Text('Valores por 100 g (edite se necessário)',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            _field(_kcal, 'Calorias', 'kcal'),
            _field(_protein, 'Proteínas', 'g'),
            _field(_carbs, 'Carboidratos', 'g'),
            _field(_fat, 'Gorduras totais', 'g'),
            _field(_fiber, 'Fibras', 'g'),
            _field(_sodium, 'Sódio', 'mg'),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('Salvar produto'),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => setState(() {
                _label = null;
                _error = null;
              }),
              child: const Text('Tirar outra foto'),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _field(TextEditingController c, String label, String unit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: '$label ($unit)'),
      ),
    );
  }
}