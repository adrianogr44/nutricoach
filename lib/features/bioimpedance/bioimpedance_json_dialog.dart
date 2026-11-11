import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../services/bioimpedance/bioimpedance_json_parser.dart';
import '../../services/bioimpedance_text_parser.dart';

/// Abre o preenchimento por JSON e devolve o resultado lido (ou `null`).
Future<BioimpedanceParseResult?> showBioimpedanceJsonDialog(BuildContext context) {
  return showDialog<BioimpedanceParseResult>(
    context: context,
    builder: (_) => const BioimpedanceJsonDialog(),
  );
}

/// Diálogo para colar/editar um JSON de bioimpedância.
class BioimpedanceJsonDialog extends StatefulWidget {
  const BioimpedanceJsonDialog({super.key});

  @override
  State<BioimpedanceJsonDialog> createState() => _BioimpedanceJsonDialogState();
}

class _BioimpedanceJsonDialogState extends State<BioimpedanceJsonDialog> {
  final _controller = TextEditingController();
  String? _error;

  static const _example = '''{
  "data": "2026-09-03",
  "pesoKg": 121.2,
  "alturaCm": 185,
  "idade": 23,
  "sexo": "masculino",
  "imc": 35.4,
  "gorduraPct": 40.4,
  "gorduraKg": 47.9,
  "massaMuscularEsqueleticaKg": 41.1,
  "aguaL": 52.7,
  "proteinaKg": 12.9,
  "mineraisKg": 4.3,
  "tmbKcal": 1930,
  "gorduraVisceral": 20,
  "grauObesidade": 141,
  "relacaoCinturaQuadril": 0.98,
  "pontuacao": 52
}''';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (!mounted) return;
    if (text == null || text.isEmpty) {
      setState(() => _error = 'A área de transferência está vazia.');
      return;
    }
    setState(() {
      _controller.text = text;
      _error = null;
    });
  }

  void _apply() {
    try {
      final result = const BioimpedanceJsonParser().parse(_controller.text);
      Navigator.pop(context, result);
    } on LocalParseException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      scrollable: true,
      title: const Text(
        'Preencher com JSON',
        style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 17),
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cole o JSON exportado pelo NutriCoach ou um objeto com campos '
              'como pesoKg, imc, gorduraPct, massaMuscularEsqueleticaKg e '
              'massaMagraSegmentar. Campos desconhecidos ficam preservados na revisão.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              minLines: 6,
              maxLines: 12,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12.5,
                height: 1.45,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                hintText: _example,
                hintMaxLines: 8,
                hintStyle: const TextStyle(color: AppTheme.textFaint, fontSize: 11.5, height: 1.4),
                filled: true,
                fillColor: AppTheme.backgroundElevated,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _paste,
                  icon: const Icon(Icons.content_paste, size: 16),
                  label: const Text('Colar'),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _controller.text = _example;
                    _error = null;
                  }),
                  icon: const Icon(Icons.description_outlined, size: 16),
                  label: const Text('Exemplo'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.danger, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SelectableText(
                      _error!,
                      style: const TextStyle(color: AppTheme.danger, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _apply,
          icon: const Icon(Icons.data_object, size: 18),
          label: const Text('Ler JSON'),
        ),
      ],
    );
  }
}
