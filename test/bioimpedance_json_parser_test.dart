import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/services/bioimpedance/bioimpedance_json_parser.dart';
import 'package:nutricoach_ai/services/bioimpedance_text_parser.dart';

BioimpedanceParseResult _json(String source) =>
    const BioimpedanceJsonParser().parse(source);

void main() {
  group('JSON exportado pelo app', () {
    test('faz ida e volta com todos os campos e segmentos', () {
      final original = const BioimpedanceTextParser().parseDetailed('''
Data: 03/09/2026
Sexo: Masculino
Idade: 23
Altura: 185 cm
Peso 121,2 kg
IMC 35,4
PGC 40,4 %
Massa de gordura 47,9 kg
Massa muscular esquelética 41,1 kg
Água corporal total 52,7 L
Proteína 12,9 kg
Minerais 4,3 kg
Taxa metabólica basal 1.930 kcal
Relação cintura-quadril 0,98
Nível de gordura visceral 20
Grau de obesidade 141 %
Pontuação InBody 52
Massa magra segmentar
Braço direito 3,4 kg
Braço esquerdo 3,3 kg
Tronco 28,5 kg
Perna direita 9,7 kg
Perna esquerda 9,6 kg
Gordura segmentar
Braço direito 1,2 kg 12,3 %
Tronco 12,4 kg 22,5 %
''').bioimpedance;

      final parsed = _json(jsonEncode(original.toJson())).bioimpedance;

      expect(parsed.data, DateTime(2026, 9, 3));
      expect(parsed.pesoKg, 121.2);
      expect(parsed.alturaCm, 185);
      expect(parsed.idade, 23);
      expect(parsed.sexo?.name, 'masculino');
      expect(parsed.imc, 35.4);
      expect(parsed.gorduraPct, 40.4);
      expect(parsed.gorduraKg, 47.9);
      expect(parsed.massaMuscularEsqueleticaKg, 41.1);
      expect(parsed.aguaL, 52.7);
      expect(parsed.proteinaKg, 12.9);
      expect(parsed.mineraisKg, 4.3);
      expect(parsed.tmbKcal, 1930);
      expect(parsed.relacaoCinturaQuadril, 0.98);
      expect(parsed.gorduraVisceral, 20);
      expect(parsed.grauObesidade, 141);
      expect(parsed.pontuacao, 52);
      expect(parsed.massaMagraSegmentar?.trunk, 28.5);
      expect(parsed.massaMagraSegmentar?.leftLeg, 9.6);
      expect(parsed.gorduraSegmentar?.rightArm, 1.2);
      expect(parsed.gorduraSegmentar?.rightArmPct, 12.3);
      expect(parsed.gorduraSegmentar?.trunkPct, 22.5);
    });
  });

  group('nomes de campos aceitos', () {
    test('nomes canônicos do extrator (inglês)', () {
      final result = _json('''
{
  "data": "2026-09-03",
  "weight": 121.2,
  "height": 185,
  "age": 23,
  "bmi": 35.4,
  "bodyFatPercentage": 40.4,
  "fatMass": 47.9,
  "skeletalMuscleMass": 41.1,
  "muscleMass": 45.2,
  "totalBodyWater": 52.7,
  "proteinMass": 12.9,
  "mineralMass": 4.3,
  "basalMetabolicRate": 1930,
  "waistHipRatio": 0.98,
  "visceralFatLevel": 20,
  "obesityDegree": 141,
  "inBodyScore": 52,
  "idealWeight": 79.4
}
''');
      final bio = result.bioimpedance;
      expect(bio.pesoKg, 121.2);
      expect(bio.alturaCm, 185);
      expect(bio.idade, 23);
      expect(bio.imc, 35.4);
      expect(bio.gorduraPct, 40.4);
      expect(bio.gorduraKg, 47.9);
      expect(bio.massaMuscularEsqueleticaKg, 41.1);
      expect(bio.massaMuscularKg, 45.2);
      expect(bio.aguaL, 52.7);
      expect(bio.proteinaKg, 12.9);
      expect(bio.mineraisKg, 4.3);
      expect(bio.tmbKcal, 1930);
      expect(bio.relacaoCinturaQuadril, 0.98);
      expect(bio.gorduraVisceral, 20);
      expect(bio.grauObesidade, 141);
      expect(bio.pontuacao, 52);
      expect(bio.pesoIdealKg, 79.4);
    });

    test('português com acento, camelCase e snake_case', () {
      final result = _json('''
{
  "Data": "03/09/2026",
  "Peso": "121,2",
  "Altura": 185,
  "IMC": 35.4,
  "Percentual de Gordura": 40.4,
  "massa_muscular_esquelética_kg": 41.1,
  "Água Corporal Total": 52.7,
  "gordura_visceral": 20,
  "Pontuação InBody": 52,
  "Taxa Metabólica Basal": "1.930"
}
''');
      final bio = result.bioimpedance;
      expect(bio.data, DateTime(2026, 9, 3));
      expect(bio.pesoKg, 121.2);
      expect(bio.imc, 35.4);
      expect(bio.gorduraPct, 40.4);
      expect(bio.massaMuscularEsqueleticaKg, 41.1);
      expect(bio.aguaL, 52.7);
      expect(bio.gorduraVisceral, 20);
      expect(bio.pontuacao, 52);
      expect(bio.tmbKcal, 1930);
    });

    test('números como texto, com vírgula ou ponto de milhar', () {
      final result = _json('{"pesoKg": "121,2", "imc": "35.4", "tmbKcal": "1.930"}');
      expect(result.bioimpedance.pesoKg, 121.2);
      expect(result.bioimpedance.imc, 35.4);
      expect(result.bioimpedance.tmbKcal, 1930);
    });
  });

  group('datas, sexo e fonte', () {
    test('aceita ISO, dd/mm/aaaa e epoch em milissegundos', () {
      expect(_json('{"data": "2026-09-03", "pesoKg": 90}').bioimpedance.data, DateTime(2026, 9, 3));
      expect(_json('{"data": "03/09/2026", "pesoKg": 90}').bioimpedance.data, DateTime(2026, 9, 3));
      expect(
        _json('{"data": ${DateTime(2026, 9, 3).millisecondsSinceEpoch}, "pesoKg": 90}')
            .bioimpedance
            .data,
        DateTime(2026, 9, 3),
      );
    });

    test('reconhece sexo em português e inglês', () {
      expect(_json('{"sexo": "M", "pesoKg": 90}').bioimpedance.sexo?.name, 'masculino');
      expect(_json('{"sexo": "feminino", "pesoKg": 90}').bioimpedance.sexo?.name, 'feminino');
      expect(_json('{"gender": "female", "pesoKg": 90}').bioimpedance.sexo?.name, 'feminino');
      expect(_json('{"genero": "male", "pesoKg": 90}').bioimpedance.sexo?.name, 'masculino');
    });

    test('identifica fabricante pela fonte', () {
      final result = _json('{"fonte": "InBody 970", "pesoKg": 90}');
      expect(result.manufacturer.id, 'inbody');
      expect(result.manufacturer.model, '970');
      expect(result.bioimpedance.fonte, 'InBody 970');
    });

    test('fonte desconhecida é preservada como veio', () {
      final result = _json('{"fabricante": "Balança da clínica", "pesoKg": 90}');
      expect(result.manufacturer.known, isFalse);
      expect(result.manufacturer.label, 'Balança da clínica');
    });
  });

  group('dados segmentares em JSON', () {
    test('objetos aninhados de massa magra e gordura', () {
      final result = _json('''
{
  "pesoKg": 121.2,
  "massaMagraSegmentar": {
    "rightArm": 3.4,
    "leftArm": 3.3,
    "trunk": 28.5,
    "rightLeg": 9.7,
    "leftLeg": 9.6
  },
  "gorduraSegmentar": {
    "braço direito": 1.2,
    "braço esquerdo": 1.1,
    "tronco": 12.4,
    "perna direita": 3.1,
    "perna esquerda": 3.0,
    "tronco_pct": 22.5
  }
}
''');
      final lean = result.bioimpedance.massaMagraSegmentar!;
      expect(lean.rightArm, 3.4);
      expect(lean.leftArm, 3.3);
      expect(lean.trunk, 28.5);
      expect(lean.rightLeg, 9.7);
      expect(lean.leftLeg, 9.6);

      final fat = result.bioimpedance.gorduraSegmentar!;
      expect(fat.rightArm, 1.2);
      expect(fat.leftArm, 1.1);
      expect(fat.trunk, 12.4);
      expect(fat.rightLeg, 3.1);
      expect(fat.leftLeg, 3.0);
      expect(fat.trunkPct, 22.5);
    });

    test('chaves planas com prefixo de seção', () {
      final result = _json('''
{
  "massaMagraSegmentar.trunk": 28.5,
  "massaMagraSegmentar.rightArmPercentual": 110.2,
  "gorduraSegmentar.tronco": 12.4
}
''');
      expect(result.bioimpedance.massaMagraSegmentar?.trunk, 28.5);
      expect(result.bioimpedance.massaMagraSegmentar?.rightArmPct, 110.2);
      expect(result.bioimpedance.gorduraSegmentar?.trunk, 12.4);
    });

    test('segmentar não preenche massa muscular esquelética', () {
      final result = _json('{"massaMagraSegmentar": {"trunk": 28.5}}');
      expect(result.bioimpedance.massaMagraSegmentar?.trunk, 28.5);
      expect(result.bioimpedance.massaMuscularEsqueleticaKg, isNull);
    });
  });

  group('preservação e erros', () {
    test('chaves desconhecidas ficam preservadas para revisão', () {
      final result = _json('{"pesoKg": 90, "aparelhoX": 123, "observacao": "laudo antigo"}');
      expect(result.unrecognizedLines, contains('aparelhoX: 123'));
      expect(result.unrecognizedLines, contains('observacao: laudo antigo'));
    });

    test('aceita objeto dentro de wrapper', () {
      final result = _json('{"bioimpedance": {"pesoKg": 90}}');
      expect(result.bioimpedance.pesoKg, 90);
    });

    test('JSON inválido explica o problema', () {
      expect(
        () => _json('{"pesoKg": 90,}'),
        throwsA(isA<LocalParseException>()
            .having((e) => e.message, 'message', contains('JSON inválido'))),
      );
    });

    test('JSON sem campos conhecidos falha com mensagem clara', () {
      expect(
        () => _json('{"foo": 1, "bar": "x"}'),
        throwsA(isA<LocalParseException>()
            .having((e) => e.message, 'message', contains('Nenhum campo conhecido'))),
      );
    });

    test('JSON vazio falha com mensagem clara', () {
      expect(
        () => _json('   '),
        throwsA(isA<LocalParseException>()
            .having((e) => e.message, 'message', contains('vazio'))),
      );
    });

    test('avisa quando falta a data', () {
      final result = _json('{"pesoKg": 90}');
      expect(result.warnings.any((w) => w.contains('Data')), isTrue);
    });

    test('mantém aviso de incoerência sem descartar valores', () {
      final result = _json('{"pesoKg": 40, "gorduraKg": 47.9}');
      expect(result.bioimpedance.pesoKg, 40);
      expect(result.bioimpedance.gorduraKg, 47.9);
      expect(result.warnings, isNotEmpty);
    });
  });
}
