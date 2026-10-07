import '../data/models/food.dart';

enum MeasureUnit {
  g,
  kg,
  ml,
  l,
  unidade,
  fatia,
  colherCha,
  colherSopa,
  concha,
  xicara,
  copo,
  porcao,
  pegador,
}

extension MeasureUnitX on MeasureUnit {
  String get label {
    switch (this) {
      case MeasureUnit.g:
        return 'g';
      case MeasureUnit.kg:
        return 'kg';
      case MeasureUnit.ml:
        return 'ml';
      case MeasureUnit.l:
        return 'litro';
      case MeasureUnit.unidade:
        return 'unidade';
      case MeasureUnit.fatia:
        return 'fatia';
      case MeasureUnit.colherCha:
        return 'colher de chá';
      case MeasureUnit.colherSopa:
        return 'colher de sopa';
      case MeasureUnit.concha:
        return 'concha';
      case MeasureUnit.xicara:
        return 'xícara';
      case MeasureUnit.copo:
        return 'copo';
      case MeasureUnit.porcao:
        return 'porção';
      case MeasureUnit.pegador:
        return 'pegador';
    }
  }

  String get shortLabel {
    switch (this) {
      case MeasureUnit.colherCha:
        return 'col. chá';
      case MeasureUnit.colherSopa:
        return 'col. sopa';
      default:
        return label;
    }
  }

  bool get isWeight => this == MeasureUnit.g || this == MeasureUnit.kg || this == MeasureUnit.colherCha || this == MeasureUnit.colherSopa || this == MeasureUnit.concha || this == MeasureUnit.xicara || this == MeasureUnit.copo || this == MeasureUnit.fatia || this == MeasureUnit.unidade || this == MeasureUnit.porcao || this == MeasureUnit.pegador;
  bool get isVolume => this == MeasureUnit.ml || this == MeasureUnit.l || this == MeasureUnit.copo || this == MeasureUnit.xicara;

  static MeasureUnit fromString(String s) {
    switch (s) {
      case 'g':
        return MeasureUnit.g;
      case 'kg':
        return MeasureUnit.kg;
      case 'ml':
        return MeasureUnit.ml;
      case 'l':
      case 'litro':
        return MeasureUnit.l;
      case 'unidade':
      case 'un':
        return MeasureUnit.unidade;
      case 'fatia':
        return MeasureUnit.fatia;
      case 'colher_cha':
      case 'colherCha':
      case 'cha':
        return MeasureUnit.colherCha;
      case 'colher_sopa':
      case 'colherSopa':
      case 'sopa':
        return MeasureUnit.colherSopa;
      case 'concha':
        return MeasureUnit.concha;
      case 'xicara':
      case 'xícara':
        return MeasureUnit.xicara;
      case 'copo':
        return MeasureUnit.copo;
      case 'porcao':
      case 'porção':
        return MeasureUnit.porcao;
      case 'pegador':
        return MeasureUnit.pegador;
      default:
        return MeasureUnit.g;
    }
  }
}

/// Conversor de medidas caseiras para gramas/ml, dependente do alimento.
class HouseholdMeasureConverter {
  const HouseholdMeasureConverter();

  /// Tabela por alimento (id) -> unidade -> gramas (ou ml para líquidos).
  /// Valores baseados em porções usuais TACO e medidas caseiras brasileiras.
  static const Map<String, Map<MeasureUnit, double>> _perFoodGrams = {
    // Cereais
    'arroz-branco': {
      MeasureUnit.colherSopa: 15,
      MeasureUnit.concha: 45,
      MeasureUnit.xicara: 100,
      MeasureUnit.copo: 150,
      MeasureUnit.porcao: 150,
      MeasureUnit.pegador: 60,
    },
    'arroz-integral': {
      MeasureUnit.colherSopa: 15,
      MeasureUnit.concha: 45,
      MeasureUnit.xicara: 100,
      MeasureUnit.porcao: 150,
    },
    'feijao-carioca': {
      MeasureUnit.colherSopa: 15,
      MeasureUnit.concha: 90,
      MeasureUnit.xicara: 130,
      MeasureUnit.copo: 170,
      MeasureUnit.porcao: 130,
      MeasureUnit.pegador: 45,
    },
    'feijao-preto': {
      MeasureUnit.colherSopa: 15,
      MeasureUnit.concha: 90,
      MeasureUnit.xicara: 130,
      MeasureUnit.porcao: 130,
    },
    'ovo': {
      MeasureUnit.unidade: 50,
      MeasureUnit.fatia: 50,
      MeasureUnit.porcao: 50,
    },
    'ovo-frito': {
      MeasureUnit.unidade: 50,
    },
    'ovo-mexido': {
      MeasureUnit.colherSopa: 20,
      MeasureUnit.porcao: 60,
      MeasureUnit.unidade: 50,
    },
    'pao-forma': {
      MeasureUnit.fatia: 25,
      MeasureUnit.unidade: 25,
      MeasureUnit.porcao: 50,
    },
    'pao-frances': {
      MeasureUnit.unidade: 50,
      MeasureUnit.fatia: 25,
      MeasureUnit.porcao: 50,
    },
    'leite-integral': {
      MeasureUnit.xicara: 200,
      MeasureUnit.copo: 200,
      MeasureUnit.ml: 1,
      MeasureUnit.l: 1000,
      MeasureUnit.colherSopa: 15,
    },
    'leite-desnatado': {
      MeasureUnit.xicara: 200,
      MeasureUnit.copo: 200,
    },
    'banana': {
      MeasureUnit.unidade: 100,
      MeasureUnit.fatia: 20,
      MeasureUnit.porcao: 100,
    },
    'maca': {
      MeasureUnit.unidade: 130,
      MeasureUnit.fatia: 20,
    },
    'peito-frango': {
      MeasureUnit.fatia: 40,
      MeasureUnit.porcao: 120,
      MeasureUnit.pegador: 60,
      MeasureUnit.unidade: 120,
    },
    'patinho': {
      MeasureUnit.colherSopa: 20,
      MeasureUnit.porcao: 100,
      MeasureUnit.pegador: 50,
    },
    'queijo-minas': {
      MeasureUnit.fatia: 30,
      MeasureUnit.porcao: 30,
      MeasureUnit.unidade: 30,
    },
    'mussarela': {
      MeasureUnit.fatia: 30,
      MeasureUnit.porcao: 30,
    },
  };

