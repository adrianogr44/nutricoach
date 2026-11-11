import '../../data/models/bioimpedance.dart';

/// Verificações de coerência aplicadas a qualquer origem de bioimpedância
/// (PDF, OCR, texto colado ou JSON).
///
/// Nunca descarta valores: só acrescenta avisos para a revisão humana.
class BioimpedanceValidator {
  const BioimpedanceValidator._();

  static void validate(Bioimpedance bio, List<String> warnings) {
    if (bio.gorduraKg != null && bio.pesoKg != null && bio.gorduraKg! > bio.pesoKg!) {
      warnings.add('Massa de gordura maior que o peso: confira os valores lidos.');
    }
    if (bio.gorduraPct != null && bio.gorduraPct! > 70) {
      warnings.add('Percentual de gordura acima de 70%: confira o valor lido.');
    }
    if (bio.gorduraKg != null && bio.pesoKg != null && bio.gorduraPct != null) {
      final expected = (bio.gorduraKg! / bio.pesoKg!) * 100;
      if ((expected - bio.gorduraPct!).abs() > 15) {
        warnings.add('Percentual de gordura não bate com massa de gordura e peso.');
      }
    }
    final lean = bio.massaMagraSegmentar;
    if (lean != null && bio.pesoKg != null) {
      final total = lean.totalKg;
      if (total != null && total > bio.pesoKg! * 0.9) {
        warnings.add('Soma das massas magras segmentares parece alta para o peso informado.');
      }
    }
    if (bio.idade != null && (bio.idade! < 10 || bio.idade! > 100)) {
      warnings.add('Idade fora do esperado (${bio.idade}) — confira na revisão.');
    }
  }
}
