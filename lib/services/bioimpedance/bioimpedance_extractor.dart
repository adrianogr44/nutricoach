import '../../data/models/bioimpedance.dart';
import '../../data/models/user_profile.dart';
import 'bioimpedance_aliases.dart';
import 'bioimpedance_exception.dart';
import 'bioimpedance_manufacturer.dart';
import 'bioimpedance_text_normalizer.dart';

/// Resultado completo da leitura: além do modelo pronto para salvar, carrega o
/// que foi reconhecido, o que ficou de fora e os avisos para a revisão humana.
class BioimpedanceParseResult {
  const BioimpedanceParseResult({
    required this.bioimpedance,
    required this.manufacturer,
    required this.values,
    required this.rawValues,
    required this.unrecognizedLines,
    required this.warnings,
    required this.rawText,
  });

  final Bioimpedance bioimpedance;
  final BioimpedanceManufacturer manufacturer;

  /// Valores encontrados por campo (antes de virarem o modelo).
  final Map<BioField, double> values;

  /// Trecho original de onde cada valor saiu, para auditoria na revisão.
  final Map<BioField, String> rawValues;

  /// Linhas com números que não foram associadas a nenhum campo.
  final List<String> unrecognizedLines;

  /// Incoerências e observações — nunca usadas para descartar valores.
  final List<String> warnings;

  final String rawText;

  bool get foundSegmentalLean => bioimpedance.massaMagraSegmentar?.isNotEmpty ?? false;
  bool get foundSegmentalFat => bioimpedance.gorduraSegmentar?.isNotEmpty ?? false;
}

class _NumberToken {
  const _NumberToken({
    required this.value,
    required this.start,
    required this.end,
    required this.unit,
    required this.inRange,
  });

  final double value;
  final int start;
  final int end;
  final String? unit;
  final bool inRange;
}

/// Extrai bioimpedância de texto de PDF/OCR.
///
/// O fluxo é: normalizar → identificar fabricante → cortar histórico →
/// ler seções segmentares → ler campos gerais → validar → montar o modelo.
class BioimpedanceExtractor {
  const BioimpedanceExtractor();

  static const BioimpedanceTextNormalizer _normalizer = BioimpedanceTextNormalizer();
  static const BioimpedanceManufacturerDetector _detector = BioimpedanceManufacturerDetector();

  BioimpedanceParseResult extract(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) {
      throw const LocalParseException('O texto do laudo está vazio.');
    }

    final lines = _normalizer.lines(text);
    final full = _normalizer.normalize(text);
    final manufacturer = _detector.detect(full);
    final specs = _detector.specsFor(manufacturer);
    final cut = _historyCut(lines);
    final warnings = <String>[];

    final consumedLines = <int>{};
    final lean = _extractSegmental(
      lines: lines,
      cut: cut,
      consumedLines: consumedLines,
      sectionAliases: BioSectionAliases.leanSegmental,
      warnings: warnings,
      label: 'massa magra segmentar',
    );
    final fat = _extractSegmental(
      lines: lines,
      cut: cut,
      consumedLines: consumedLines,
      sectionAliases: BioSectionAliases.fatSegmental,
      warnings: warnings,
      label: 'gordura segmentar',
    );

    final consumedSpans = <int, List<(int, int)>>{};
    final values = <BioField, double>{};
    final rawValues = <BioField, String>{};

    for (final spec in specs) {
      if (values.containsKey(spec.field)) continue;
      final hit = _findField(
        lines: lines,
        specs: specs,
        spec: spec,
        cut: cut,
        consumedLines: consumedLines,
        consumedSpans: consumedSpans,
      );
      if (hit == null) continue;
      values[spec.field] = hit.value;
      rawValues[spec.field] = hit.raw;
    }

    final date = _extractDate(lines, cut, warnings);
    final sexo = _extractSex(lines, cut);

    var altura = values[BioField.height];
    if (altura != null && altura > 0 && altura < 3) {
      altura = altura * 100;
      warnings.add('Altura lida em metros (${values[BioField.height]}) e convertida para centímetros.');
    }

