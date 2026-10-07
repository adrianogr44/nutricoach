import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/diet.dart';
import '../../data/models/food.dart';
import '../../services/household_measure.dart';
import '../../state/app_state.dart';

/// Card diário de uma refeição planejada.
///
/// Mostra nome, horário, status real do dia, alimentos e quantidades.
/// A conclusão é feita por swipe para a direita (threshold de 30% da largura);
/// não existe botão ou modal que substitua o gesto. Refeições já concluídas
/// não aceitam swipe e oferecem "Desfazer".
class DietMealDailyCard extends StatefulWidget {
  const DietMealDailyCard({
    super.key,
    required this.meal,
    required this.status,
    required this.isNext,
    required this.onCompleted,
    required this.onUndo,
    required this.onEdit,
    required this.onDelete,
  });

  final DietMeal meal;

  /// 'planned' | 'partially' | 'consumed' — vem de `AppState.dietMealStatusFor`.
  final String status;

  final bool isNext;
  final Future<bool> Function() onCompleted;
  final Future<void> Function() onUndo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<DietMealDailyCard> createState() => _DietMealDailyCardState();
}

class _DietMealDailyCardState extends State<DietMealDailyCard> with SingleTickerProviderStateMixin {
  late final AnimationController _settle;
  double _dx = 0;
  double _settleFrom = 0;
  bool _hapticArmed = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(vsync: this, duration: const Duration(milliseconds: 240))
      ..addListener(() {
        if (!mounted) return;
        setState(() => _dx = _settleFrom * (1 - _settle.value));
      });
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  bool get _consumed => widget.status == 'consumed';
  bool get _partial => widget.status == 'partially';
  bool get _canSwipe => !_consumed && !_submitting;

  double _threshold(double width) => width * 0.30;

  void _onDragStart(DragStartDetails details) {
    _settle.stop();
    _hapticArmed = false;
  }

  void _onDragUpdate(DragUpdateDetails details, double width) {
    if (!_canSwipe) return;
    setState(() {
      _dx = (_dx + details.delta.dx).clamp(0.0, width * 0.92);
      if (!_hapticArmed && _dx >= _threshold(width)) {
        _hapticArmed = true;
        HapticFeedback.lightImpact();
      } else if (_hapticArmed && _dx < _threshold(width)) {
        _hapticArmed = false;
      }
    });
  }

  Future<void> _onDragEnd(double width) async {
    if (!_canSwipe) return;
    if (_dx >= _threshold(width)) {
      await _confirm();
    } else {
      _settleBack();
    }
  }

  void _settleBack() {
    if (_dx == 0) return;
    _settleFrom = _dx;
    _settle.forward(from: 0);
  }

  Future<void> _confirm() async {
    setState(() => _submitting = true);
    final ok = await widget.onCompleted();
    if (!mounted) return;
    if (ok) {
      setState(() {
        _dx = 0;
        _hapticArmed = false;
        _submitting = false;
      });
    } else {
      setState(() => _submitting = false);
      _settleBack();
    }
  }

  String get _semanticsLabel {
    final name = widget.meal.name;
    if (_consumed) return '$name, refeição concluída. Toque em Desfazer para desfazer.';
    final status = _partial ? 'refeição parcial' : 'refeição pendente';
    final next = widget.isNext ? 'próxima refeição, ' : '';
    return '$name, $next$status. Arraste para a direita para concluir.';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final foodMap = state.foodByIdMap;
    final totals = widget.meal.totals(foodMap);
    final kcal = totals['kcal']!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        button: true,
        label: _semanticsLabel,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final progress = (_dx / _threshold(width)).clamp(0.0, 1.0);
            return ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Positioned.fill(child: _backdrop(progress)),
                  Transform.translate(
                    offset: Offset(_dx, 0),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: _canSwipe ? _onDragStart : null,
                      onHorizontalDragUpdate: _canSwipe ? (d) => _onDragUpdate(d, width) : null,
                      onHorizontalDragEnd: _canSwipe ? (d) => _onDragEnd(width) : null,
                      onHorizontalDragCancel: _canSwipe ? _settleBack : null,
                      child: _card(context, foodMap, kcal),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _backdrop(double progress) {
    return Container(
      color: AppTheme.primary.withValues(alpha: 0.06 + 0.16 * progress),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 20),
      child: Opacity(
        opacity: progress,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: AppTheme.primary, size: 22),
            SizedBox(width: 8),
            Text(
              'Concluir',
              style: TextStyle(color: AppTheme.primary, fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, Map<String, Food> foodMap, double kcal) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 12),
      decoration: BoxDecoration(
        color: _consumed ? AppTheme.primaryMuted : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _consumed
              ? AppTheme.primary.withValues(alpha: 0.5)
              : (widget.isNext ? AppTheme.primary.withValues(alpha: 0.55) : AppTheme.border),
          width: (_consumed || widget.isNext) ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statusIcon(),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.meal.name,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                    ),
                    if (widget.meal.time != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          widget.meal.time!,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${kcal.round()} kcal',
                style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13),
              ),
              _menu(context),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _statusLabel(),
              if (widget.isNext)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.55)),
                  ),
                  child: const Text(
                    'Próxima refeição',
                    style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (widget.meal.items.isEmpty)
            const Text(
              'Nenhum alimento — toque em Editar para adicionar.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            )
          else
            for (final item in widget.meal.items) _itemRow(item, foodMap),
          if (_consumed) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _submitting ? null : () => widget.onUndo(),
                  icon: const Icon(Icons.undo_rounded, size: 16, color: AppTheme.textMuted),
                  label: const Text(
                    'Desfazer',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusIcon() {
    if (_consumed) return const Icon(Icons.check_circle, color: AppTheme.primary, size: 22);
    if (_partial) return const Icon(Icons.adjust, color: AppTheme.warning, size: 22);
    return const Icon(Icons.radio_button_unchecked, color: AppTheme.textFaint, size: 22);
  }

  Widget _statusLabel() {
    final String label;
    final Color color;
    if (_consumed) {
      label = 'Concluída';
      color = AppTheme.primary;
    } else if (_partial) {
      label = 'Parcial';
      color = AppTheme.warning;
    } else {
      label = 'Pendente';
      color = AppTheme.textMuted;
    }
    return Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700));
  }

  Widget _menu(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'edit') widget.onEdit();
        if (v == 'delete') widget.onDelete();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('Editar')),
        PopupMenuItem(value: 'delete', child: Text('Excluir')),
      ],
      icon: const Icon(Icons.more_horiz, size: 18, color: AppTheme.textMuted),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    );
  }

  Widget _itemRow(DietMealItem item, Map<String, Food> foodMap) {
    final food = foodMap[item.foodId];
    if (food == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text('${item.foodId} — alimento não encontrado', style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
      );
    }
    const converter = HouseholdMeasureConverter();
    final display = converter.displayFor(food, item.quantity, item.unit, customGramsPerUnit: item.customGramsPerUnit);
    final grams = converter.toGrams(food, item.quantity, item.unit, customGramsPerUnit: item.customGramsPerUnit);
    final nutr = food.nutritionFor(grams);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: _consumed ? AppTheme.primary : AppTheme.textMuted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  display,
                  style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w800),
                ),
                Text(
                  food.name,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Text(
            '${nutr.kcal.round()} kcal',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
