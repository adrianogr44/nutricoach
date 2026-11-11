import 'dart:convert';

import '../../data/models/bioimpedance.dart';
import '../../data/models/user_profile.dart';
import 'bioimpedance_aliases.dart';
import 'bioimpedance_exception.dart';
import 'bioimpedance_extractor.dart';
import 'bioimpedance_manufacturer.dart';
import 'bioimpedance_text_normalizer.dart';
import 'bioimpedance_validator.dart';

/// Importa uma bioimpedância a partir de JSON.
///
/// Aceita o JSON exportado pelo próprio app (`Bioimpedance.toJson()`), nomes
/// canônicos do extrator (`weight`, `bmi`, `bodyFatPercentage`…) e variações em
/// português com ou sem acento, em camelCase ou snake_case. Chaves
/// desconhecidas não são descartadas: ficam preservadas para a revisão.
class BioimpedanceJsonParser {
  const BioimpedanceJsonParser();

  static const BioimpedanceTextNormalizer _normalizer = BioimpedanceTextNormalizer();
  static const BioimpedanceManufacturerDetector _detector = BioimpedanceManufacturerDetector();

  /// Chaves já normalizadas (minúsculas, sem acento e sem separadores).
  static const Map<BioField, List<String>> _keysByField = {
    BioField.weight: ['pesokg', 'peso', 'weightkg', 'weight', 'massacorporal', 'pesocorporal'],
    BioField.height: ['alturacm', 'altura', 'estatura', 'heightcm', 'height'],
    BioField.age: ['idade', 'age'],
    BioField.bmi: ['imc', 'bmi', 'imckgm2', 'indicedemassacorporal'],
    BioField.bodyFatPercentage: [
      'gorduratpct',
      'gordurapct',
      'percentualdegordura',
      'percentualdegorduracorporal',
      'bodyfatpercentage',
      'pgc',
      'bfp',
      'pbf',
    ],
    BioField.fatMass: ['gorduratkg', 'gordurakg', 'massadegordura', 'massagorda', 'fatmass'],
    BioField.skeletalMuscleMass: [
      'massamuscularesqueleticakg',
      'massamuscularesqueletica',
      'skeletalmusclemass',
      'smm',
      'mme',
    ],
    BioField.muscleMass: [
      'massamuscularkg',
      'massamuscular',
      'massamusculartotal',
      'musclemass',
    ],
    BioField.totalBodyWater: [
      'aguacorporaltotal',
      'aguacorporal',
      'agual',
      'agua',
      'totalbodywater',
      'tbw',
      'act',
    ],
    BioField.proteinMass: ['proteinakg', 'proteina', 'proteinmass', 'massaproteica'],
    BioField.mineralMass: ['mineraiskg', 'minerais', 'mineralmass', 'massamineral'],
    BioField.basalMetabolicRate: [
      'tmbkcal',
      'tmb',
      'taxametabolicabasal',
      'basalmetabolicrate',
      'bmr',
      'metabolismobasal',
    ],
    BioField.waistHipRatio: ['relacaocinturaquadril', 'waisthipratio', 'rcq', 'whr'],
    BioField.visceralFatLevel: [
      'gorduravisceral',
      'niveldegorduravisceral',
      'visceralfatlevel',
      'vfl',
    ],
    BioField.obesityDegree: ['graudeobesidade', 'grauobesidade', 'graudeobesidadepct', 'obesitydegree'],
    BioField.inBodyScore: ['pontuacao', 'pontuacaoinbody', 'inbodyscore', 'score', 'scoreinbody'],
    BioField.idealWeight: ['pesoideal', 'pesoidealkg', 'idealweight'],
  };

  static final Map<String, BioField> _fieldByKey = {
    for (final entry in _keysByField.entries)
      for (final key in entry.value) key: entry.key,
  };

  static final Map<BioField, BioFieldSpec> _specByField = {
    for (final spec in bioFieldSpecs) spec.field: spec,
  };

  static const List<String> _dateKeys = [
    'data',
    'date',
    'datadaavaliacao',
    'datadoexame',
    'avaliacao',
    'examdate',
    'measuredat',
    'measuredate',
    'datadamedicao',
  ];

