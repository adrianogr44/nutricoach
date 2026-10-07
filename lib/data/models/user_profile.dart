enum Sexo { masculino, feminino }

enum Objetivo { emagrecer, manter, ganharMassa }

enum NivelAtividade { sedentario, leve, moderado, intenso, atleta }

extension NivelAtividadeX on NivelAtividade {
  double get fator {
    switch (this) {
      case NivelAtividade.sedentario:
        return 1.2;
      case NivelAtividade.leve:
        return 1.375;
      case NivelAtividade.moderado:
        return 1.55;
      case NivelAtividade.intenso:
        return 1.725;
      case NivelAtividade.atleta:
        return 1.9;
    }
  }

  String get label {
    switch (this) {
      case NivelAtividade.sedentario:
        return 'Sedentário';
      case NivelAtividade.leve:
        return 'Leve';
      case NivelAtividade.moderado:
        return 'Moderado';
      case NivelAtividade.intenso:
        return 'Intenso';
      case NivelAtividade.atleta:
        return 'Atleta';
    }
  }
}

extension ObjetivoX on Objetivo {
  String get label {
    switch (this) {
      case Objetivo.emagrecer:
        return 'Emagrecer';
      case Objetivo.manter:
        return 'Manter';
      case Objetivo.ganharMassa:
        return 'Ganhar massa';
    }
  }
}

extension SexoX on Sexo {
  String get label => this == Sexo.masculino ? 'Masculino' : 'Feminino';
}

/// Perfil e metas do usuário.
class UserProfile {
  const UserProfile({
    this.name,
    required this.pesoAtualKg,
    required this.pesoDesejadoKg,
    required this.alturaCm,
    required this.idade,
    required this.sexo,
    required this.objetivo,
    required this.nivelAtividade,
    this.metaCalorica,
    this.metaProteina,
    this.metaCarboidrato,
    this.metaGordura,
    this.metaAguaMl,
    this.updatedAt,
    this.photoBase64,
  });

  final String? name;
  final double pesoAtualKg;
  final double pesoDesejadoKg;
  final double alturaCm;
  final int idade;
  final Sexo sexo;
  final Objetivo objetivo;
  final NivelAtividade nivelAtividade;

  /// Foto de perfil do usuário (opcional) em base64 (data URI ou puro).
  final String? photoBase64;

  /// Metas calculadas (podem ser ajustadas manualmente).
  final double? metaCalorica;
  final double? metaProteina;
  final double? metaCarboidrato;
  final double? metaGordura;
  final double? metaAguaMl;
  final DateTime? updatedAt;

  UserProfile copyWith({
    String? name,
    double? pesoAtualKg,
    double? pesoDesejadoKg,
    double? alturaCm,
    int? idade,
    Sexo? sexo,
    Objetivo? objetivo,
    NivelAtividade? nivelAtividade,
    double? metaCalorica,
    double? metaProteina,
    double? metaCarboidrato,
    double? metaGordura,
    double? metaAguaMl,
    String? photoBase64,
  }) {
    return UserProfile(
      name: name ?? this.name,
      pesoAtualKg: pesoAtualKg ?? this.pesoAtualKg,
      pesoDesejadoKg: pesoDesejadoKg ?? this.pesoDesejadoKg,
      alturaCm: alturaCm ?? this.alturaCm,
      idade: idade ?? this.idade,
      sexo: sexo ?? this.sexo,
      objetivo: objetivo ?? this.objetivo,
      nivelAtividade: nivelAtividade ?? this.nivelAtividade,
      metaCalorica: metaCalorica ?? this.metaCalorica,
      metaProteina: metaProteina ?? this.metaProteina,
      metaCarboidrato: metaCarboidrato ?? this.metaCarboidrato,
      metaGordura: metaGordura ?? this.metaGordura,
      metaAguaMl: metaAguaMl ?? this.metaAguaMl,
      updatedAt: DateTime.now(),
      photoBase64: photoBase64 ?? this.photoBase64,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'pesoAtualKg': pesoAtualKg,
        'pesoDesejadoKg': pesoDesejadoKg,
        'alturaCm': alturaCm,
        'idade': idade,
        'sexo': sexo.name,
        'objetivo': objetivo.name,
        'nivelAtividade': nivelAtividade.name,
        'metaCalorica': metaCalorica,
        'metaProteina': metaProteina,
        'metaCarboidrato': metaCarboidrato,
        'metaGordura': metaGordura,
        'metaAguaMl': metaAguaMl,
        'updatedAt': updatedAt?.toIso8601String(),
        'photoBase64': photoBase64,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] as String?,
        pesoAtualKg: (json['pesoAtualKg'] as num?)?.toDouble() ?? 70,
        pesoDesejadoKg: (json['pesoDesejadoKg'] as num?)?.toDouble() ?? 65,
        alturaCm: (json['alturaCm'] as num?)?.toDouble() ?? 170,
        idade: (json['idade'] as num?)?.toInt() ?? 30,
        sexo: Sexo.values.firstWhere(
          (s) => s.name == json['sexo'],
          orElse: () => Sexo.masculino,
        ),
        objetivo: Objetivo.values.firstWhere(
          (o) => o.name == json['objetivo'],
          orElse: () => Objetivo.emagrecer,
        ),
        nivelAtividade: NivelAtividade.values.firstWhere(
          (n) => n.name == json['nivelAtividade'],
          orElse: () => NivelAtividade.moderado,
        ),
        metaCalorica: (json['metaCalorica'] as num?)?.toDouble(),
        metaProteina: (json['metaProteina'] as num?)?.toDouble(),
        metaCarboidrato: (json['metaCarboidrato'] as num?)?.toDouble(),
        metaGordura: (json['metaGordura'] as num?)?.toDouble(),
        metaAguaMl: (json['metaAguaMl'] as num?)?.toDouble(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
        photoBase64: json['photoBase64'] as String?,
      );
}