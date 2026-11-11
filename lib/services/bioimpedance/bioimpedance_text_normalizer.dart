/// Normalização de texto e de números para leitura de laudos de bioimpedância.
///
/// O texto extraído de PDFs e do OCR chega com acentos, unidades, separadores
/// diferentes e quebras de linha no meio do campo. Esta camada concentra toda
/// essa bagunça para que o extrator trabalhe com um formato previsível.
library;

class NormalizedLine {
  const NormalizedLine(this.original, this.normalized);

  /// Linha como veio do PDF/OCR (usada na revisão e nos avisos).
  final String original;

  /// Linha em minúsculas, sem acentos, sem parênteses e com espaços simples.
  final String normalized;

  bool get isBlank => normalized.trim().isEmpty;
}

class BioimpedanceTextNormalizer {
  const BioimpedanceTextNormalizer();

  static const Map<String, String> _accentMap = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n', 'ý': 'y', 'ÿ': 'y',
  };

  /// Converte para minúsculas, remove acentos e normaliza separadores.
  String normalize(String input) {
    final buffer = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_accentMap[char] ?? char);
    }
    return buffer
        .toString()
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'[()\[\]{}]'), ' ')
        .replaceAll('\u2013', '-')
        .replaceAll('\u2014', '-')
        .replaceAll('\u2212', '-')
        .replaceAll('\u2019', "'")
        .replaceAll('\u00ba', 'o')
        .replaceAll('\u00aa', 'a')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
  }

  List<NormalizedLine> lines(String input) {
    return [
      for (final raw in input.split(RegExp(r'\r\n|\r|\n')))
        NormalizedLine(raw.trim(), normalize(raw)),
    ];
  }

  /// Lê números nos formatos do Brasil e do exterior.
  ///
  /// `1.234,5`, `1,234.5`, `35,4`, `35.4` e `1.930` são aceitos. Quando o ponto
  /// é ambíguo (milhar ou decimal), a faixa esperada do campo decide; se ambos
  /// os lados forem possíveis, mantém a leitura decimal.
  double? parseNumber(String raw, {double? min, double? max}) {
    var text = raw.replaceAll(RegExp(r'[^0-9,.\-]'), '').trim();
    if (text.isEmpty || text == '-' || text == '.' || text == ',') return null;

    final hasComma = text.contains(',');
    final hasDot = text.contains('.');
    bool inRange(double? value) =>
        value != null && (min == null || value >= min) && (max == null || value <= max);

    if (hasComma && hasDot) {
      final commaLast = text.lastIndexOf(',') > text.lastIndexOf('.');
      final candidate = commaLast
          ? text.replaceAll('.', '').replaceAll(',', '.')
          : text.replaceAll(',', '');
      return double.tryParse(candidate);
    }
    if (hasComma) {
      final decimal = double.tryParse(text.replaceAll('.', '').replaceAll(',', '.'));
      final parts = text.split(',');
      if (parts.length == 2 && parts[1].length == 3 && parts[0] != '0') {
        final thousands = double.tryParse(parts.join());
        if (inRange(thousands) && !inRange(decimal)) return thousands;
      }
      return decimal;
    }
    if (!hasDot) return double.tryParse(text);

    final parts = text.split('.');
    final decimal = double.tryParse(text);
    if (parts.length == 2 && parts[1].length == 3 && parts[0] != '0') {
      final thousands = double.tryParse(parts.join());
      final preferThousands = inRange(thousands) && !inRange(decimal);
      if (preferThousands) return thousands;
    }
    if (parts.length > 2) {
      final thousands = double.tryParse(parts.join());
      if (thousands != null) return thousands;
    }
    return decimal;
  }
}