    final bio = Bioimpedance(
      data: date ?? DateTime.now(),
      pesoKg: values[BioField.weight],
      alturaCm: altura,
      idade: values[BioField.age]?.round(),
      sexo: sexo,
      imc: values[BioField.bmi],
      gorduraPct: values[BioField.bodyFatPercentage],
      gorduraKg: values[BioField.fatMass],
      massaMuscularKg: values[BioField.muscleMass],
      massaMuscularEsqueleticaKg: values[BioField.skeletalMuscleMass],
      aguaL: values[BioField.totalBodyWater],
      proteinaKg: values[BioField.proteinMass],
      mineraisKg: values[BioField.mineralMass],
      tmbKcal: values[BioField.basalMetabolicRate],
      gorduraVisceral: values[BioField.visceralFatLevel]?.round(),
      grauObesidade: values[BioField.obesityDegree],
      relacaoCinturaQuadril: values[BioField.waistHipRatio],
      pesoIdealKg: values[BioField.idealWeight],
      pontuacao: values[BioField.inBodyScore]?.round(),
      massaMagraSegmentar: lean,
      gorduraSegmentar: fat,
      fonte: manufacturer.displayName,
    );

    if (date == null) {
      warnings.add('Data da avaliação não encontrada — usando a data de hoje.');
    }
    _validate(bio, warnings);

    final recognized = values.isNotEmpty || lean != null || fat != null;
    if (!recognized) {
      throw const LocalParseException(
        'Nenhum campo conhecido foi encontrado. Revise o texto extraído e '
        'preencha os valores manualmente.',
      );
    }

