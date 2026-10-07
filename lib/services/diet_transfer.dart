import 'dart:convert';

import '../data/models/diet.dart';

/// Exportação/importação da dieta em JSON.
///
/// O app é offline-first (SharedPreferences local) e a nuvem não está
/// configurada, então os dados não migram sozinhos entre dispositivos.
/// Este formato é a ponte: exporta em um navegador/dispositivo e importa
/// em outro, sem rede e sem inventar nenhum valor.
class DietTransfer {
  const DietTransfer._();

  static const format = 'nutricoach-dieta';
  static const version = 1;
  static const fileName = 'nutricoach-dieta.json';

  /// Serializa o plano com envelope de formato/versão para validação no import.
  static String export(DietPlan plan) {
    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'diet': plan.toJson(),
    });
  }

  /// Lê o JSON exportado. Lança [FormatException] com mensagem amigável
  /// (pt-BR) quando o conteúdo não for uma dieta válida.
  static DietPlan decode(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      throw const FormatException('Cole o JSON da dieta ou escolha um arquivo exportado.');
    }

    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const FormatException('O conteúdo não é um JSON válido.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('O arquivo não tem a estrutura de uma dieta exportada.');
    }
    if (decoded['format'] != format) {
      throw const FormatException('Este arquivo não é uma dieta exportada do NutriCoach.');
    }
    final fileVersion = decoded['version'];
    if (fileVersion is! int || fileVersion < 1 || fileVersion > version) {
      throw const FormatException('Versão do arquivo não suportada por esta versão do app.');
    }

    final dietValue = decoded['diet'];
    if (dietValue is! Map<String, dynamic>) {
      throw const FormatException('O arquivo não contém nenhuma dieta.');
    }
    final plan = DietPlan.fromJson(dietValue);
    if (plan.meals.isEmpty) {
      throw const FormatException('A dieta importada não possui nenhuma refeição.');
    }
    return plan;
  }
}
