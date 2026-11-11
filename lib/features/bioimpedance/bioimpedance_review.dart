import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/bioimpedance.dart';
import '../../data/models/user_profile.dart';
import '../../services/bioimpedance_text_parser.dart';

/// Revisão humana da bioimpedância lida do laudo.
///
/// Todos os campos são editáveis: o parser só preenche o que reconheceu e o
/// usuário confirma ou corrige. Campos não reconhecidos aparecem como
/// "não identificado" e o texto não lido fica disponível para conferência.
class BioimpedanceReview extends StatefulWidget {
  const BioimpedanceReview({
    super.key,
    required this.result,
    required this.onApply,
    required this.onDiscard,
    this.applyLabel = 'Aplicar ao perfil',
  });

  final BioimpedanceParseResult result;
  final ValueChanged<Bioimpedance> onApply;
  final VoidCallback onDiscard;
  final String applyLabel;

  @override
  State<BioimpedanceReview> createState() => _BioimpedanceReviewState();
}

class _BioimpedanceReviewState extends State<BioimpedanceReview> {
  late final Map<BioField, TextEditingController> _controllers;
  late final TextEditingController _date;
  late final Map<String, TextEditingController> _leanKg;
  late final Map<String, TextEditingController> _leanPct;
  late final Map<String, TextEditingController> _fatKg;
  late final Map<String, TextEditingController> _fatPct;
  Sexo? _sexo;
  String? _dateError;

  static const _segments = <String, String>{
    'rightArm': 'Braço direito',
    'leftArm': 'Braço esquerdo',
    'trunk': 'Tronco',
    'rightLeg': 'Perna direita',
    'leftLeg': 'Perna esquerda',
  };

  @override
  void initState() {
    super.initState();
    final bio = widget.result.bioimpedance;
    final values = widget.result.values;
    _controllers = {
      for (final spec in bioFieldSpecs)
        spec.field: TextEditingController(
          text: _format(values[spec.field], integer: spec.integer),
        ),
    };
    _date = TextEditingController(text: _fmtDate(bio.data));
    _sexo = bio.sexo;

    final lean = bio.massaMagraSegmentar;
    final fat = bio.gorduraSegmentar;
    _leanKg = _buildSegmentControllers(lean, pct: false);
    _leanPct = _buildSegmentControllers(lean, pct: true);
    _fatKg = _buildSegmentControllers(fat, pct: false);
    _fatPct = _buildSegmentControllers(fat, pct: true);
  }

