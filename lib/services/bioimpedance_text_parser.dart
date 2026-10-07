import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import '../data/models/bioimpedance.dart';
import '../data/models/user_profile.dart';

class LocalParseException implements Exception {
  const LocalParseException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BioimpedanceTextParser {
  const BioimpedanceTextParser();

  Future<Bioimpedance> parsePdf(Uint8List bytes) async {
    PdfDocument? document;
    try {
      document = await PdfDocument.openData(bytes);
      final buffer = StringBuffer();
      for (final page in document.pages) {
        await page.ensureLoaded();
        final text = await page.loadText();
        if (text != null && text.fullText.trim().isNotEmpty) {
          buffer.writeln(text.fullText);
        }
      }
      if (buffer.toString().trim().isEmpty) {
        throw const LocalParseException(
          'O PDF não contém texto. Em um laudo digitalizado, use a foto com OCR local.',
        );
      }
      return parse(buffer.toString());
    } on LocalParseException {
      rethrow;
    } catch (_) {
      throw const LocalParseException(
        'Não foi possível abrir o PDF selecionado.',
      );
    } finally {
      await document?.dispose();
    }
  }

  Bioimpedance parse(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) {
      throw const LocalParseException('O texto do laudo está vazio.');
    }

    final date = _date(text) ?? DateTime.now();
    final sexText = _textValue(text, const ['sexo', 'gênero', 'genero']);
    Sexo? sexo;
    if (sexText != null) {
      final normalized = sexText.toLowerCase();
      if (normalized.contains('fem')) sexo = Sexo.feminino;
      if (normalized.contains('masc')) sexo = Sexo.masculino;
    }

    final bio = Bioimpedance(
      data: date,
      pesoKg: _value(text, const ['peso']),
      alturaCm: _value(text, const ['altura']),
      idade: _value(text, const ['idade'])?.round(),
      sexo: sexo,
      imc: _value(text, const ['imc']),
      gorduraPct: _value(text, const [
        'percentual de gordura corporal',
        'gordura corporal',
        'percentual de gordura',
      ]),
      gorduraKg: _value(text, const ['massa de gordura', 'gordura em kg']),
      massaMuscularKg: _value(text, const [
        'massa muscular esquelética',
        'massa muscular esqueletica',
        'massa muscular',
      ]),
      aguaL: _value(text, const [
        'água corporal total',
        'agua corporal total',
        'água corporal',
        'agua corporal',
      ]),
      proteinaKg: _value(text, const ['proteína', 'proteina']),
      mineraisKg: _value(text, const ['minerais']),
      tmbKcal: _value(text, const [
        'taxa metabólica basal',
        'taxa metabolica basal',
        'tmb',
      ]),
      gorduraVisceral: _value(text, const [
        'nível de gordura visceral',
        'nivel de gordura visceral',
        'gordura visceral',
      ])?.round(),
      relacaoCinturaQuadril: _value(text, const [
        'relação cintura-quadril',
        'relacao cintura-quadril',
        'relação cintura quadril',
        'rcq',
      ]),
      pesoIdealKg: _value(text, const ['peso ideal']),
      pontuacao: _value(text, const [
        'pontuação inbody',
        'pontuacao inbody',
        'pontuação',
        'pontuacao',
      ])?.round(),
    );

    if (bio.pesoKg == null &&
        bio.imc == null &&
        bio.gorduraPct == null &&
        bio.massaMuscularKg == null) {
      throw const LocalParseException(
        'Nenhum campo conhecido foi encontrado. Revise o texto extraído.',
      );
    }
    return bio;
  }

  double? _value(String text, List<String> labels) {
    for (final label in labels) {
      final match = RegExp(
        '${RegExp.escape(label)}\\s*[:.-]?\\s*([0-9]+(?:[.,][0-9]+)?)',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        return double.tryParse(match.group(1)!.replaceAll(',', '.'));
      }
    }
    return null;
  }

  String? _textValue(String text, List<String> labels) {
    for (final label in labels) {
      final match = RegExp(
        '${RegExp.escape(label)}\\s*[:.-]?\\s*([^\\n\\r]+)',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) return match.group(1)?.trim();
    }
    return null;
  }

  DateTime? _date(String text) {
    final match = RegExp(
      r'(?:data\s*[:.-]?\s*)?(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;
    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    var year = int.parse(match.group(3)!);
    if (year < 100) year += 2000;
    return DateTime(year, month, day);
  }
}