    return BioimpedanceParseResult(
      bioimpedance: bio,
      manufacturer: manufacturer,
      values: values,
      rawValues: rawValues,
      unrecognizedLines: _unrecognized(lines, cut, consumedLines, consumedSpans),
      warnings: warnings,
      rawText: text,
    );
  }

  // ───────────────────────────── campos gerais ─────────────────────────────

  _FieldHit? _findField({
    required List<NormalizedLine> lines,
    required List<BioFieldSpec> specs,
    required BioFieldSpec spec,
    required int cut,
    required Set<int> consumedLines,
    required Map<int, List<(int, int)>> consumedSpans,
  }) {
    final orderedAliases = [...spec.aliases]..sort((a, b) => b.length.compareTo(a.length));

    for (final alias in orderedAliases) {
      final pattern = RegExp(RegExp.escape(alias));
      for (var i = 0; i < cut; i++) {
        if (consumedLines.contains(i)) continue;
        final line = lines[i];
        if (line.isBlank) continue;

        for (final match in pattern.allMatches(line.normalized)) {
          if (_overlaps(consumedSpans[i], match.start, match.end)) continue;
          _consume(consumedSpans, i, match.start, match.end);

          // 1) valor na mesma linha, depois do nome do campo
          final sameLine = _pickToken(
            _tokens(line.normalized, spec, start: match.end),
            spec,
            line.normalized,
          );
          if (sameLine != null) {
            _consume(consumedSpans, i, sameLine.start, sameLine.end);
            return _FieldHit(sameLine.value, line.original.trim());
          }

          // 2) valor em uma das duas linhas seguintes (nome e número separados)
          for (var j = i + 1; j <= i + 2 && j < cut; j++) {
            if (consumedLines.contains(j)) break;
            final next = lines[j];
            if (next.isBlank) continue;
            if (_matchesAnyAlias(next.normalized, specs)) break;
            if (_isTerminator(next.normalized)) break;
            final tokens = _tokens(next.normalized, spec);
            final token = _pickToken(tokens, spec, next.normalized);
            if (token != null) {
              _consume(consumedSpans, j, token.start, token.end);
              final raw = '${line.original.trim()} ${next.original.trim()}';
              return _FieldHit(token.value, raw);
            }
            if (tokens.isNotEmpty) break;
          }
        }
      }
    }
    return null;
  }

  _NumberToken? _pickToken(List<_NumberToken> tokens, BioFieldSpec spec, String line) {
    if (tokens.isEmpty) return null;
    final usable = tokens.where((t) => t.value > 0).toList();
    if (usable.isEmpty) return null;

    _NumberToken? best;
    var bestScore = -1000;
    final numberCount = tokens.length;
    final referenceLine = _looksLikeReference(line);

    for (final token in usable) {
      var score = 0;
      if (spec.unit.isNotEmpty) {
        if (token.unit != null) {
          score += _unitMatches(token.unit!, spec.unit) ? 4 : -3;
        }
      }
      if (token.inRange) {
        score -= 8;
      } else {
        score += 2;
      }
      if (spec.integer && token.value != token.value.roundToDouble()) score -= 1;
      if (numberCount >= 6) score -= 4;
      if (referenceLine) score -= 2;
      final inSanity = (spec.min == null || token.value >= spec.min!) &&
          (spec.max == null || token.value <= spec.max!);
      score += inSanity ? 1 : -5;

      if (score > bestScore) {
        best = token;
        bestScore = score;
      }
    }
    return best;
  }

  List<_NumberToken> _tokens(String line, BioFieldSpec spec, {int start = 0}) {
    final tokens = <_NumberToken>[];
    final pattern = RegExp(r'[0-9]+(?:[.,][0-9]+)*');
    for (final match in pattern.allMatches(line)) {
      if (match.start < start) continue;
      final beforeChar = match.start > 0 ? line[match.start - 1] : '';
      if (beforeChar == ',' || beforeChar == '.') continue;
      final value = _normalizer.parseNumber(match.group(0)!, min: spec.min, max: spec.max);
      if (value == null) continue;

      final after = line.substring(match.end);
      final unitMatch = RegExp(
        r'^\s*(%|kg/m²|kg/m2|kcal(?:/[a-z0-9]{1,4})?|kgs?|g|ml|lts?|litros?|l|cm|mm|pts|pontos|bpm)(?![a-z0-9/])',
      ).firstMatch(after);
      final unit = unitMatch?.group(1);

      tokens.add(_NumberToken(
        value: value,
        start: match.start,
        end: match.end,
        unit: unit,
        inRange: _isInRange(line, match.start, match.end),
      ));
    }
    return tokens;
  }

  bool _isInRange(String line, int start, int end) {
    final before = line.substring(0, start).trimRight();
    if (before.endsWith('~') || before.endsWith('-')) return true;
    if (RegExp(r'(?:\ba|\bde)$').hasMatch(before)) return true;
    final after = line.substring(end);
    if (RegExp(r'^\s*[~-]\s*\d').hasMatch(after)) return true;
    return false;
  }

  bool _unitMatches(String found, String expected) {
    String canon(String unit) {
      final u = unit.toLowerCase().trim();
      if (u == 'kgs' || u == 'quilo' || u == 'quilos' || u == 'k') return 'kg';
      if (u == 'lt' || u == 'litro' || u == 'litros' || u == 'lts') return 'l';
      if (u == 'pct' || u == 'porcento') return '%';
      if (u == 'kcal/dia' || u == 'kcal/kg' || u == 'kcal/d') return 'kcal';
      if (u == 'pts' || u == 'pontos' || u == 'pontos.') return 'pontos';
      if (u == 'kg/m2' || u == 'kg/m²') return 'kg/m2';
      return u;
    }

    return canon(found) == canon(expected);
  }

  bool _overlaps(List<(int, int)>? spans, int start, int end) {
    if (spans == null) return false;
    for (final (s, e) in spans) {
      if (start < e && end > s) return true;
    }
    return false;
  }

  void _consume(Map<int, List<(int, int)>> spans, int line, int start, int end) {
    spans.putIfAbsent(line, () => []).add((start, end));
  }

  bool _matchesAnyAlias(String line, List<BioFieldSpec> specs) {
    for (final spec in specs) {
      for (final alias in spec.aliases) {
        if (line.contains(alias)) return true;
      }
    }
    return false;
  }

  bool _looksLikeReference(String line) =>
      line.contains('referencia') ||
      line.contains('referencial') ||
      line.contains('faixa') ||
      line.contains('normal') ||
      line.contains('min') ||
      line.contains('max') ||
      line.contains('limite');

  bool _isTerminator(String line) {
    for (final alias in BioSectionAliases.terminators) {
      if (line.contains(alias)) return true;
    }
    return false;
  }

  // ──────────────────────────── dados segmentares ────────────────────────────

  SegmentalValues? _extractSegmental({
    required List<NormalizedLine> lines,
    required int cut,
    required Set<int> consumedLines,
    required List<String> sectionAliases,
    required List<String> warnings,
    required String label,
  }) {
    var header = -1;
    for (var i = 0; i < cut; i++) {
      final normalized = lines[i].normalized;
      if (sectionAliases.any(normalized.contains)) {
        header = i;
        break;
      }
    }
    if (header < 0) return null;

    final end = _sectionEnd(lines, header, cut, sectionAliases);
    for (var i = header; i < end; i++) {
      consumedLines.add(i);
    }

    final block = [for (var i = header; i < end; i++) lines[i]];
    final order = _columnOrder(block);
    SegmentalValues? values;

    if (order != null) {
      var kgAssigned = false;
      var pctAssigned = false;
      for (final line in block) {
        if (line.normalized.isEmpty) continue;
        final tokens = _tokens(line.normalized, const BioFieldSpec(
          field: BioField.weight,
          label: 'segmento',
          unit: 'kg',
          aliases: [],
        )).where((t) => !t.inRange).toList();
        if (tokens.length < order.length) continue;
        final isPercentRow = line.normalized.contains('%') || line.normalized.contains('percent');
        if ((isPercentRow || kgAssigned) && !pctAssigned) {
          values = (values ?? const SegmentalValues()).copyWith(
            rightArmPct: order['rightArm'] != null ? tokens[order['rightArm']!].value : null,
            leftArmPct: order['leftArm'] != null ? tokens[order['leftArm']!].value : null,
            trunkPct: order['trunk'] != null ? tokens[order['trunk']!].value : null,
            rightLegPct: order['rightLeg'] != null ? tokens[order['rightLeg']!].value : null,
            leftLegPct: order['leftLeg'] != null ? tokens[order['leftLeg']!].value : null,
          );
          pctAssigned = true;
          continue;
        }
        if (!kgAssigned) {
          values = (values ?? const SegmentalValues()).copyWith(
            rightArm: order['rightArm'] != null ? tokens[order['rightArm']!].value : null,
            leftArm: order['leftArm'] != null ? tokens[order['leftArm']!].value : null,
            trunk: order['trunk'] != null ? tokens[order['trunk']!].value : null,
            rightLeg: order['rightLeg'] != null ? tokens[order['rightLeg']!].value : null,
            leftLeg: order['leftLeg'] != null ? tokens[order['leftLeg']!].value : null,
          );
          kgAssigned = true;
        }
        if (kgAssigned && pctAssigned) break;
      }
    }

    if (values == null || values.isEmpty) {
      // Layout com um segmento por linha.
      values = _segmentalByLine(block, warnings, label);
    }

    if (values == null || values.isEmpty) return null;
    return values;
  }

  int _sectionEnd(List<NormalizedLine> lines, int header, int cut, List<String> sectionAliases) {
    final own = sectionAliases.join('|');
    final ownPattern = RegExp(own);
    var numericLines = 0;
    for (var i = header + 1; i < cut && i < header + 16; i++) {
      final line = lines[i].normalized;
      if (line.isEmpty) {
        if (numericLines > 0) return i;
        continue;
      }
      if (numericLines > 0 && _isTerminator(line) && !ownPattern.hasMatch(line)) return i;
      if (RegExp(r'\d').hasMatch(line)) numericLines++;
    }
    return (header + 16) < cut ? (header + 16) : cut;
  }

  Map<String, int>? _columnOrder(List<NormalizedLine> block) {
    for (final line in block) {
      final positions = <String, int>{};
      const keys = {
        'rightArm': ['braco direito', 'braco dir', 'braco d', 'right arm'],
        'leftArm': ['braco esquerdo', 'braco esq', 'braco e', 'left arm'],
        'trunk': ['tronco', 'trunk'],
        'rightLeg': ['perna direita', 'perna dir', 'perna d', 'right leg'],
        'leftLeg': ['perna esquerda', 'perna esq', 'perna e', 'left leg'],
      };
      keys.forEach((key, aliases) {
        for (final alias in aliases) {
          final index = line.normalized.indexOf(alias);
          if (index >= 0) {
            final current = positions[key];
            positions[key] = current == null || index < current ? index : current;
            break;
          }
        }
      });
      if (positions.length < 3) continue;
      final sorted = positions.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
      return {for (var i = 0; i < sorted.length; i++) sorted[i].key: i};
    }
    return null;
  }

  SegmentalValues? _segmentalByLine(
    List<NormalizedLine> block,
    List<String> warnings,
    String label,
  ) {
    const segments = {
      'rightArm': ['braco direito', 'braco dir', 'right arm'],
      'leftArm': ['braco esquerdo', 'braco esq', 'left arm'],
      'trunk': ['tronco', 'trunk'],
      'rightLeg': ['perna direita', 'perna dir', 'right leg'],
      'leftLeg': ['perna esquerda', 'perna esq', 'left leg'],
    };
    final kg = <String, double>{};
    final pct = <String, double>{};

    for (final line in block) {
      for (final entry in segments.entries) {
        final alias = entry.value.firstWhere(
          (candidate) => line.normalized.contains(candidate),
          orElse: () => '',
        );
        if (alias.isEmpty) continue;
        final tokens = _tokens(
          line.normalized,
          const BioFieldSpec(
            field: BioField.weight,
            label: 'segmento',
            unit: 'kg',
            aliases: [],
          ),
        ).where((t) => !t.inRange).toList();
        if (tokens.isEmpty) continue;
        final percentToken = tokens.where((t) => t.unit == '%').firstOrNull;
        final kgToken = tokens.where((t) => t.unit == 'kg').firstOrNull ??
            tokens.where((t) => t.unit != '%').firstOrNull ??
            tokens.first;
        if (kgToken.value > 0 && kgToken.unit != '%') kg[entry.key] = kgToken.value;
        if (percentToken != null) pct[entry.key] = percentToken.value;
      }
    }

    if (kg.isEmpty && pct.isEmpty) {
      warnings.add('Seção de $label encontrada, mas sem valores legíveis.');
      return null;
    }
    return SegmentalValues(
      rightArm: kg['rightArm'],
      leftArm: kg['leftArm'],
      trunk: kg['trunk'],
      rightLeg: kg['rightLeg'],
      leftLeg: kg['leftLeg'],
      rightArmPct: pct['rightArm'],
      leftArmPct: pct['leftArm'],
      trunkPct: pct['trunk'],
      rightLegPct: pct['rightLeg'],
      leftLegPct: pct['leftLeg'],
    );
  }

  // ─────────────────────────── data, sexo, validação ───────────────────────────

  DateTime? _extractDate(List<NormalizedLine> lines, int cut, List<String> warnings) {
    final limit = cut < 40 ? cut : 40;
    String? preferred;
    String? fallback;

    for (var i = 0; i < limit; i++) {
      final line = lines[i].normalized;
      if (line.isEmpty) continue;
      if (line.contains('nasc')) continue;
      final date = _parseDateIn(line);
      if (date == null) continue;
      final isLabeled = line.contains('data') ||
          line.contains('avaliacao') ||
          line.contains('exame') ||
          line.contains('medicao');
      if (isLabeled && preferred == null) {
        preferred = line;
      }
      fallback ??= line;
    }

    final source = preferred ?? fallback;
    if (source == null) return null;
    final date = _parseDateIn(source);
    if (date == null) return null;
    final now = DateTime.now();
    if (date.isAfter(now.add(const Duration(days: 1)))) {
      warnings.add('A data encontrada ($source) está no futuro — confira a revisão.');
    }
    return date;
  }

  DateTime? _parseDateIn(String line) {
    final iso = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(line);
    if (iso != null) {
      final year = int.parse(iso.group(1)!);
      final month = int.parse(iso.group(2)!);
      final day = int.parse(iso.group(3)!);
      if (_validDate(day, month, year)) return DateTime(year, month, day);
    }

    final numeric = RegExp(r'(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2,4})').firstMatch(line);
    if (numeric != null) {
      final day = int.parse(numeric.group(1)!);
      final month = int.parse(numeric.group(2)!);
      var year = int.parse(numeric.group(3)!);
      if (year < 100) year += 2000;
      if (_validDate(day, month, year)) return DateTime(year, month, day);
    }

    const months = {
      'janeiro': 1,
      'fevereiro': 2,
      'marco': 3,
      'abril': 4,
      'maio': 5,
      'junho': 6,
      'julho': 7,
      'agosto': 8,
      'setembro': 9,
      'outubro': 10,
      'novembro': 11,
      'dezembro': 12,
    };
    final words = RegExp(r'(\d{1,2})\s+de\s+([a-z]+)\s+de\s+(\d{4})').firstMatch(line);
    if (words != null) {
      final day = int.parse(words.group(1)!);
      final month = months[words.group(2)!];
      final year = int.parse(words.group(3)!);
      if (month != null && _validDate(day, month, year)) return DateTime(year, month, day);
    }
    return null;
  }

  bool _validDate(int day, int month, int year) {
    if (year < 1990 || year > 2100) return false;
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > 31) return false;
    final date = DateTime(year, month, day);
    return date.day == day && date.month == month;
  }

  Sexo? _extractSex(List<NormalizedLine> lines, int cut) {
    for (var i = 0; i < cut; i++) {
      final line = lines[i].normalized;
      if (!line.contains('sexo') && !line.contains('genero')) continue;
      final source = '$line ${i + 1 < cut ? lines[i + 1].normalized : ''}';
      if (source.contains('femin') || RegExp(r'\bsexo\b[^a-z]{0,6}\bf\b').hasMatch(source)) {
        return Sexo.feminino;
      }
      if (source.contains('masc') || RegExp(r'\bsexo\b[^a-z]{0,6}\bm\b').hasMatch(source)) {
        return Sexo.masculino;
      }
      if (RegExp(r'\bgenero\b[^a-z]{0,6}\bf\b').hasMatch(source)) return Sexo.feminino;
      if (RegExp(r'\bgenero\b[^a-z]{0,6}\bm\b').hasMatch(source)) return Sexo.masculino;
    }
    return null;
  }

  void _validate(Bioimpedance bio, List<String> warnings) {
    if (bio.gorduraKg != null && bio.pesoKg != null && bio.gorduraKg! > bio.pesoKg!) {
      warnings.add('Massa de gordura maior que o peso: confira os valores lidos.');
    }
    if (bio.gorduraPct != null && bio.gorduraPct! > 70) {
      warnings.add('Percentual de gordura acima de 70%: confira o valor lido.');
    }
    if (bio.gorduraKg != null && bio.pesoKg != null && bio.gorduraPct != null) {
      final expected = (bio.gorduraKg! / bio.pesoKg!) * 100;
      if ((expected - bio.gorduraPct!).abs() > 15) {
        warnings.add('Percentual de gordura não bate com massa de gordura e peso.');
      }
    }
    final lean = bio.massaMagraSegmentar;
    if (lean != null && bio.pesoKg != null) {
      final total = lean.totalKg;
      if (total != null && total > bio.pesoKg! * 0.9) {
        warnings.add('Soma das massas magras segmentares parece alta para o peso informado.');
      }
    }
    if (bio.idade != null && (bio.idade! < 10 || bio.idade! > 100)) {
      warnings.add('Idade fora do esperado (${bio.idade}) — confira na revisão.');
    }
  }

  // ────────────────────────────── texto não lido ──────────────────────────────

  int _historyCut(List<NormalizedLine> lines) {
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].normalized;
      if (line.isEmpty || line.length > 48) continue;
      for (final marker in BioSectionAliases.historyMarkers) {
        if (line == marker || line.startsWith('$marker ') || line.startsWith('$marker:')) {
          return i;
        }
      }
    }
    return lines.length;
  }

  List<String> _unrecognized(
    List<NormalizedLine> lines,
    int cut,
    Set<int> consumedLines,
    Map<int, List<(int, int)>> consumedSpans,
  ) {
    final result = <String>[];
    for (var i = 0; i < cut; i++) {
      final line = lines[i];
      if (line.isBlank) continue;
      final hasNumber = RegExp(r'\d').hasMatch(line.normalized);
      if (!hasNumber) continue;
      final spans = consumedSpans[i] ?? const <(int, int)>[];
      final numbers = RegExp(r'[0-9]+(?:[.,][0-9]+)*').allMatches(line.normalized);
      var unconsumed = false;
      for (final number in numbers) {
        var overlaps = false;
        for (final (s, e) in spans) {
          if (number.start < e && number.end > s) overlaps = true;
        }
        if (!overlaps) unconsumed = true;
      }
      if (unconsumed) result.add(line.original.trim());
      if (result.length >= 40) break;
    }
    return result;
  }
}

class _FieldHit {
  const _FieldHit(this.value, this.raw);

  final double value;
  final String raw;
}
