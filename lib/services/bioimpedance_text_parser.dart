import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import '../data/models/bioimpedance.dart';
import 'bioimpedance/bioimpedance_exception.dart';
import 'bioimpedance/bioimpedance_extractor.dart';

export 'bioimpedance/bioimpedance_aliases.dart' show BioField, BioFieldSpec, bioFieldSpecs;
export 'bioimpedance/bioimpedance_exception.dart';
export 'bioimpedance/bioimpedance_extractor.dart' show BioimpedanceParseResult;
export 'bioimpedance/bioimpedance_manufacturer.dart' show BioimpedanceManufacturer;
export 'bioimpedance/bioimpedance_text_normalizer.dart';

/// Fachada de leitura de laudos de bioimpedância.
///
/// O trabalho pesado fica em `services/bioimpedance/`:
/// normalização de texto, dicionário de aliases, identificação de fabricante,
/// extração de campos gerais e segmentares, validação e conversão para o
/// modelo `Bioimpedance`.
class BioimpedanceTextParser {
  const BioimpedanceTextParser();

  /// Lê o PDF, extrai o texto e devolve o modelo já convertido.
  Future<Bioimpedance> parsePdf(Uint8List bytes) async {
    return (await parsePdfDetailed(bytes)).bioimpedance;
  }

  /// Igual a [parsePdf], mas devolve também avisos e o texto não reconhecido.
  Future<BioimpedanceParseResult> parsePdfDetailed(Uint8List bytes) async {
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
      return parseDetailed(buffer.toString());
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

  /// Lê texto colado ou produzido pelo OCR e devolve só o modelo.
  Bioimpedance parse(String rawText) => parseDetailed(rawText).bioimpedance;

  /// Lê texto e devolve modelo, fabricante, avisos e linhas não reconhecidas.
  BioimpedanceParseResult parseDetailed(String rawText) =>
      const BioimpedanceExtractor().extract(rawText);
}