  Map<String, TextEditingController> _buildSegmentControllers(
    SegmentalValues? values, {
    required bool pct,
  }) {
    double? pick(String key) {
      if (values == null) return null;
      return switch (key) {
        'rightArm' => pct ? values.rightArmPct : values.rightArm,
        'leftArm' => pct ? values.leftArmPct : values.leftArm,
        'trunk' => pct ? values.trunkPct : values.trunk,
        'rightLeg' => pct ? values.rightLegPct : values.rightLeg,
        _ => pct ? values.leftLegPct : values.leftLeg,
      };
    }

    return {
      for (final key in _segments.keys) key: TextEditingController(text: _format(pick(key))),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _date.dispose();
    for (final controller in [
      ..._leanKg.values,
      ..._leanPct.values,
      ..._fatKg.values,
      ..._fatPct.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _read(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return const BioimpedanceTextNormalizer().parseNumber(text);
  }

  SegmentalValues? _readSegmental(
    Map<String, TextEditingController> kg,
    Map<String, TextEditingController> pct,
  ) {
    double? read(TextEditingController controller) => _read(controller);
    final values = SegmentalValues(
      rightArm: read(kg['rightArm']!),
      leftArm: read(kg['leftArm']!),
      trunk: read(kg['trunk']!),
      rightLeg: read(kg['rightLeg']!),
      leftLeg: read(kg['leftLeg']!),
      rightArmPct: read(pct['rightArm']!),
      leftArmPct: read(pct['leftArm']!),
      trunkPct: read(pct['trunk']!),
      rightLegPct: read(pct['rightLeg']!),
      leftLegPct: read(pct['leftLeg']!),
    );
    return values.isEmpty ? null : values;
  }

  void _apply() {
    final date = _parseDate(_date.text);
    if (date == null) {
      setState(() => _dateError = 'Use o formato dd/mm/aaaa.');
      return;
    }
    setState(() => _dateError = null);

    final values = {for (final entry in _controllers.entries) entry.key: _read(entry.value)};
    double? v(BioField field) => values[field];

    widget.onApply(Bioimpedance(
      data: date,
      pesoKg: v(BioField.weight),
      alturaCm: v(BioField.height),
      idade: v(BioField.age)?.round(),
      sexo: _sexo,
      imc: v(BioField.bmi),
      gorduraPct: v(BioField.bodyFatPercentage),
      gorduraKg: v(BioField.fatMass),
      massaMuscularKg: v(BioField.muscleMass),
      massaMuscularEsqueleticaKg: v(BioField.skeletalMuscleMass),
      aguaL: v(BioField.totalBodyWater),
      proteinaKg: v(BioField.proteinMass),
      mineraisKg: v(BioField.mineralMass),
      tmbKcal: v(BioField.basalMetabolicRate),
      gorduraVisceral: v(BioField.visceralFatLevel)?.round(),
      grauObesidade: v(BioField.obesityDegree),
      relacaoCinturaQuadril: v(BioField.waistHipRatio),
      pesoIdealKg: v(BioField.idealWeight),
      pontuacao: v(BioField.inBodyScore)?.round(),
      massaMagraSegmentar: _readSegmental(_leanKg, _leanPct),
      gorduraSegmentar: _readSegmental(_fatKg, _fatPct),
      fonte: widget.result.manufacturer.displayName,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Valores encontrados — revise e aplique',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            TextButton(onPressed: widget.onDiscard, child: const Text('Recomeçar')),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              widget.result.manufacturer.known ? Icons.verified_outlined : Icons.description_outlined,
              color: AppTheme.textMuted,
              size: 16,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Fonte: ${widget.result.manufacturer.displayName}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _block(
          title: 'Dados do laudo',
          children: [
            _dateRow(),
            _sexRow(),
          ],
        ),
        const SizedBox(height: 14),
        _block(
          title: 'Composição corporal',
          children: [
            for (final spec in bioFieldSpecs)
              _fieldRow(
                label: spec.label,
                unit: spec.unit,
                controller: _controllers[spec.field]!,
              ),
          ],
        ),
        const SizedBox(height: 14),
        _segmentalBlock(
          title: 'Massa magra segmentar',
          subtitle: 'Não é a massa muscular esquelética total.',
          kg: _leanKg,
          pct: _leanPct,
        ),
        const SizedBox(height: 14),
        _segmentalBlock(
          title: 'Gordura segmentar',
          subtitle: 'Não é a massa de gordura total.',
          kg: _fatKg,
          pct: _fatPct,
        ),
        if (widget.result.warnings.isNotEmpty) ...[
          const SizedBox(height: 14),
          _warnings(),
        ],
        if (widget.result.unrecognizedLines.isNotEmpty) ...[
          const SizedBox(height: 14),
          _unrecognized(),
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onDiscard,
                child: const Text('Descartar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _apply,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(widget.applyLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _block({required String title, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ),
          ...children,
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _fieldRow({
    required String label,
    required String unit,
    required TextEditingController controller,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13.5),
            ),
          ),
          SizedBox(
            width: 116,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13.5),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'não identificado',
                hintStyle: const TextStyle(color: AppTheme.textFaint, fontSize: 11.5),
                suffixText: unit.isEmpty ? null : unit,
                suffixStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Data da avaliação',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5),
                ),
              ),
              SizedBox(
                width: 116,
                child: TextField(
                  controller: _date,
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.datetime,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13.5),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'dd/mm/aaaa',
                    hintStyle: TextStyle(color: AppTheme.textFaint, fontSize: 11.5),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          if (_dateError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _dateError!,
                style: const TextStyle(color: AppTheme.danger, fontSize: 11.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sexRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Sexo',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5),
            ),
          ),
          DropdownButton<Sexo?>(
            value: _sexo,
            dropdownColor: AppTheme.surfaceLight,
            underline: const SizedBox.shrink(),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            hint: const Text(
              'não identificado',
              style: TextStyle(color: AppTheme.textFaint, fontSize: 11.5),
            ),
            items: const [
              DropdownMenuItem<Sexo?>(value: null, child: Text('Não informado')),
              DropdownMenuItem<Sexo?>(value: Sexo.masculino, child: Text('Masculino')),
              DropdownMenuItem<Sexo?>(value: Sexo.feminino, child: Text('Feminino')),
            ],
            onChanged: (value) => setState(() => _sexo = value),
          ),
        ],
      ),
    );
  }

  Widget _segmentalBlock({
    required String title,
    required String subtitle,
    required Map<String, TextEditingController> kg,
    required Map<String, TextEditingController> pct,
  }) {
    return _block(
      title: title,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            subtitle,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: const [
              Expanded(
                child: Text('Segmento', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ),
              SizedBox(
                width: 84,
                child: Text('kg', textAlign: TextAlign.right,
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ),
              SizedBox(width: 12),
              SizedBox(
                width: 84,
                child: Text('%', textAlign: TextAlign.right,
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ),
            ],
          ),
        ),
        for (final entry in _segments.entries)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.value,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ),
                SizedBox(
                  width: 84,
                  child: TextField(
                    controller: kg[entry.key],
                    textAlign: TextAlign.right,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '—',
                      hintStyle: TextStyle(color: AppTheme.textFaint, fontSize: 11.5),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 84,
                  child: TextField(
                    controller: pct[entry.key],
                    textAlign: TextAlign.right,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '—',
                      hintStyle: TextStyle(color: AppTheme.textFaint, fontSize: 11.5),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _warnings() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 18),
              SizedBox(width: 8),
              Text(
                'Confira antes de salvar',
                style: TextStyle(
                  color: AppTheme.warning,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final warning in widget.result.warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '• $warning',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _unrecognized() {
    return Material(
      color: AppTheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: const Text(
            'Texto não reconhecido',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Preservado para conferência manual',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: [
            SelectableText(
              widget.result.unrecognizedLines.join('\n'),
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11.5, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  static String _format(double? value, {bool integer = false}) {
    if (value == null) return '';
    if (integer) return value.round().toString();
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2).replaceAll('.', ',').replaceAll(RegExp(r'0$'), '');
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static DateTime? _parseDate(String raw) {
    final match = RegExp(r'(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2,4})').firstMatch(raw.trim());
    if (match == null) return null;
    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    var year = int.parse(match.group(3)!);
    if (year < 100) year += 2000;
    final date = DateTime(year, month, day);
    if (date.day != day || date.month != month) return null;
    return date;
  }
}
