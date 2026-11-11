/// Dicionário de nomes encontrados em laudos de bioimpedância.
///
/// Todas as chaves são normalizadas (minúsculas e sem acento) pelo
/// `BioimpedanceTextNormalizer`. Para adicionar um fabricante novo, basta
/// acrescentar aliases na lista do campo correspondente ou registrar um
/// perfil de fabricante em `BioimpedanceManufacturerProfiles`.
library;

/// Campos gerais da composição corporal que o app sabe representar.
enum BioField {
  weight,
  height,
  age,
  bmi,
  bodyFatPercentage,
  fatMass,
  skeletalMuscleMass,
  muscleMass,
  totalBodyWater,
  proteinMass,
  mineralMass,
  basalMetabolicRate,
  waistHipRatio,
  visceralFatLevel,
  obesityDegree,
  inBodyScore,
  idealWeight,
}

class BioFieldSpec {
  const BioFieldSpec({
    required this.field,
    required this.label,
    required this.unit,
    required this.aliases,
    this.integer = false,
    this.min,
    this.max,
  });

  final BioField field;

  /// Rótulo em pt-BR usado na tela de revisão.
  final String label;

  /// Unidade esperada (apenas para validar a leitura, não para converter).
  final String unit;

  /// Nomes normalizados que identificam o campo no laudo.
  final List<String> aliases;

  /// Campos que só fazem sentido inteiros (idade, pontuação, nível visceral).
  final bool integer;

  /// Limites apenas de sanidade técnica, nunca de faixa de referência.
  final double? min;
  final double? max;
}

/// Especificação dos campos gerais, do mais específico para o mais genérico.
///
/// A ordem importa: nomes compostos (`peso ideal`, `massa muscular esqueletica`)
/// precisam ser reconhecidos antes dos nomes curtos (`peso`, `massa muscular`).
const List<BioFieldSpec> bioFieldSpecs = [
  BioFieldSpec(
    field: BioField.idealWeight,
    label: 'Peso ideal',
    unit: 'kg',
    min: 20,
    max: 400,
    aliases: ['peso ideal', 'ideal weight', 'peso recomendado'],
  ),
  BioFieldSpec(
    field: BioField.skeletalMuscleMass,
    label: 'Massa muscular esquelética',
    unit: 'kg',
    min: 5,
    max: 120,
    aliases: [
      'massa muscular esqueletica',
      'massa musculo esqueletica',
      'musculo esqueletico',
      'massa esqueletica',
      'skeletal muscle mass',
      'massa muscular esquelética',
      'smm',
      'mme',
      'smme',
    ],
  ),
  BioFieldSpec(
    field: BioField.bodyFatPercentage,
    label: 'Percentual de gordura',
    unit: '%',
    min: 1,
    max: 75,
    aliases: [
      'percentual de gordura corporal',
      'percentual de gordura',
      'percentual de massa gorda',
      'percentual de massa de gordura',
      'gordura corporal percentual',
      'body fat percentage',
      'percent body fat',
      'pgc',
      'bfp',
      'pbf',
      '% de gordura',
      '% de gordura corporal',
      '% gordura',
      'percentual gordura',
    ],
  ),
  BioFieldSpec(
    field: BioField.fatMass,
    label: 'Massa de gordura',
    unit: 'kg',
    min: 1,
    max: 300,
    aliases: [
      'massa de gordura corporal',
      'massa de gordura',
      'massa gorda',
      'gordura corporal kg',
      'gordura em kg',
      'peso de gordura',
      'fat mass',
      'massa gordura',
    ],
  ),
  BioFieldSpec(
    field: BioField.totalBodyWater,
    label: 'Água corporal total',
    unit: 'l',
    min: 5,
    max: 120,
    aliases: [
      'agua corporal total',
      'agua corporea total',
      'agua total corporal',
      'agua total',
      'total body water',
      'agua corporal',
      'act',
      'tbw',
    ],
  ),
  BioFieldSpec(
    field: BioField.proteinMass,
    label: 'Proteína',
    unit: 'kg',
    min: 1,
    max: 60,
    aliases: [
      'massa proteica',
      'proteinas corporais',
      'proteina corporal',
      'proteina',
      'proteinas',
      'protein',
    ],
  ),
  BioFieldSpec(
    field: BioField.mineralMass,
    label: 'Minerais',
    unit: 'kg',
    min: 0.3,
    max: 20,
    aliases: [
      'massa mineral ossea',
      'massa mineral',
      'minerais corporais',
      'minerais',
      'mineral',
    ],
  ),
  BioFieldSpec(
    field: BioField.basalMetabolicRate,
    label: 'Taxa metabólica basal',
    unit: 'kcal',
    min: 500,
    max: 6000,
    aliases: [
      'taxa metabolica basal',
      'taxa de metabolismo basal',
      'metabolismo basal',
      'basal metabolic rate',
      'tmb',
      'bmr',
      'gasto energetico basal',
    ],
  ),
  BioFieldSpec(
    field: BioField.waistHipRatio,
    label: 'Relação cintura-quadril',
    unit: '',
    min: 0.3,
    max: 2,
    aliases: [
      'relacao cintura quadril',
      'relacao cintura-quadril',
      'relacao cintura/quadril',
      'relacao cintura/quadril rcq',
      'cintura-quadril',
      'cintura quadril',
      'waist hip ratio',
      'rcq',
      'whr',
    ],
  ),
  BioFieldSpec(
    field: BioField.visceralFatLevel,
    label: 'Nível de gordura visceral',
    unit: '',
    integer: true,
    min: 1,
    max: 60,
    aliases: [
      'nivel de gordura visceral',
      'gordura visceral nivel',
      'nivel visceral',
      'visceral fat level',
      'gordura visceral',
      'visceral fat',
      'vfl',
      'nivel de gordura visceral vfl',
    ],
  ),
  BioFieldSpec(
    field: BioField.obesityDegree,
    label: 'Grau de obesidade',
    unit: '%',
    min: 1,
    max: 300,
    aliases: [
      'grau de obesidade',
      'percentual de obesidade',
      'grau de obesidade corporal',
      'obesity degree',
      'obesidade',
    ],
  ),
  BioFieldSpec(
    field: BioField.bmi,
    label: 'IMC',
    unit: 'kg/m2',
    min: 5,
    max: 90,
    aliases: [
      'indice de massa corporal',
      'indice de massa corporea',
      'body mass index',
      'imc',
      'bmi',
    ],
  ),
  BioFieldSpec(
    field: BioField.inBodyScore,
    label: 'Pontuação InBody',
    unit: 'pts',
    integer: true,
    min: 1,
    max: 100,
    aliases: [
      'pontuacao inbody',
      'pontuacao do inbody',
      'pontuacao corporal',
      'inbody score',
      'pontuacao',
      'score inbody',
    ],
  ),
  BioFieldSpec(
    field: BioField.weight,
    label: 'Peso',
    unit: 'kg',
    min: 10,
    max: 500,
    aliases: [
      'peso corporal',
      'massa corporal',
      'peso kg',
      'peso',
      'weight',
    ],
  ),
  BioFieldSpec(
    field: BioField.height,
    label: 'Altura',
    unit: 'cm',
    min: 50,
    max: 260,
    aliases: [
      'altura',
      'estatura',
      'height',
    ],
  ),
  BioFieldSpec(
    field: BioField.age,
    label: 'Idade',
    unit: 'anos',
    integer: true,
    min: 3,
    max: 120,
    aliases: [
      'idade',
      'age',
    ],
  ),
  BioFieldSpec(
    field: BioField.muscleMass,
    label: 'Massa muscular',
    unit: 'kg',
    min: 5,
    max: 150,
    aliases: [
      'massa muscular total',
      'massa muscular corporal',
      'massa muscular',
      'muscle mass',
      'massa dos musculos',
    ],
  ),
];

