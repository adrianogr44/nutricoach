/// Constantes globais do app.
library;

class AppConstants {
  AppConstants._();

  static const double kcalPerGramProtein = 4.0;
  static const double kcalPerGramCarbs = 4.0;
  static const double kcalPerGramFat = 9.0;
  static const double kcalPerGramAlcohol = 7.0;

  /// Fóntes nutricionais utilizadas como base de dados.
  static const String foodDbSource = 'TACO 4ª ed. + TBCA 2023';

  static const String openFoodFactsBase =
      'https://world.openfoodfacts.org/api/v3';
}

enum DayStatus { deficit, maintenance, surplus }

extension DayStatusX on DayStatus {
  String get label {
    switch (this) {
      case DayStatus.deficit:
        return 'Déficit';
      case DayStatus.maintenance:
        return 'Manutenção';
      case DayStatus.surplus:
        return 'Superávit';
    }
  }

  String get emoji {
    switch (this) {
      case DayStatus.deficit:
        return '🟢';
      case DayStatus.maintenance:
        return '🟡';
      case DayStatus.surplus:
        return '🔴';
    }
  }
}