import 'user_profile.dart';

/// Massas por segmento corporal (braços, tronco e pernas).
///
/// Usado tanto para massa magra segmentar quanto para gordura segmentar.
/// Os valores são sempre os do laudo — o app nunca calcula um segmento.
class SegmentalValues {
  const SegmentalValues({
    this.rightArm,
    this.leftArm,
    this.trunk,
    this.rightLeg,
    this.leftLeg,
    this.rightArmPct,
    this.leftArmPct,
    this.trunkPct,
    this.rightLegPct,
    this.leftLegPct,
  });

  final double? rightArm;
  final double? leftArm;
  final double? trunk;
  final double? rightLeg;
  final double? leftLeg;
  final double? rightArmPct;
  final double? leftArmPct;
  final double? trunkPct;
  final double? rightLegPct;
  final double? leftLegPct;

  bool get isEmpty =>
      rightArm == null &&
      leftArm == null &&
      trunk == null &&
      rightLeg == null &&
      leftLeg == null;

  bool get isNotEmpty => !isEmpty;

  Map<String, dynamic> toJson() => {
        'rightArm': rightArm,
        'leftArm': leftArm,
        'trunk': trunk,
        'rightLeg': rightLeg,
        'leftLeg': leftLeg,
        'rightArmPct': rightArmPct,
        'leftArmPct': leftArmPct,
        'trunkPct': trunkPct,
        'rightLegPct': rightLegPct,
        'leftLegPct': leftLegPct,
      };

  factory SegmentalValues.fromJson(Map<String, dynamic> json) => SegmentalValues(
        rightArm: (json['rightArm'] as num?)?.toDouble(),
        leftArm: (json['leftArm'] as num?)?.toDouble(),
        trunk: (json['trunk'] as num?)?.toDouble(),
        rightLeg: (json['rightLeg'] as num?)?.toDouble(),
        leftLeg: (json['leftLeg'] as num?)?.toDouble(),
        rightArmPct: (json['rightArmPct'] as num?)?.toDouble(),
        leftArmPct: (json['leftArmPct'] as num?)?.toDouble(),
        trunkPct: (json['trunkPct'] as num?)?.toDouble(),
        rightLegPct: (json['rightLegPct'] as num?)?.toDouble(),
        leftLegPct: (json['leftLegPct'] as num?)?.toDouble(),
      );

  SegmentalValues copyWith({
    double? rightArm,
    double? leftArm,
    double? trunk,
    double? rightLeg,
    double? leftLeg,
    double? rightArmPct,
    double? leftArmPct,
    double? trunkPct,
    double? rightLegPct,
    double? leftLegPct,
  }) =>
      SegmentalValues(
        rightArm: rightArm ?? this.rightArm,
        leftArm: leftArm ?? this.leftArm,
        trunk: trunk ?? this.trunk,
        rightLeg: rightLeg ?? this.rightLeg,
        leftLeg: leftLeg ?? this.leftLeg,
        rightArmPct: rightArmPct ?? this.rightArmPct,
        leftArmPct: leftArmPct ?? this.leftArmPct,
        trunkPct: trunkPct ?? this.trunkPct,
        rightLegPct: rightLegPct ?? this.rightLegPct,
        leftLegPct: leftLegPct ?? this.leftLegPct,
      );

  double? get totalKg {
    if (isEmpty) return null;
    return (rightArm ?? 0) +
        (leftArm ?? 0) +
        (trunk ?? 0) +
        (rightLeg ?? 0) +
        (leftLeg ?? 0);
  }
}

/// Resultado de uma bioimpedância (padrão InBody e compatíveis).
///
/// Todos os campos vêm do laudo impresso — nunca calculados pelo app.
class Bioimpedance {
  const Bioimpedance({
    required this.data,
    this.pesoKg,
    this.alturaCm,
    this.idade,
    this.sexo,
    this.imc,
    this.gorduraPct,
    this.gorduraKg,
    this.massaMuscularKg,
    this.massaMuscularEsqueleticaKg,
    this.aguaL,
    this.proteinaKg,
    this.mineraisKg,
    this.tmbKcal,
    this.gorduraVisceral,
    this.grauObesidade,
    this.relacaoCinturaQuadril,
    this.pesoIdealKg,
    this.pontuacao,
    this.massaMagraSegmentar,
    this.gorduraSegmentar,
    this.fonte = 'InBody',
  });

