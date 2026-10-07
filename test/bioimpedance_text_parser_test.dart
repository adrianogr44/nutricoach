import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/services/bioimpedance_text_parser.dart';

void main() {
  test('extrai campos conhecidos de um laudo textual sem IA generativa', () {
    const parser = BioimpedanceTextParser();

    final bio = parser.parse('''
Data: 03/09/2026
Peso: 121,2 kg
Altura: 185 cm
Idade: 23
IMC: 35,4 kg/m²
Percentual de gordura corporal: 40,4 %
Massa muscular esquelética: 41,1 kg
Água corporal total: 52,7 L
Taxa metabólica basal: 1930 kcal
Nível de gordura visceral: 20
Relação cintura-quadril: 0,98
Pontuação InBody: 52
''');

    expect(bio.data, DateTime(2026, 9, 3));
    expect(bio.pesoKg, 121.2);
    expect(bio.alturaCm, 185);
    expect(bio.idade, 23);
    expect(bio.gorduraPct, 40.4);
    expect(bio.massaMuscularKg, 41.1);
    expect(bio.aguaL, 52.7);
    expect(bio.tmbKcal, 1930);
    expect(bio.gorduraVisceral, 20);
    expect(bio.relacaoCinturaQuadril, 0.98);
    expect(bio.pontuacao, 52);
  });

  test('rejeita PDF inválido com erro local compreensível', () async {
    const parser = BioimpedanceTextParser();

    expect(
      () => parser.parsePdf(Uint8List(0)),
      throwsA(
        isA<LocalParseException>().having(
          (error) => error.message,
          'message',
          contains('PDF'),
        ),
      ),
    );
  });
}