  static const List<String> _sexKeys = ['sexo', 'sex', 'genero', 'gender'];
  static const List<String> _sourceKeys = [
    'fonte',
    'source',
    'fabricante',
    'manufacturer',
    'aparelho',
    'device',
    'modelo',
    'model',
  ];

  static const List<String> _leanPrefixes = [
    'massamagrasegmentar',
    'massamagrasegmentada',
    'segmentallean',
    'leansegment',
    'massamuscularsegmentar',
  ];

  static const List<String> _fatPrefixes = [
    'gorduracorporalsegmentar',
    'gordurasegmentar',
    'segmentalfat',
    'fatsegmental',
    'gorduradasegmentar',
  ];

  static const Map<String, List<String>> _segmentAliases = {
    'rightArm': ['bracodireito', 'bracodir', 'rightarm', 'armright'],
    'leftArm': ['bracoesquerdo', 'bracoesq', 'leftarm', 'armleft'],
    'trunk': ['tronco', 'trunk', 'torax'],
    'rightLeg': ['pernadireita', 'pernadir', 'rightleg', 'legright'],
    'leftLeg': ['pernaesquerda', 'pernaesq', 'leftleg', 'legleft'],
  };

  BioimpedanceParseResult parse(String rawJson) {
    final raw = rawJson.trim();
    if (raw.isEmpty) {
      throw const LocalParseException(
        'O JSON está vazio. Cole o objeto com os dados da bioimpedância.',
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw LocalParseException('JSON inválido: ${e.message}');
    }

    final root = _unwrap(decoded);
    if (root == null) {
      throw const LocalParseException(
        'O JSON precisa ser um objeto com os campos, por exemplo: '
        '{"data": "2026-09-03", "pesoKg": 121.2, "imc": 35.4}.',
      );
    }

    final values = <BioField, double>{};
    final rawValues = <BioField, String>{};
    final unknown = <String>[];
    final leanKg = <String, double>{};
    final leanPct = <String, double>{};
    final fatKg = <String, double>{};
    final fatPct = <String, double>{};
    DateTime? date;
    Sexo? sexo;
    String? fonte;

    void visit(Object? node, String path, String? section) {
      if (node is! Map) return;
      node.forEach((key, value) {
        final rawKey = key.toString();
        final normalized = _normalizeKey(rawKey);
        final childPath = path.isEmpty ? rawKey : '$path.$rawKey';

        if (value is Map) {
          visit(value, childPath, _sectionFor(normalized) ?? section);
          return;
        }
        if (value is List) {
          unknown.add('$childPath: ${jsonEncode(value)}');
          return;
        }
        if (value == null) return;

        // Seções segmentares, planas ou aninhadas.
        final effectiveSection = _sectionFor(normalized) ?? section;
        if (effectiveSection != null) {
          final segment = _segmentFor(normalized);
          if (segment != null) {
            final number = _number(value, null);
            if (number == null) return;
            final target = _isPercentKey(normalized)
                ? (effectiveSection == 'lean' ? leanPct : fatPct)
                : (effectiveSection == 'lean' ? leanKg : fatKg);
            target[segment] = number;
            return;
          }
        }

        final field = _fieldByKey[normalized];
        if (field == null) {
          if (_dateKeys.contains(normalized)) {
            date = _date(value) ?? date;
            return;
          }
          if (_sexKeys.contains(normalized)) {
            sexo = _sex(value) ?? sexo;
            return;
          }
          if (_sourceKeys.contains(normalized) && value is String && value.trim().isNotEmpty) {
            fonte = value.trim();
            return;
          }
          unknown.add('$childPath: ${_plain(value)}');
          return;
        }

        final spec = _specByField[field];
        final number = _number(value, spec);
        if (number == null) {
          unknown.add('$childPath: ${_plain(value)}');
          return;
        }
        values[field] = number;
        rawValues[field] = '$childPath: ${_plain(value)}';
      });
    }

    visit(root, '', null);

    final lean = _segmental(leanKg, leanPct);
    final fat = _segmental(fatKg, fatPct);
    final warnings = <String>[];

    final manufacturer = _manufacturerFor(fonte);
    final bio = Bioimpedance(
      data: date ?? DateTime.now(),
      pesoKg: values[BioField.weight],
      alturaCm: values[BioField.height],
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
      fonte: fonte ?? manufacturer.displayName,
    );

    if (date == null) {
      warnings.add('Data da avaliação não encontrada — usando a data de hoje.');
    }
    BioimpedanceValidator.validate(bio, warnings);

    if (values.isEmpty && lean == null && fat == null) {
      throw const LocalParseException(
        'Nenhum campo conhecido foi encontrado no JSON. Use nomes como '
        'pesoKg, imc, gorduraPct, massaMuscularEsqueleticaKg ou '
        'massaMagraSegmentar.',
      );
    }

    return BioimpedanceParseResult(
      bioimpedance: bio,
      manufacturer: manufacturer,
      values: values,
      rawValues: rawValues,
      unrecognizedLines: unknown.take(40).toList(),
      warnings: warnings,
      rawText: raw,
    );
  }

  // ─────────────────────────────── utilitários ───────────────────────────────

  Map? _unwrap(Object? decoded) {
    if (decoded is List) {
      if (decoded.length == 1 && decoded.first is Map) return decoded.first as Map;
      return null;
    }
    if (decoded is! Map) return null;

    for (final wrapper in const ['bioimpedancia', 'bioimpedance', 'resultado', 'laudo']) {
      for (final entry in decoded.entries) {
        if (_normalizeKey(entry.key.toString()) == wrapper && entry.value is Map) {
          return entry.value as Map;
        }
      }
    }
    return decoded;
  }

  String _normalizeKey(String key) {
    final normalized = _normalizer.normalize(key);
    return normalized.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String? _sectionFor(String key) {
    if (key == 'lean' || key == 'massamagra') return 'lean';
    if (key == 'fat' || key == 'gordura') return 'fat';
    for (final prefix in _leanPrefixes) {
      if (key.contains(prefix)) return 'lean';
    }
    for (final prefix in _fatPrefixes) {
      if (key.contains(prefix)) return 'fat';
    }
    return null;
  }

  String? _segmentFor(String key) {
    for (final entry in _segmentAliases.entries) {
      for (final alias in entry.value) {
        if (key.contains(alias)) return entry.key;
      }
    }
    return null;
  }

  bool _isPercentKey(String key) =>
      key.contains('pct') ||
      key.contains('percent') ||
      key.contains('percentual') ||
      key.contains('porcentagem');

  double? _number(Object? value, BioFieldSpec? spec) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = _normalizer.parseNumber(value, min: spec?.min, max: spec?.max);
      return parsed;
    }
    return null;
  }

