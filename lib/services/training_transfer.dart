import 'dart:convert';

import '../data/models/training.dart';

/// Exportação/importação do treino (ficha) em JSON.
///
/// O app é offline-first (SharedPreferences local) e a nuvem não está
/// configurada, então os dados não migram sozinhos entre dispositivos.
/// Este formato é a ponte: exporta em um aparelho e importa em outro,
/// sem rede. Só a ficha vai no arquivo — o histórico de sessões fica
/// no aparelho de origem, igual à dieta.
class TrainingTransfer {
  const TrainingTransfer._();

  static const format = 'nutricoach-treino';
  static const version = 1;
  static const fileName = 'nutricoach-treino.json';

  /// Serializa o plano com envelope de formato/versão para validação no import.
  static String export(TrainingPlan plan) {
    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'plan': plan.toJson(),
    });
  }

  /// Lê o JSON exportado. Lança [FormatException] com mensagem amigável
  /// (pt-BR) quando o conteúdo não for um treino válido.
  static TrainingPlan decode(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      throw const FormatException('Cole o JSON do treino ou escolha um arquivo exportado.');
    }

    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const FormatException('O conteúdo não é um JSON válido.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('O arquivo não tem a estrutura de um treino exportado.');
    }
    if (decoded['format'] != format) {
      throw const FormatException('Este arquivo não é um treino exportado do NutriCoach.');
    }
    final fileVersion = decoded['version'];
    if (fileVersion is! int || fileVersion < 1 || fileVersion > version) {
      throw const FormatException('Versão do arquivo não suportada por esta versão do app.');
    }

    final planValue = decoded['plan'];
    if (planValue is! Map<String, dynamic>) {
      throw const FormatException('O arquivo não contém nenhuma ficha de treino.');
    }
    final plan = TrainingPlan.fromJson(planValue);
    if (plan.days.isEmpty) {
      throw const FormatException('A ficha importada não possui nenhum dia de treino.');
    }
    return plan;
  }
}
