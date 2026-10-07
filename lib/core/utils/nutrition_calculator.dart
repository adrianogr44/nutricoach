import 'dart:math' as math;

import '../../data/models/user_profile.dart';

/// Cálculos de TMB, TDEE e metas calóricas/nutricionais.
/// Fórmulas base: Mifflin-St Jeor (TMB) e fator de atividade.
class NutritionCalculator {
  NutritionCalculator._();

  /// Taxa Metabólica Basal (kcal/dia) — Mifflin-St Jeor.
  static double tmb({required double pesoKg, required double alturaCm, required int idade, required Sexo sexo}) {
    final base = (10 * pesoKg) + (6.25 * alturaCm) - (5 * idade);
    return sexo == Sexo.masculino ? base + 5 : base - 161;
  }

  /// Gasto Energético Total Diário.
  static double tdee({required double tmb, required NivelAtividade nivel}) {
    return tmb * nivel.fator;
  }

  /// Meta calórica conforme objetivo.
  static double metaCalorica({required double tdee, required Objetivo objetivo}) {
    switch (objetivo) {
      case Objetivo.emagrecer:
        return tdee - 500; // déficit de ~500 kcal/dia (~0,5 kg/semana)
      case Objetivo.ganharMassa:
        return tdee + 300; // superávit moderado
      case Objetivo.manter:
        return tdee;
    }
  }

  /// Meta de proteínas (g) — 2,0 g/kg para ganho/deficit, 1,6 g/kg manutenção.
  static double metaProteina({required double pesoKg, required Objetivo objetivo}) {
    return pesoKg * (objetivo == Objetivo.manter ? 1.6 : 2.0);
  }

  /// Distribuição de macros (% das calorias).
  static ({double proteina, double carboidrato, double gordura}) macroSplit(Objetivo objetivo) {
    switch (objetivo) {
      case Objetivo.emagrecer:
        return (proteina: 0.30, carboidrato: 0.35, gordura: 0.35);
      case Objetivo.ganharMassa:
        return (proteina: 0.25, carboidrato: 0.50, gordura: 0.25);
      case Objetivo.manter:
        return (proteina: 0.25, carboidrato: 0.45, gordura: 0.30);
    }
  }

  static double metaGordura({required double metaKcal, required Objetivo objetivo}) {
    return (metaKcal * macroSplit(objetivo).gordura) / 9;
  }

  static double metaCarboidrato({required double metaKcal, required Objetivo objetivo}) {
    return (metaKcal * macroSplit(objetivo).carboidrato) / 4;
  }

  /// Meta de água (ml) — ~35 ml/kg.
  static double metaAgua({required double pesoKg}) => pesoKg * 35;

  /// IMC.
  static double imc({required double pesoKg, required double alturaCm}) {
    final h = alturaCm / 100;
    return pesoKg / (h * h);
  }

  /// IMC ideal para a meta de peso (kg) dados os limites saudáveis 18,5-24,9.
  static double pesoIdeal({required double alturaCm}) {
    final h = alturaCm / 100;
    final minimo = 18.5 * h * h;
    final maximo = 24.9 * h * h;
    return (minimo + maximo) / 2;
  }

  /// Peso previsto após [dias] em déficit de [deficitKcal]/dia (~7700 kcal/kg).
  static double pesoEstimado({required double pesoAtual, required double deficitKcalPorDia, required int dias}) {
    final lostKg = (deficitKcalPorDia * dias) / 7700;
    return math.max(0, pesoAtual - lostKg);
  }
}