  final DateTime data;
  final double? pesoKg;
  final double? alturaCm;
  final int? idade;
  final Sexo? sexo;
  final double? imc;
  final double? gorduraPct;
  final double? gorduraKg;
  final double? massaMuscularKg;

  /// Massa muscular esquelética (SMM/MME) — diferente da massa muscular total.
  final double? massaMuscularEsqueleticaKg;
  final double? aguaL;
  final double? proteinaKg;
  final double? mineraisKg;
  final double? tmbKcal;
  final int? gorduraVisceral;
  final double? grauObesidade;
  final double? relacaoCinturaQuadril;
  final double? pesoIdealKg;
  final int? pontuacao;

  /// Massa magra por segmento — não é a massa muscular esquelética total.
  final SegmentalValues? massaMagraSegmentar;

  /// Gordura por segmento — não é a massa de gordura total.
  final SegmentalValues? gorduraSegmentar;
  final String fonte;

  Map<String, dynamic> toJson() => {
        'data': data.toIso8601String(),
        'pesoKg': pesoKg,
        'alturaCm': alturaCm,
        'idade': idade,
        'sexo': sexo?.name,
        'imc': imc,
        'gorduraPct': gorduraPct,
        'gorduraKg': gorduraKg,
        'massaMuscularKg': massaMuscularKg,
        'massaMuscularEsqueleticaKg': massaMuscularEsqueleticaKg,
        'aguaL': aguaL,
        'proteinaKg': proteinaKg,
        'mineraisKg': mineraisKg,
        'tmbKcal': tmbKcal,
        'gorduraVisceral': gorduraVisceral,
        'grauObesidade': grauObesidade,
        'relacaoCinturaQuadril': relacaoCinturaQuadril,
        'pesoIdealKg': pesoIdealKg,
        'pontuacao': pontuacao,
        'massaMagraSegmentar': massaMagraSegmentar?.toJson(),
        'gorduraSegmentar': gorduraSegmentar?.toJson(),
        'fonte': fonte,
      };

  factory Bioimpedance.fromJson(Map<String, dynamic> json) {
    final rawDate = json['data'] as String?;
    DateTime? data;
    if (rawDate != null) {
      data = DateTime.tryParse(rawDate);
    }
    final sexo = Sexo.values.where((s) => s.name == json['sexo']).firstOrNull;
    SegmentalValues? segmental(Object? raw) {
      if (raw is! Map) return null;
      return SegmentalValues.fromJson(Map<String, dynamic>.from(raw));
    }

    return Bioimpedance(
      data: data ?? DateTime.now(),
      pesoKg: (json['pesoKg'] as num?)?.toDouble(),
      alturaCm: (json['alturaCm'] as num?)?.toDouble(),
      idade: (json['idade'] as num?)?.toInt(),
      sexo: sexo,
      imc: (json['imc'] as num?)?.toDouble(),
      gorduraPct: (json['gorduraPct'] as num?)?.toDouble(),
      gorduraKg: (json['gorduraKg'] as num?)?.toDouble(),
      massaMuscularKg: (json['massaMuscularKg'] as num?)?.toDouble(),
      massaMuscularEsqueleticaKg: (json['massaMuscularEsqueleticaKg'] as num?)?.toDouble(),
      aguaL: (json['aguaL'] as num?)?.toDouble(),
      proteinaKg: (json['proteinaKg'] as num?)?.toDouble(),
      mineraisKg: (json['mineraisKg'] as num?)?.toDouble(),
      tmbKcal: (json['tmbKcal'] as num?)?.toDouble(),
      gorduraVisceral: (json['gorduraVisceral'] as num?)?.toInt(),
      grauObesidade: (json['grauObesidade'] as num?)?.toDouble(),
      relacaoCinturaQuadril: (json['relacaoCinturaQuadril'] as num?)?.toDouble(),
      pesoIdealKg: (json['pesoIdealKg'] as num?)?.toDouble(),
      pontuacao: (json['pontuacao'] as num?)?.toInt(),
      massaMagraSegmentar: segmental(json['massaMagraSegmentar']),
      gorduraSegmentar: segmental(json['gorduraSegmentar']),
      fonte: json['fonte'] as String? ?? 'InBody',
    );
  }
}
