import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/data/models/bioimpedance.dart';
import 'package:nutricoach_ai/services/bioimpedance_text_parser.dart';

BioimpedanceParseResult _parse(String text) =>
    const BioimpedanceTextParser().parseDetailed(text);

/// Laudo fictício no layout do InBody (com faixas de referência e histórico).
const _inbodyFixture = '''
InBody 570
Data: 03/09/2026
Sexo: Masculino
Idade: 23 anos
Altura: 185 cm

Composição corporal
Peso 121,2 kg   Faixa normal 58,1 - 79,4 kg
IMC 35,4 kg/m²   18,5 - 24,9
PGC 40,4 %   10 - 20 %
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

Análise segmentar de massa magra
Braço direito   Braço esquerdo   Tronco   Perna direita   Perna esquerda
3,4   3,3   28,5   9,7   9,6
110,2   108,4   115,1   112,0   111,2

Gordura segmentar
Braço direito 1,2 kg 12,3 %
Braço esquerdo 1,1 kg 11,9 %
Tronco 12,4 kg 22,5 %
Perna direita 3,1 kg 15,0 %
Perna esquerda 3,0 kg 14,8 %

Histórico de resultados
Peso 130,0 kg
IMC 38,0
Nível de gordura visceral 24
''';

void main() {
  group('aliases dos campos gerais', () {
    final cases = <String, (List<String>, BioField, double)>{
      'peso': (['peso', 'peso corporal', 'massa corporal', 'weight'], BioField.weight, 121.2),
      'altura': (['altura', 'estatura', 'height'], BioField.height, 185),
      'idade': (['idade', 'age'], BioField.age, 23),
      'imc': (['imc', 'bmi', 'índice de massa corporal', 'indice de massa corporea'], BioField.bmi, 35.4),
      'pgc': (
        [
          'pgc',
          'bfp',
          'pbf',
          'percentual de gordura',
          'percentual de gordura corporal',
          '% de gordura',
          '% de gordura corporal',
          '% gordura',
          'percentual gordura',
          'body fat percentage',
        ],
        BioField.bodyFatPercentage,
        40.4
      ),
      'gordura kg': (
        ['massa de gordura', 'massa gorda', 'fat mass', 'massa de gordura corporal'],
        BioField.fatMass,
        47.9
      ),
      'massa esquelética': (
        [
          'massa muscular esquelética',
          'massa musculo esqueletica',
          'musculo esqueletico',
          'skeletal muscle mass',
          'mme',
          'smm',
        ],
        BioField.skeletalMuscleMass,
        41.1
      ),
      'massa muscular': (
        ['massa muscular', 'massa muscular total', 'muscle mass'],
        BioField.muscleMass,
        45.2
      ),
      'água': (
        ['água corporal total', 'agua corporal', 'agua total', 'total body water', 'act', 'tbw'],
        BioField.totalBodyWater,
        52.7
      ),
      'proteína': (['proteína', 'proteina', 'massa proteica'], BioField.proteinMass, 12.9),
      'minerais': (['minerais', 'massa mineral'], BioField.mineralMass, 4.3),
      'tmb': (
        [
          'taxa metabólica basal',
          'taxa metabolica basal',
          'metabolismo basal',
          'tmb',
          'bmr',
          'basal metabolic rate',
        ],
        BioField.basalMetabolicRate,
        1930
      ),
      'rcq': (
        [
          'relação cintura-quadril',
          'relacao cintura quadril',
          'cintura quadril',
          'rcq',
          'whr',
          'waist hip ratio',
        ],
        BioField.waistHipRatio,
        0.98
      ),
      'visceral': (
        [
          'nível de gordura visceral',
          'nivel de gordura visceral',
          'gordura visceral',
          'visceral fat level',
          'vfl',
        ],
        BioField.visceralFatLevel,
        20
      ),
      'obesidade': (
        ['grau de obesidade', 'percentual de obesidade', 'obesity degree'],
        BioField.obesityDegree,
        141
      ),
      'pontuação': (
        ['pontuação InBody', 'pontuacao inbody', 'inbody score', 'pontuacao', 'score inbody'],
        BioField.inBodyScore,
        52
      ),
      'peso ideal': (['peso ideal', 'ideal weight'], BioField.idealWeight, 79.4),
    };

    for (final entry in cases.entries) {
      for (final alias in entry.value.$1) {
        test('reconhece "${entry.key}" escrito como "$alias"', () {
          final unit = switch (entry.value.$2) {
            BioField.bodyFatPercentage ||
            BioField.obesityDegree =>
              '%',
            BioField.basalMetabolicRate => 'kcal',
            BioField.totalBodyWater => 'L',
            BioField.height => 'cm',
            BioField.age => 'anos',
            BioField.bmi => 'kg/m²',
            BioField.waistHipRatio || BioField.visceralFatLevel || BioField.inBodyScore => '',
            _ => 'kg',
          };
          final text = '$alias 12,5 $unit'.replaceFirst('12,5', _number(entry.value.$3));
          final result = _parse(text);
          final value = result.values[entry.value.$2];
          expect(value, closeTo(entry.value.$3, 0.001), reason: 'campo ${entry.value.$2} via "$alias"');
        });
      }
    }
  });

  group('números, quebras de linha e unidades', () {
    test('aceita vírgula e ponto decimal', () {
      expect(_parse('Peso 121,2 kg').values[BioField.weight], 121.2);
      expect(_parse('Peso 121.2 kg').values[BioField.weight], 121.2);
      expect(_parse('Peso 121.2kg').values[BioField.weight], 121.2);
    });

    test('milhar com ponto em kcal é lido como 1930', () {
      expect(_parse('Taxa metabólica basal 1.930 kcal').values[BioField.basalMetabolicRate], 1930);
      expect(_parse('Taxa metabólica basal 1,930 kcal').values[BioField.basalMetabolicRate], 1930);
      expect(_parse('Taxa metabólica basal 1930 kcal').values[BioField.basalMetabolicRate], 1930);
    });

    test('lê valor que caiu na linha de baixo (inclusive com linha em branco)', () {
      final result = _parse('''
Peso
121,2 kg
Massa de gordura

47,9 kg
''');
      expect(result.values[BioField.weight], 121.2);
      expect(result.values[BioField.fatMass], 47.9);
    });

    test('lê altura em metros convertendo para centímetros', () {
      final result = _parse('Altura 1,85 m');
      expect(result.bioimpedance.alturaCm, 185);
      expect(result.warnings.any((w) => w.contains('metros')), isTrue);
    });

    test('não confunde intervalo de referência com o valor medido', () {
      final result = _parse('''
Peso 121,2 kg   58,1 - 79,4 kg
IMC 35,4 kg/m²  18,5 a 24,9
Percentual de gordura 40,4 %   10 ~ 20 %
''');
      expect(result.bioimpedance.pesoKg, 121.2);
      expect(result.bioimpedance.imc, 35.4);
      expect(result.bioimpedance.gorduraPct, 40.4);
    });

    test('não trata números de escala gráfica como resultado', () {
      final result = _parse('''
Peso 121,2 kg
IMC 35,4
Composição corporal 40 50 60 70 80 90 100
''');
      expect(result.bioimpedance.pesoKg, 121.2);
      expect(result.bioimpedance.imc, 35.4);
    });
  });

  group('diferenças entre campos parecidos', () {
    test('massa muscular esquelética e massa muscular total não se misturam', () {
      final result = _parse('''
Massa muscular esquelética 41,1 kg
Massa muscular 45,2 kg
''');
      expect(result.bioimpedance.massaMuscularEsqueleticaKg, 41.1);
      expect(result.bioimpedance.massaMuscularKg, 45.2);
    });

    test('massa de gordura total e gordura segmentar ficam separadas', () {
      final result = _parse('''
Massa de gordura 47,9 kg
Gordura segmentar
Braço direito 1,2 kg
Tronco 12,4 kg
''');
      expect(result.bioimpedance.gorduraKg, 47.9);
      expect(result.bioimpedance.gorduraSegmentar?.rightArm, 1.2);
      expect(result.bioimpedance.gorduraSegmentar?.trunk, 12.4);
    });

    test('seção de massa magra não preenche massa muscular esquelética', () {
      final result = _parse('''
Análise segmentar de massa magra
Braço direito 3,4 kg
Braço esquerdo 3,3 kg
Tronco 28,5 kg
Perna direita 9,7 kg
Perna esquerda 9,6 kg
''');
      expect(result.bioimpedance.massaMuscularEsqueleticaKg, isNull);
      expect(result.bioimpedance.massaMagraSegmentar?.trunk, 28.5);
      expect(result.bioimpedance.massaMagraSegmentar?.leftLeg, 9.6);
    });
  });

  group('dados segmentares', () {
    test('lê tabela com colunas na ordem do cabeçalho (kg e %)', () {
      final result = _parse('''
Análise segmentar de massa magra
Braço direito   Braço esquerdo   Tronco   Perna direita   Perna esquerda
3,4   3,3   28,5   9,7   9,6
110,2   108,4   115,1   112,0   111,2
''');
      final lean = result.bioimpedance.massaMagraSegmentar;
      expect(lean, isNotNull);
      expect(lean!.rightArm, 3.4);
      expect(lean.leftArm, 3.3);
      expect(lean.trunk, 28.5);
      expect(lean.rightLeg, 9.7);
      expect(lean.leftLeg, 9.6);
      expect(lean.rightArmPct, 110.2);
      expect(lean.leftLegPct, 111.2);
    });

    test('lê tabela com um segmento por linha', () {
      final result = _parse('''
Gordura segmentar
Braço direito 1,2 kg 12,3 %
Braço esquerdo 1,1 kg 11,9 %
Tronco 12,4 kg 22,5 %
Perna direita 3,1 kg 15,0 %
Perna esquerda 3,0 kg 14,8 %
''');
      final fat = result.bioimpedance.gorduraSegmentar;
      expect(fat!.rightArm, 1.2);
      expect(fat.leftArm, 1.1);
      expect(fat.trunk, 12.4);
      expect(fat.rightLeg, 3.1);
      expect(fat.leftLeg, 3.0);
      expect(fat.trunkPct, 22.5);
    });

    test('sem seção segmentar os campos permanecem nulos', () {
      final result = _parse('Peso 121,2 kg');
      expect(result.bioimpedance.massaMagraSegmentar, isNull);
      expect(result.bioimpedance.gorduraSegmentar, isNull);
    });
  });

  group('avaliação atual versus histórico', () {
    test('ignora valores depois do marcador de histórico', () {
      final result = _parse('''
Data: 03/09/2026
Peso 121,2 kg
IMC 35,4
Nível de gordura visceral 20
Histórico de resultados
Peso 130,0 kg
IMC 38,0
Nível de gordura visceral 24
''');
      expect(result.bioimpedance.pesoKg, 121.2);
      expect(result.bioimpedance.imc, 35.4);
      expect(result.bioimpedance.gorduraVisceral, 20);
    });

    test('laudo completo usa a avaliação atual, não o histórico', () {
      final result = _parse(_inbodyFixture);
      expect(result.bioimpedance.pesoKg, 121.2);
      expect(result.bioimpedance.imc, 35.4);
      expect(result.bioimpedance.gorduraVisceral, 20);
    });
  });

  group('data da avaliação', () {
    test('reconhece dd/mm/aaaa', () {
      expect(_parse('Data: 03/09/2026\nPeso 90 kg').bioimpedance.data, DateTime(2026, 9, 3));
    });

    test('reconhece dd.mm.aa', () {
      expect(_parse('Data: 03.09.26\nPeso 90 kg').bioimpedance.data, DateTime(2026, 9, 3));
    });

    test('reconhece aaaa-mm-dd', () {
      expect(_parse('Exame em 2026-09-03\nPeso 90 kg').bioimpedance.data, DateTime(2026, 9, 3));
    });

    test('reconhece data por extenso', () {
      expect(_parse('Data: 12 de novembro de 2025\nPeso 90 kg').bioimpedance.data, DateTime(2025, 11, 12));
    });

    test('ignora data de nascimento e usa a data do exame', () {
      final result = _parse('''
Data de nascimento: 01/02/1990
Data do exame: 03/09/2026
Peso 90 kg
''');
      expect(result.bioimpedance.data, DateTime(2026, 9, 3));
    });

    test('sem data usa hoje e avisa', () {
      final result = _parse('Peso 90 kg');
      final now = DateTime.now();
      expect(result.bioimpedance.data.day, now.day);
      expect(result.warnings.any((w) => w.contains('Data')), isTrue);
    });
  });

  group('laudo completo (InBody)', () {
    late BioimpedanceParseResult result;

    setUpAll(() => result = _parse(_inbodyFixture));

    test('identifica fabricante e modelo', () {
      expect(result.manufacturer.id, 'inbody');
      expect(result.manufacturer.displayName, contains('InBody'));
      expect(result.manufacturer.model, '570');
    });

    test('extrai todos os campos gerais', () {
      final bio = result.bioimpedance;
      expect(bio.data, DateTime(2026, 9, 3));
      expect(bio.sexo?.name, 'masculino');
      expect(bio.idade, 23);
      expect(bio.alturaCm, 185);
      expect(bio.pesoKg, 121.2);
      expect(bio.imc, 35.4);
      expect(bio.gorduraPct, 40.4);
      expect(bio.gorduraKg, 47.9);
      expect(bio.massaMuscularEsqueleticaKg, 41.1);
      expect(bio.massaMuscularKg, isNull);
      expect(bio.aguaL, 52.7);
      expect(bio.proteinaKg, 12.9);
      expect(bio.mineraisKg, 4.3);
      expect(bio.tmbKcal, 1930);
      expect(bio.relacaoCinturaQuadril, 0.98);
      expect(bio.gorduraVisceral, 20);
      expect(bio.grauObesidade, 141);
      expect(bio.pontuacao, 52);
    });

    test('extrai os dois blocos segmentares', () {
      final lean = result.bioimpedance.massaMagraSegmentar!;
      expect(lean.rightArm, 3.4);
      expect(lean.trunk, 28.5);
      expect(lean.leftLeg, 9.6);

      final fat = result.bioimpedance.gorduraSegmentar!;
      expect(fat.rightArm, 1.2);
      expect(fat.trunk, 12.4);
      expect(fat.leftLeg, 3.0);
      expect(fat.rightArmPct, 12.3);
    });

    test('não traz números do histórico nem das faixas', () {
      expect(result.bioimpedance.pesoKg, isNot(130));
      expect(result.bioimpedance.imc, isNot(38));
      expect(result.bioimpedance.pesoKg, isNot(58.1));
    });

    test('preserva o texto não reconhecido em vez de descartar', () {
      expect(result.unrecognizedLines, isNotEmpty);
      expect(result.rawText, contains('InBody 570'));
    });
  });

  group('campos ausentes e segurança', () {
    test('não inventa valores ausentes', () {
      final result = _parse('Peso 92,4 kg');
      final bio = result.bioimpedance;
      expect(bio.pesoKg, 92.4);
      expect(bio.imc, isNull);
      expect(bio.gorduraPct, isNull);
      expect(bio.tmbKcal, isNull);
      expect(bio.gorduraVisceral, isNull);
      expect(bio.relacaoCinturaQuadril, isNull);
      expect(bio.pontuacao, isNull);
      expect(bio.massaMagraSegmentar, isNull);
      expect(bio.gorduraSegmentar, isNull);
    });

    test('texto sem nenhum campo conhecido falha com mensagem clara', () {
      expect(
        () => _parse('Laudo sem números reconhecíveis'),
        throwsA(isA<LocalParseException>().having((e) => e.message, 'message', contains('Nenhum campo'))),
      );
    });

    test('texto vazio falha com mensagem clara', () {
      expect(
        () => _parse('   '),
        throwsA(isA<LocalParseException>().having((e) => e.message, 'message', contains('vazio'))),
      );
    });

    test('resolve conflito de leitura sem descartar o valor lido', () {
      final result = _parse('Massa de gordura 47,9 kg\nPeso 40,0 kg');
      expect(result.bioimpedance.gorduraKg, 47.9);
      expect(result.bioimpedance.pesoKg, 40.0);
      expect(result.warnings, isNotEmpty);
    });

    test('PDF inválido continua com erro local compreensível', () async {
      expect(
        () => const BioimpedanceTextParser().parsePdf(Uint8List(0)),
        throwsA(isA<LocalParseException>().having((e) => e.message, 'message', contains('PDF'))),
      );
    });
  });

  group('modelo e persistência', () {
    test('JSON preserva campos novos e segmentares', () {
      final original = _parse(_inbodyFixture).bioimpedance;
      final restored = Bioimpedance.fromJson(original.toJson());

      expect(restored.massaMuscularEsqueleticaKg, 41.1);
      expect(restored.grauObesidade, 141);
      expect(restored.massaMagraSegmentar?.trunk, 28.5);
      expect(restored.massaMagraSegmentar?.rightArmPct, 110.2);
      expect(restored.gorduraSegmentar?.rightArm, 1.2);
      expect(restored.fonte, contains('InBody'));
    });

    test('JSON antigo sem campos novos continua válido', () {
      final old = Bioimpedance.fromJson({
        'data': '2026-01-05T00:00:00.000',
        'pesoKg': 90,
        'massaMuscularKg': 40,
      });
      expect(old.pesoKg, 90);
      expect(old.massaMuscularKg, 40);
      expect(old.massaMuscularEsqueleticaKg, isNull);
      expect(old.massaMagraSegmentar, isNull);
    });
  });
}

String _number(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2).replaceAll(RegExp(r'0$'), '').replaceAll('.', ',');
}
