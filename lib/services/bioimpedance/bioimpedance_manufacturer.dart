/// Identificação do fabricante/modelo do laudo e extensões de vocabulário.
///
/// Cada fabricante é um `BioimpedanceManufacturerProfile`: um conjunto de
/// termos que o identificam e, opcionalmente, aliases extras que só aparecem
/// naquele modelo. Novos fabricantes entram apenas nesta lista.
library;

import 'bioimpedance_aliases.dart';

class BioimpedanceManufacturer {
  const BioimpedanceManufacturer({
    required this.id,
    required this.label,
    this.model,
    this.known = true,
  });

  final String id;
  final String label;
  final String? model;
  final bool known;

  String get displayName => model == null || model!.isEmpty ? label : '$label $model';

  static const BioimpedanceManufacturer unknown = BioimpedanceManufacturer(
    id: 'generico',
    label: 'Laudo de bioimpedância',
    known: false,
  );
}

class BioimpedanceManufacturerProfile {
  const BioimpedanceManufacturerProfile({
    required this.id,
    required this.label,
    required this.patterns,
    this.modelPattern,
    this.extraAliases = const {},
  });

  final String id;
  final String label;

  /// Termos normalizados que identificam o fabricante no texto.
  final List<String> patterns;

  /// Regex aplicada ao texto normalizado para achar o modelo (ex.: InBody 570).
  final String? modelPattern;

  /// Aliases extras por campo, somados ao dicionário base.
  final Map<BioField, List<String>> extraAliases;
}

const List<BioimpedanceManufacturerProfile> bioimpedanceManufacturers = [
  BioimpedanceManufacturerProfile(
    id: 'inbody',
    label: 'InBody',
    patterns: ['inbody', 'in body', 'biospace', 'lookinbody'],
    modelPattern: r'inbody\s*(\d{3}[a-z]?|dial|touch)',
    extraAliases: {
      BioField.inBodyScore: ['pontuacao inbody', 'score inbody', 'pontuacao do exame'],
      BioField.skeletalMuscleMass: ['massa muscular esqueletica mme'],
      BioField.bodyFatPercentage: ['pgc do exame', 'pgc percentual'],
    },
  ),
  BioimpedanceManufacturerProfile(
    id: 'tanita',
    label: 'Tanita',
    patterns: ['tanita', 'inner scan', 'innerscan'],
    modelPattern: r'(?:inner scan|innerscan)\s*([a-z0-9\-]{2,10})',
  ),
  BioimpedanceManufacturerProfile(
    id: 'omron',
    label: 'Omron',
    patterns: ['omron', 'karada scan', 'karadascan'],
  ),
  BioimpedanceManufacturerProfile(
    id: 'seca',
    label: 'seca',
    patterns: ['seca ', 'seca®', 'seca m', 'seca 515', 'seca 514'],
    modelPattern: r'seca\s*(\d{3})',
  ),
  BioimpedanceManufacturerProfile(
    id: 'maltron',
    label: 'Maltron',
    patterns: ['maltron'],
  ),
  BioimpedanceManufacturerProfile(
    id: 'biodynamics',
    label: 'Biodynamics',
    patterns: ['biodynamics', 'biodinamica', 'byodinamics', 'biodynamics 310'],
    modelPattern: r'(?:biodynamics|byodinamics)\s*(\d{3})',
  ),
  BioimpedanceManufacturerProfile(
    id: 'renpho',
    label: 'Renpho',
    patterns: ['renpho'],
  ),
  BioimpedanceManufacturerProfile(
    id: 'withings',
    label: 'Withings',
    patterns: ['withings', 'body comp'],
  ),
  BioimpedanceManufacturerProfile(
    id: 'xiaomi',
    label: 'Xiaomi',
    patterns: ['xiaomi', 'mi body composition', 'mi scale'],
  ),
];

class BioimpedanceManufacturerDetector {
  const BioimpedanceManufacturerDetector();

  List<BioimpedanceManufacturerProfile> get profiles => bioimpedanceManufacturers;

  BioimpedanceManufacturer detect(String normalizedText) {
    for (final profile in profiles) {
      for (final pattern in profile.patterns) {
        if (!normalizedText.contains(pattern)) continue;
        String? model;
        final modelPattern = profile.modelPattern;
        if (modelPattern != null) {
          final match = RegExp(modelPattern).firstMatch(normalizedText);
          model = match?.group(1)?.trim();
        }
        return BioimpedanceManufacturer(
          id: profile.id,
          label: profile.label,
          model: model,
        );
      }
    }
    return BioimpedanceManufacturer.unknown;
  }

  /// Dicionário base somado aos aliases extras do fabricante identificado.
  List<BioFieldSpec> specsFor(BioimpedanceManufacturer manufacturer) {
    BioimpedanceManufacturerProfile? profile;
    for (final candidate in profiles) {
      if (candidate.id == manufacturer.id) profile = candidate;
    }
    if (profile == null || profile.extraAliases.isEmpty) return bioFieldSpecs;

    return [
      for (final spec in bioFieldSpecs)
        if (profile.extraAliases.containsKey(spec.field))
          BioFieldSpec(
            field: spec.field,
            label: spec.label,
            unit: spec.unit,
            integer: spec.integer,
            min: spec.min,
            max: spec.max,
            aliases: [
              ...spec.aliases,
              ...profile.extraAliases[spec.field]!,
            ],
          )
        else
          spec,
    ];
  }
}
