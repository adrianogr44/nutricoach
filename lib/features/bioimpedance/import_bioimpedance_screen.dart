import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/bioimpedance.dart';
import '../../services/bioimpedance_text_parser.dart';
import '../../services/device_text_recognizer.dart';
import '../../state/app_state.dart';

/// Importa um laudo de bioimpedância (foto ou texto colado do PDF) e aplica
/// ao perfil: peso, altura, IMC, %gordura, massa muscular, água, TMB, etc.
class ImportBioimpedanceScreen extends StatefulWidget {
  const ImportBioimpedanceScreen({super.key});

  @override
  State<ImportBioimpedanceScreen> createState() => _ImportBioimpedanceScreenState();
}

class _ImportBioimpedanceScreenState extends State<ImportBioimpedanceScreen> {
  final _picker = ImagePicker();
  final _textController = TextEditingController();
  bool _busy = false;
  String? _error;
  Bioimpedance? _parsed;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _fromImage(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final text = await const DeviceTextRecognizer().recognizeFile(file.path);
      final bio = const BioimpedanceTextParser().parse(text);
      if (mounted) setState(() => _parsed = bio);
    } on LocalParseException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Falha ao ler a imagem: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pasteText() async {
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Cole o texto do laudo'),
        content: TextField(
          controller: _textController,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText:
                'Ex.: abra o PDF no leitor, selecione tudo e copie. '
                'Cole aqui. (Peso 121.2 kg, IMC 35.4...)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _textController.text),
            child: const Text('Usar texto'),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bio = const BioimpedanceTextParser().parse(text);
      if (mounted) setState(() => _parsed = bio);
    } on LocalParseException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fromPdf() async {
    final FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
        dialogTitle: 'Selecione o PDF do laudo',
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Falha ao abrir o seletor: $e');
      return;
    }
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = result.files.single;
      final bytes = file.bytes ?? await file.xFile.readAsBytes();
      final bio = await const BioimpedanceTextParser().parsePdf(bytes);
      if (mounted) setState(() => _parsed = bio);
    } on LocalParseException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Falha ao ler o PDF: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clear() {
    setState(() {
      _parsed = null;
      _error = null;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bio = _parsed;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Importar bioimpedância',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: bio == null ? _buildSource() : _buildReview(bio),
    );
  }

  Widget _buildSource() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
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
              const Text(
                'Como funciona',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'O OCR local lê fotos sem enviá-las para servidores. Envie '
                'seu laudo ou cole o texto; revise os valores antes de aplicar '
                'ao perfil. O app reconhece '
                'com peso, altura, IMC, % de gordura, massa muscular, água '
                'corporal e taxa metabólica basal (TMB) medida.',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: 12),
                  Text('Lendo o laudo...',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            ),
          )
        else ...[
          _button(Icons.photo_camera, 'Tirar foto do laudo',
              'Enquadre a página inteira, com boa luz',
              () => _fromImage(ImageSource.camera)),
          const SizedBox(height: 12),
          _button(Icons.photo_library, 'Enviar foto da galeria',
              'Escolha uma imagem do relatório',
              () => _fromImage(ImageSource.gallery)),
          const SizedBox(height: 12),
          _button(Icons.content_paste, 'Colar texto do PDF',
              'Abra o PDF no leitor, copie tudo e cole aqui',
              _pasteText),
          const SizedBox(height: 12),
          _button(Icons.picture_as_pdf, 'Enviar arquivo PDF',
              'Escolha o laudo em PDF diretamente',
              _fromPdf),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: AppTheme.danger, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    _error!,
                    style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _button(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primary, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12.5)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReview(Bioimpedance bio) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Valores encontrados no laudo — revise e aplique',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Data do laudo: ${_fmtDate(bio.data)}',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              _row('Peso', bio.pesoKg, 'kg'),
              _row('Altura', bio.alturaCm, 'cm'),
              _row('Idade', bio.idade?.toDouble(), 'anos'),
              _row('IMC', bio.imc, 'kg/m²'),
              _row('Gordura corporal', bio.gorduraPct, '%'),
              _row('Massa de gordura', bio.gorduraKg, 'kg'),
              _row('Massa muscular', bio.massaMuscularKg, 'kg'),
              _row('Água corporal', bio.aguaL, 'L'),
              _row('Proteína', bio.proteinaKg, 'kg'),
              _row('Minerais', bio.mineraisKg, 'kg'),
              _row('TMB medida', bio.tmbKcal, 'kcal/dia'),
              _row('Gordura visceral', bio.gorduraVisceral?.toDouble(), 'nível'),
              _row('Cintura/quadril', bio.relacaoCinturaQuadril, ''),
              _row('Peso ideal', bio.pesoIdealKg, 'kg'),
              _row('Pontuação InBody', bio.pontuacao?.toDouble(), '/100'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _clear,
                child: const Text('Descartar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: () => _apply(bio),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Aplicar ao perfil'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(String label, double? value, String unit) {
    final filled = value != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          ),
          Text(
            filled ? '${_fmtNum(value)} $unit' : '— não informado',
            style: TextStyle(
              color: filled ? AppTheme.textPrimary : AppTheme.textMuted,
              fontSize: 14,
              fontWeight: filled ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _apply(Bioimpedance bio) async {
    final state = context.read<AppState>();
    await state.importBioimpedance(bio);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bioimpedância aplicada ao perfil!')),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _fmtNum(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2).replaceAll('.', ',');
}