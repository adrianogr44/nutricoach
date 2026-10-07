import 'user_profile.dart';

/// Resultado de uma bioimpedância (padrão InBody).
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
    this.aguaL,
    this.proteinaKg,
    this.mineraisKg,
    this.tmbKcal,
    this.gorduraVisceral,
    this.relacaoCinturaQuadril,
    this.pesoIdealKg,
    this.pontuacao,
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
  final double? aguaL;
  final double? proteinaKg;
  final double? mineraisKg;
  final double? tmbKcal;
  final int? gorduraVisceral;
  final double? relacaoCinturaQuadril;
  final double? pesoIdealKg;
  final int? pontuacao;
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
        'aguaL': aguaL,
        'proteinaKg': proteinaKg,
        'mineraisKg': mineraisKg,
        'tmbKcal': tmbKcal,
        'gorduraVisceral': gorduraVisceral,
        'relacaoCinturaQuadril': relacaoCinturaQuadril,
        'pesoIdealKg': pesoIdealKg,
        'pontuacao': pontuacao,
        'fonte': fonte,
      };

  factory Bioimpedance.fromJson(Map<String, dynamic> json) {
    final rawDate = json['data'] as String?;
    DateTime? data;
    if (rawDate != null) {
      data = DateTime.tryParse(rawDate);
    }
    final sexo = Sexo.values.where((s) => s.name == json['sexo']).firstOrNull;
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
      aguaL: (json['aguaL'] as num?)?.toDouble(),
      proteinaKg: (json['proteinaKg'] as num?)?.toDouble(),
      mineraisKg: (json['mineraisKg'] as num?)?.toDouble(),
      tmbKcal: (json['tmbKcal'] as num?)?.toDouble(),
      gorduraVisceral: (json['gorduraVisceral'] as num?)?.toInt(),
      relacaoCinturaQuadril: (json['relacaoCinturaQuadril'] as num?)?.toDouble(),
      pesoIdealKg: (json['pesoIdealKg'] as num?)?.toDouble(),
      pontuacao: (json['pontuacao'] as num?)?.toInt(),
      fonte: json['fonte'] as String? ?? 'InBody',
    );
  }
}