/// Aliases de seção usados para identificar o bloco segmentar.
class BioSectionAliases {
  const BioSectionAliases._();

  static const List<String> leanSegmental = [
    'analise segmentar de massa magra',
    'analise segmentar da massa magra',
    'massa magra segmentar',
    'massa magra por segmento',
    'massa magra segmentada',
    'massa muscular segmentar',
    'massa muscular por segmento',
    'segmental lean analysis',
    'segmental muscle analysis',
    'lean segmental',
  ];

  static const List<String> fatSegmental = [
    'analise segmentar de gordura',
    'analise segmentar da gordura',
    'analise segmentar de gordura corporal',
    'gordura corporal segmentar',
    'gordura segmentar',
    'gordura por segmento',
    'gordura segmentada',
    'segmental fat analysis',
    'fat segmental',
  ];

  /// Cabeçalhos que encerram um bloco segmentar.
  static const List<String> terminators = [
    'analise da composicao corporal',
    'composicao corporal',
    'analise segmentar',
    'historico',
    'historico de resultados',
    'evolucao',
    'comparativo',
    'referencia',
    'valores de referencia',
    'dados pessoais',
    'informacoes pessoais',
    'observacoes',
    'analise de resultados',
    'resultado da avaliacao',
    'avaliacao fisica',
    'impedancia',
  ];

  /// Marcadores a partir dos quais o texto deixa de ser a avaliação atual.
  static const List<String> historyMarkers = [
    'historico',
    'historico de resultados',
    'historico de avaliacoes',
    'evolucao',
    'comparativo',
    'analise de tendencia',
    'resultados anteriores',
    'avaliacoes anteriores',
    'tendencia',
  ];

  static const List<String> segments = [
    'braco direito',
    'braco esquerdo',
    'tronco',
    'perna direita',
    'perna esquerda',
  ];
}