  SegmentalValues? _segmental(Map<String, double> kg, Map<String, double> pct) {
    if (kg.isEmpty && pct.isEmpty) return null;
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

  String _plain(Object? value) {
    if (value is String) return value;
    if (value is num || value is bool) return '$value';
    return jsonEncode(value);
  }

  DateTime? _date(Object? value) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      final iso = DateTime.tryParse(trimmed);
      if (iso != null) return DateTime(iso.year, iso.month, iso.day);
      final match = RegExp(r'(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2,4})').firstMatch(trimmed);
      if (match != null) {
        final day = int.parse(match.group(1)!);
        final month = int.parse(match.group(2)!);
        var year = int.parse(match.group(3)!);
        if (year < 100) year += 2000;
        final date = DateTime(year, month, day);
        if (date.day == day && date.month == month) return date;
      }
    }
    if (value is int) {
      final millis = value > 100000000000 ? value : value * 1000;
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }
    return null;
  }

  Sexo? _sex(Object? value) {
    if (value is! String) return null;
    final normalized = _normalizer.normalize(value);
    if (normalized.startsWith('f') || normalized.contains('fem')) return Sexo.feminino;
    if (normalized.startsWith('m') || normalized.contains('masc')) return Sexo.masculino;
    return null;
  }

  BioimpedanceManufacturer _manufacturerFor(String? fonte) {
    if (fonte == null || fonte.isEmpty) return BioimpedanceManufacturer.unknown;
    final detected = _detector.detect(_normalizer.normalize(fonte));
    if (detected.known) return detected;
    return BioimpedanceManufacturer(id: 'json', label: fonte, known: false);
  }
}