  static const Map<MeasureUnit, double> _genericWeightGrams = {
    MeasureUnit.colherCha: 5,
    MeasureUnit.colherSopa: 15,
    MeasureUnit.concha: 100,
    MeasureUnit.xicara: 120,
    MeasureUnit.copo: 200,
    MeasureUnit.fatia: 30,
    MeasureUnit.unidade: 100,
    MeasureUnit.porcao: 100,
    MeasureUnit.pegador: 60,
  };

  /// Converte [quantity] na [unit] para gramas (ou ml para líquidos).
  double toGrams(Food food, double quantity, MeasureUnit unit, {double? customGramsPerUnit}) {
    if (customGramsPerUnit != null && customGramsPerUnit > 0) {
      return quantity * customGramsPerUnit;
    }
    switch (unit) {
      case MeasureUnit.g:
        return quantity;
      case MeasureUnit.kg:
        return quantity * 1000;
      case MeasureUnit.ml:
        return quantity;
      case MeasureUnit.l:
        return quantity * 1000;
      default:
        // Tenta per-food
        final perFood = _perFoodGrams[food.id];
        if (perFood != null && perFood.containsKey(unit)) {
          return quantity * perFood[unit]!;
        }
        // Para líquidos, xícara/copo em ml
        if (food.category == 'Bebidas' || food.category == 'Leite e derivados') {
          if (unit == MeasureUnit.xicara || unit == MeasureUnit.copo) return quantity * 200;
          if (unit == MeasureUnit.colherSopa) return quantity * 15;
          if (unit == MeasureUnit.colherCha) return quantity * 5;
        }
        // Fallback: usa standardPortion ou genérico
        if (unit == MeasureUnit.unidade || unit == MeasureUnit.porcao || unit == MeasureUnit.fatia) {
          return quantity * food.standardPortionGrams;
        }
        final generic = _genericWeightGrams[unit];
        if (generic != null) return quantity * generic;
        return quantity * food.standardPortionGrams;
    }
  }

  String displayFor(Food food, double quantity, MeasureUnit unit, {double? customGramsPerUnit}) {
    final grams = toGrams(food, quantity, unit, customGramsPerUnit: customGramsPerUnit);
    final qStr = quantity == quantity.roundToDouble() ? quantity.toStringAsFixed(0) : quantity.toStringAsFixed(1).replaceAll('.', ',');
    final unitLabel = unit == MeasureUnit.g || unit == MeasureUnit.ml ? unit.label : unit.label;
    // singular/plural simples
    final qtyLabel = quantity == 1 ? unitLabel : _plural(unitLabel);
    if (unit == MeasureUnit.g || unit == MeasureUnit.ml || unit == MeasureUnit.kg || unit == MeasureUnit.l) {
      return '$qStr $qtyLabel';
    }
    return '$qStr $qtyLabel · aprox. ${grams.round()} g';
  }

  String _plural(String s) {
    if (s == 'concha') return 'conchas';
    if (s == 'xícara') return 'xícaras';
    if (s == 'colher de chá') return 'colheres de chá';
    if (s == 'colher de sopa') return 'colheres de sopa';
    if (s == 'fatia') return 'fatias';
    if (s == 'copo') return 'copos';
    if (s == 'porção') return 'porções';
    if (s == 'unidade') return 'unidades';
    if (s == 'pegador') return 'pegadores';
    return s;
  }

  List<MeasureUnit> availableFor(Food food) {
    // Sempre oferece peso/volume básicos + caseiras relevantes
    final base = [MeasureUnit.g, MeasureUnit.kg, MeasureUnit.ml, MeasureUnit.l];
    final household = [MeasureUnit.unidade, MeasureUnit.fatia, MeasureUnit.colherCha, MeasureUnit.colherSopa, MeasureUnit.concha, MeasureUnit.xicara, MeasureUnit.copo, MeasureUnit.porcao, MeasureUnit.pegador];
    // Filtra: para líquidos, remove fatia/pegador pesados etc? mantém simples, oferece todas.
    return [...base, ...household];
  }
}
