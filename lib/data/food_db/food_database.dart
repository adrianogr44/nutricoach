import '../models/food.dart';
import 'taco_foods.dart';

/// Banco de alimentos baseado na Tabela Brasileira de Composição de
/// Alimentos (TACO 4ª ed., NEPA/UNICAMP) — tabela completa (597 alimentos,
/// [taco_foods.dart]) — além de itens curados com porções padrão e sinônimos.
///
/// Valores por 100 g de alimento pronto para consumo.
/// REGRA CRÍTICA: a IA NUNCA calcula nutrientes. Todo valor nutricional
/// registrado no app vem deste banco ou de fonte externa validada.
class FoodDatabase {
  FoodDatabase._();

  static final List<Food> _baseline = _build();
  static List<Food> _foods = List.of(_baseline);
  static Map<String, Food> _byId = {
    for (final f in _foods) f.id: f,
  };
  static int _revision = 0;

  static List<Food> get all => List.unmodifiable(_foods);
  static int get revision => _revision;

  static Food? byId(String id) => _byId[id];

  static void installOverlay(List<Food> foods, {required int revision}) {
    final merged = <String, Food>{for (final food in _baseline) food.id: food};
    for (final food in foods) {
      merged[food.id] = food;
    }
    _foods = merged.values.toList(growable: false);
    _byId = Map.unmodifiable(merged);
    _revision = revision;
  }

  static Food? byBarcode(String barcode) {
    for (final f in _foods) {
      if (f.barcode == barcode) return f;
    }
    return null;
  }

  /// Busca rápida por nome/alias (case e acento insensível).
  static List<Food> search(String query, {int limit = 40}) {
    final q = _normalize(query.trim().toLowerCase());
    if (q.isEmpty) return _foods.take(limit).toList();
    final scored = <(Food, int)>[];
    for (final f in _foods) {
      final name = _normalize(f.name.toLowerCase());
      if (name == q) {
        scored.add((f, 1000));
        continue;
      }
      if (name.startsWith(q)) {
        scored.add((f, 500));
        continue;
      }
      if (name.contains(q)) {
        scored.add((f, 300));
        continue;
      }
      for (final a in f.aliases) {
        final al = _normalize(a.toLowerCase());
        if (al == q) {
          scored.add((f, 600));
          break;
        }
        if (al.contains(q)) {
          scored.add((f, 250));
          break;
        }
      }
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).map((e) => e.$1).toList();
  }

  /// Normaliza acentos e caracteres especiais para busca.
  static String _normalize(String s) {
    const com = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const sem = 'aaaaaeeeeiiiiooooouuuuc';
    final buffer = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final idx = com.indexOf(ch);
      buffer.write(idx >= 0 ? sem[idx] : ch);
    }
    return buffer.toString();
  }

  /// Categorias disponíveis.
  static List<String> get categories {
    final seen = <String>{};
    for (final f in _foods) {
      seen.add(f.category);
    }
    return seen.toList()..sort();
  }

  static Food _f(
    String id,
    String name,
    String category,
    double kcal,
    double protein,
    double carbs,
    double fat, {
    double fiber = 0,
    double sodium = 0,
    double portion = 100,
    List<String> aliases = const [],
    String source = 'TACO/TBCA',
  }) {
    return Food(
      id: id,
      name: name,
      category: category,
      kcal: kcal,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      sodium: sodium,
      standardPortionGrams: portion,
      aliases: aliases,
      source: source,
    );
  }

  static List<Food> _build() {
    return [
      ...tacoFoods,
      // ───────────── CEREAIS, GRÃOS E MASSAS ─────────────
      _f('arroz-branco', 'Arroz branco cozido', 'Cereais e grãos', 128, 2.5, 28.1, 0.2,
          fiber: 1.6, sodium: 1, portion: 150, aliases: ['arroz', 'arroz cozido', 'arroz branco']),
      _f('arroz-integral', 'Arroz integral cozido', 'Cereais e grãos', 124, 2.6, 25.8, 1.0,
          fiber: 2.5, sodium: 1, portion: 150, aliases: ['arroz integral']),
      _f('pao-frances', 'Pão francês', 'Pães e torradas', 300, 8.0, 58.6, 3.1,
          fiber: 2.3, sodium: 622, portion: 50, aliases: ['paozinho', 'pao de sal']),
      _f('pao-forma', 'Pão de forma integral', 'Pães e torradas', 253, 7.9, 43.4, 3.7,
          fiber: 2.7, sodium: 499, portion: 50, aliases: ['pao de forma', 'pao integral']),
      _f('pao-branco', 'Pão branco', 'Pães e torradas', 268, 8.0, 54.0, 3.2,
          fiber: 1.9, sodium: 500, portion: 50, aliases: ['pao de sanduiche']),
      _f('aveia', 'Aveia em flocos', 'Cereais e grãos', 394, 13.9, 66.6, 8.5,
          fiber: 9.1, sodium: 11, portion: 40, aliases: ['aveia em flocos', 'farinha de aveia']),
      _f('macarrao', 'Macarrão cozido', 'Cereais e grãos', 112, 3.5, 21.8, 1.1,
          fiber: 1.5, sodium: 3, portion: 200, aliases: ['massa cozida', 'espaguete', 'miojo sem tempero']),
      _f('farinha-mandioca', 'Farinha de mandioca', 'Cereais e grãos', 361, 1.6, 87.9, 0.3,
          fiber: 6.4, sodium: 2, portion: 30, aliases: ['farinha']),
      _f('cuscuz', 'Cuscuz de milho cozido', 'Cereais e grãos', 113, 2.0, 25.3, 0.7,
          fiber: 2.7, sodium: 38, portion: 120, aliases: ['cuscuz nordestino']),
      _f('polenta', 'Polenta cozida', 'Cereais e grãos', 74, 1.3, 16.7, 0.3,
          fiber: 0.9, sodium: 23, portion: 150, aliases: ['polenta cozida', 'mole']),
      _f('granola', 'Granola', 'Cereais e grãos', 402, 9.6, 66.4, 11.4,
          fiber: 8.1, sodium: 25, portion: 40, aliases: ['granola com frutas']),
      _f('barra-cereal', 'Barra de cereal', 'Cereais e grãos', 397, 6.8, 73.4, 8.4,
          fiber: 6.3, sodium: 78, portion: 25, aliases: ['barra cereal']),

      // ───────────── LEGUMINOSAS ─────────────
      _f('feijao-carioca', 'Feijão carioca cozido', 'Leguminosas', 76, 4.8, 13.6, 0.5,
          fiber: 8.5, sodium: 244, portion: 130, aliases: ['feijao', 'feijao cozido', 'feijao carioca', 'feijao preto']),
      _f('feijao-preto', 'Feijão preto cozido', 'Leguminosas', 77, 4.5, 14.0, 0.5,
          fiber: 8.4, sodium: 218, portion: 130, aliases: ['feijao preto']),
      _f('lentilha', 'Lentilha cozida', 'Leguminosas', 93, 6.3, 16.3, 0.5,
          fiber: 7.9, sodium: 139, portion: 130, aliases: ['lentilha cozida']),
      _f('grao-de-bico', 'Grão-de-bico cozido', 'Leguminosas', 121, 8.4, 20.7, 2.4,
          fiber: 5.4, sodium: 180, portion: 130, aliases: ['gracao de bico']),
      _f('ervilha', 'Ervilha cozida', 'Leguminosas', 79, 6.2, 14.7, 0.3,
          fiber: 6.2, sodium: 57, portion: 100, aliases: ['ervilha cozida']),
      _f('soja', 'Soja cozida', 'Leguminosas', 151, 12.5, 10.6, 6.5,
          fiber: 7.4, sodium: 59, portion: 100, aliases: ['grão de soja', 'soja em grao']),

      // ───────────── CARNES, AVES, PEIXES E OVOS ─────────────
      _f('peito-frango', 'Peito de frango grelhado', 'Carnes e aves', 159, 32.0, 0, 3.2,
          fiber: 0, sodium: 60, portion: 120, aliases: ['frango grelhado', 'peito de frango', 'frango']),
      _f('peito-frango-cozido', 'Peito de frango cozido', 'Carnes e aves', 163, 31.5, 0, 3.8,
          sodium: 59, portion: 120, aliases: ['frango cozido', 'peito de frango cozido']),
      _f('coxa-frango', 'Coxa de frango assada', 'Carnes e aves', 215, 25.9, 0, 12.4,
          sodium: 68, portion: 100, aliases: ['coxa de frango', 'sobrecoxa']),
      _f('frango-assado', 'Frango assado inteiro', 'Carnes e aves', 218, 25.6, 0, 12.7,
          sodium: 67, portion: 100, aliases: ['frango assado']),
      _f('nuggets', 'Frango empanado (nuggets)', 'Carnes e aves', 296, 11.1, 19.7, 18.9,
          fiber: 1.0, sodium: 365, portion: 100, aliases: ['nuggets', 'frango empanado']),
      _f('file-mignon', 'Filé mignon grelhado', 'Carnes e aves', 223, 32.0, 0, 10.5,
          sodium: 66, portion: 120, aliases: ['file mignon', 'bife']),
      _f('contrafile', 'Contrafilé grelhado', 'Carnes e aves', 246, 25.5, 0, 16.3,
          sodium: 63, portion: 120, aliases: ['contra file', 'bife de contrafile']),
      _f('picanha', 'Picanha grelhada', 'Carnes e aves', 289, 27.4, 0, 20.2,
          sodium: 61, portion: 120, aliases: ['picanha']),
      _f('patinho', 'Patinho moído refogado', 'Carnes e aves', 190, 27.2, 0, 8.8,
          sodium: 71, portion: 100, aliases: ['carne moida', 'patinho']),
      _f('alcatra', 'Alcatra grelhada', 'Carnes e aves', 239, 27.9, 0, 14.4,
          sodium: 65, portion: 120, aliases: ['alcatra']),
      _f('costela-bovina', 'Costela bovina assada', 'Carnes e aves', 373, 28.8, 0, 28.6,
          sodium: 65, portion: 120, aliases: ['costela', 'costela assada']),
      _f('lombo-porco', 'Lombo de porco assado', 'Carnes e aves', 210, 33.6, 0, 8.0,
          sodium: 58, portion: 120, aliases: ['lombo suino', 'lombo']),
      _f('pernil', 'Pernil suíno assado', 'Carnes e aves', 262, 26.5, 0, 17.3,
          sodium: 66, portion: 120, aliases: ['pernil']),
      _f('charque', 'Carne seca (charque) cozida', 'Carnes e aves', 274, 26.9, 0, 18.0,
          sodium: 4040, portion: 100, aliases: ['carne seca', 'charque', 'carne de sol']),
      _f('bacon', 'Bacon', 'Carnes e aves', 488, 13.3, 0, 48.5,
          sodium: 1053, portion: 30, aliases: ['bacon']),
      _f('salsicha', 'Salsicha', 'Carnes e aves', 255, 12.5, 2.6, 21.7,
          sodium: 1390, portion: 50, aliases: ['salsicha']),
      _f('presunto', 'Presunto', 'Carnes e aves', 129, 14.2, 0, 7.6,
          sodium: 1396, portion: 50, aliases: ['presunto']),
      _f('mortadela', 'Mortadela', 'Carnes e aves', 269, 12.0, 5.8, 21.6,
          sodium: 1547, portion: 50, aliases: ['mortadela']),
      _f('peito-peru', 'Peito de peru defumado', 'Carnes e aves', 103, 16.8, 0, 2.0,
          sodium: 1235, portion: 50, aliases: ['peito de peru', 'peru']),
      _f('tilapia', 'Tilápia grelhada', 'Peixes e frutos do mar', 128, 26.2, 0, 2.4,
          sodium: 47, portion: 120, aliases: ['tilapia', 'peixe grelhado', 'peixe']),
      _f('salmão', 'Salmão grelhado', 'Peixes e frutos do mar', 240, 23.9, 0, 15.9,
          sodium: 50, portion: 120, aliases: ['salmao']),
      _f('sardinha', 'Sardinha assada', 'Peixes e frutos do mar', 134, 25.0, 0, 3.7,
          sodium: 67, portion: 100, aliases: ['sardinha']),
      _f('atum', 'Atum (conserva, em óleo)', 'Peixes e frutos do mar', 166, 25.6, 0, 6.9,
          sodium: 419, portion: 100, aliases: ['atum em lata', 'atum']),
      _f('camarao', 'Camarão cozido', 'Peixes e frutos do mar', 99, 20.5, 0.3, 1.6,
          sodium: 187, portion: 100, aliases: ['camarao']),
      _f('ovo', 'Ovo de galinha cozido', 'Ovos', 146, 13.3, 0.6, 9.5,
          sodium: 136, portion: 50, aliases: ['ovo cozido', 'ovo']),
      _f('ovo-frito', 'Ovo frito', 'Ovos', 240, 15.6, 1.2, 18.6,
          sodium: 171, portion: 50, aliases: ['ovo frito', 'ovo estrelado']),
      _f('ovo-mexido', 'Ovo mexido', 'Ovos', 145, 13.2, 1.2, 9.6,
          sodium: 175, portion: 60, aliases: ['ovos mexidos']),

      // ───────────── LEITE E DERIVADOS ─────────────
      _f('leite-integral', 'Leite integral', 'Leite e derivados', 61, 3.2, 4.7, 3.3,
          sodium: 56, portion: 200, aliases: ['leite', 'leite integral']),
      _f('leite-desnatado', 'Leite desnatado', 'Leite e derivados', 33, 3.4, 5.0, 0.2,
          sodium: 47, portion: 200, aliases: ['leite desnatado', 'leite semidesnatado']),
      _f('iogurte', 'Iogurte natural', 'Leite e derivados', 51, 4.1, 4.0, 2.5,
          sodium: 68, portion: 170, aliases: ['iogurte', 'iogurte natural']),
      _f('iogurte-grego', 'Iogurte grego', 'Leite e derivados', 115, 5.7, 6.7, 7.2,
          sodium: 60, portion: 170, aliases: ['iogurte grego']),
      _f('queijo-minas', 'Queijo minas frescal', 'Leite e derivados', 264, 17.4, 3.2, 20.2,
          sodium: 577, portion: 30, aliases: ['queijo minas', 'queijo branco']),
      _f('mussarela', 'Queijo mussarela', 'Leite e derivados', 330, 22.6, 3.0, 25.2,
          sodium: 581, portion: 30, aliases: ['queijo mussarela', 'muçarela', 'queijo']),
      _f('queijo-prato', 'Queijo prato', 'Leite e derivados', 360, 22.7, 1.9, 29.1,
          sodium: 595, portion: 30, aliases: ['queijo prato']),
      _f('cottage', 'Queijo cottage', 'Leite e derivados', 98, 11.1, 3.4, 4.3,
          sodium: 407, portion: 50, aliases: ['queijo cottage', 'cottage']),
      _f('requeijao', 'Requeijão cremoso', 'Leite e derivados', 257, 9.6, 4.2, 22.6,
          sodium: 471, portion: 30, aliases: ['requeijao']),
      _f('ricota', 'Ricota', 'Leite e derivados', 140, 12.6, 3.8, 8.0,
          sodium: 209, portion: 50, aliases: ['ricota']),
      _f('manteiga', 'Manteiga com sal', 'Leite e derivados', 726, 0.4, 0, 82.4,
          sodium: 545, portion: 10, aliases: ['manteiga', 'manteiga de leite']),
      _f('queijo-parmesao', 'Queijo parmesão', 'Leite e derivados', 453, 35.6, 1.7, 33.4,
          sodium: 1375, portion: 20, aliases: ['parmesao', 'queijo parmesao']),

      // ───────────── FRUTAS ─────────────
      _f('banana', 'Banana prata', 'Frutas', 98, 1.3, 26.0, 0.1,
          fiber: 2.0, sodium: 1, portion: 100, aliases: ['banana', 'banana prata', 'banana nanica']),
      _f('maca', 'Maçã', 'Frutas', 56, 0.3, 15.2, 0,
          fiber: 1.3, sodium: 2, portion: 130, aliases: ['maca', 'maca fuji', 'maca gala']),
      _f('laranja', 'Laranja', 'Frutas', 46, 1.0, 11.5, 0.1,
          fiber: 1.3, sodium: 1, portion: 130, aliases: ['laranja', 'laranja pera']),
      _f('mamao', 'Mamão papaia', 'Frutas', 40, 0.5, 10.4, 0.1,
          fiber: 1.0, sodium: 4, portion: 150, aliases: ['mamao', 'papaia']),
      _f('abacate', 'Abacate', 'Frutas', 96, 1.2, 6.0, 8.4,
          fiber: 6.3, sodium: 1, portion: 100, aliases: ['abacate']),
      _f('melancia', 'Melancia', 'Frutas', 33, 0.9, 8.1, 0,
          fiber: 0.1, sodium: 1, portion: 200, aliases: ['melancia']),
      _f('uva', 'Uva', 'Frutas', 53, 0.7, 13.6, 0.2,
          fiber: 0.9, sodium: 1, portion: 120, aliases: ['uva', 'uvas']),
      _f('abacaxi', 'Abacaxi', 'Frutas', 48, 0.9, 12.3, 0.1,
          fiber: 1.0, sodium: 1, portion: 100, aliases: ['abacaxi']),
      _f('morango', 'Morango', 'Frutas', 30, 0.9, 6.8, 0.3,
          fiber: 1.7, sodium: 1, portion: 100, aliases: ['morangos']),
      _f('manga', 'Manga', 'Frutas', 64, 0.4, 17.2, 0.2,
          fiber: 2.1, sodium: 3, portion: 100, aliases: ['manga']),
      _f('kiwi', 'Kiwi', 'Frutas', 51, 1.3, 11.5, 0.6,
          fiber: 2.7, sodium: 1, portion: 80, aliases: ['kiwi']),
      _f('pera', 'Pêra', 'Frutas', 53, 0.6, 14.0, 0.1,
          fiber: 3.0, sodium: 1, portion: 100, aliases: ['pera']),
      _f('limao', 'Limão', 'Frutas', 32, 0.9, 8.4, 0.1,
          fiber: 0.8, sodium: 1, portion: 60, aliases: ['limao', 'limao taiti']),
      _f('goiaba', 'Goiaba', 'Frutas', 54, 1.1, 13.0, 0.4,
          fiber: 6.2, sodium: 2, portion: 100, aliases: ['goiaba']),
      _f('tangerina', 'Tangerina', 'Frutas', 38, 0.8, 9.6, 0.1,
          fiber: 1.0, sodium: 1, portion: 100, aliases: ['mexerica', 'bergamota', 'tangerina']),
      _f('acai-polpa', 'Açaí (polpa)', 'Frutas', 58, 0.8, 6.2, 3.9,
          fiber: 2.6, sodium: 4, portion: 100, aliases: ['acai', 'acai puro']),

      // ───────────── LEGUMES E VERDURAS ─────────────
      _f('tomate', 'Tomate', 'Legumes e verduras', 15, 1.1, 3.1, 0.2,
          fiber: 1.2, sodium: 1, portion: 100, aliases: ['tomate']),
      _f('alface', 'Alface', 'Legumes e verduras', 11, 1.3, 1.7, 0.2,
          fiber: 1.8, sodium: 5, portion: 50, aliases: ['alface']),
      _f('brocolis', 'Brócolis cozido', 'Legumes e verduras', 25, 2.1, 4.4, 0.5,
          fiber: 3.4, sodium: 6, portion: 100, aliases: ['brocolis']),
      _f('cenoura', 'Cenoura crua', 'Legumes e verduras', 34, 1.3, 7.7, 0.2,
          fiber: 3.2, sodium: 17, portion: 60, aliases: ['cenoura']),
      _f('batata-doce', 'Batata-doce cozida', 'Legumes e verduras', 77, 0.6, 18.4, 0.1,
          fiber: 2.2, sodium: 5, portion: 150, aliases: ['batata doce']),
      _f('batata', 'Batata cozida', 'Legumes e verduras', 52, 1.2, 11.9, 0,
          fiber: 1.3, sodium: 4, portion: 150, aliases: ['batata inglesa', 'batata cozida']),
      _f('batata-frita', 'Batata frita', 'Legumes e verduras', 267, 4.9, 31.9, 13.6,
          fiber: 3.1, sodium: 301, portion: 100, aliases: ['batata frita', 'fritas']),
      _f('mandioca', 'Mandioca cozida', 'Legumes e verduras', 125, 0.6, 30.1, 0.3,
          fiber: 1.4, sodium: 1, portion: 150, aliases: ['aipim', 'macaxeira']),
      _f('abobora', 'Abóbora cabotiá cozida', 'Legumes e verduras', 48, 1.1, 11.8, 0.2,
          fiber: 2.2, sodium: 2, portion: 100, aliases: ['abobora', 'cabotia', 'moranga']),
      _f('couve', 'Couve refogada', 'Legumes e verduras', 111, 3.0, 12.7, 6.3,
          fiber: 4.3, sodium: 59, portion: 60, aliases: ['couve refogada', 'couve']),
      _f('couve-flor', 'Couve-flor cozida', 'Legumes e verduras', 20, 1.2, 4.0, 0.2,
          fiber: 2.1, sodium: 15, portion: 100, aliases: ['couve flor']),
      _f('chuchu', 'Chuchu cozido', 'Legumes e verduras', 24, 0.5, 5.6, 0.1,
          fiber: 1.0, sodium: 4, portion: 100, aliases: ['chuchu']),
      _f('abobrinha', 'Abobrinha cozida', 'Legumes e verduras', 15, 0.8, 3.4, 0.1,
          fiber: 0.9, sodium: 2, portion: 100, aliases: ['abobrinha italiana']),
      _f('pimentao', 'Pimentão', 'Legumes e verduras', 21, 1.0, 4.9, 0.1,
          fiber: 2.6, sodium: 1, portion: 80, aliases: ['pimentao']),
      _f('pepino', 'Pepino', 'Legumes e verduras', 10, 0.6, 2.2, 0.1,
          fiber: 0.7, sodium: 1, portion: 80, aliases: ['pepino']),
      _f('espinafre', 'Espinafre refogado', 'Legumes e verduras', 69, 3.8, 7.4, 3.1,
          fiber: 3.9, sodium: 46, portion: 60, aliases: ['espinafre']),
      _f('milho-verde', 'Milho verde em conserva', 'Legumes e verduras', 98, 3.2, 17.1, 2.4,
          fiber: 3.9, sodium: 280, portion: 100, aliases: ['milho', 'milho verde']),
      _f('beterraba', 'Beterraba crua', 'Legumes e verduras', 49, 1.9, 11.1, 0.1,
          fiber: 3.4, sodium: 53, portion: 80, aliases: ['beterraba']),
      _f('cebola', 'Cebola', 'Legumes e verduras', 39, 1.7, 8.9, 0.1,
          fiber: 2.2, sodium: 3, portion: 50, aliases: ['cebola']),

      // ───────────── NOZES E SEMENTES ─────────────
      _f('castanha-caju', 'Castanha-de-caju torrada', 'Oleaginosas', 570, 18.5, 29.1, 46.3,
          fiber: 3.7, sodium: 390, portion: 30, aliases: ['castanha de caju', 'castanha']),
      _f('amendoim', 'Amendoim torrado', 'Oleaginosas', 606, 22.5, 18.1, 49.7,
          fiber: 7.6, sodium: 12, portion: 30, aliases: ['amendoim']),
      _f('amendoa', 'Amêndoa', 'Oleaginosas', 579, 18.6, 15.3, 49.9,
          fiber: 10.9, sodium: 3, portion: 30, aliases: ['amendoas', 'amêndoa']),
      _f('castanha-para', 'Castanha-do-pará', 'Oleaginosas', 643, 14.5, 15.1, 63.5,
          fiber: 7.9, sodium: 3, portion: 30, aliases: ['castanha do para', 'castanha do brasil']),
      _f('noz', 'Noz', 'Oleaginosas', 620, 14.7, 12.5, 60.6,
          fiber: 5.5, sodium: 2, portion: 30, aliases: ['nozes']),
      _f('chia', 'Semente de chia', 'Oleaginosas', 486, 16.5, 42.1, 30.7,
          fiber: 34.4, sodium: 16, portion: 15, aliases: ['chia']),
      _f('linhaca', 'Linhaça', 'Oleaginosas', 495, 14.1, 43.3, 32.3,
          fiber: 27.3, sodium: 30, portion: 15, aliases: ['linhaca']),
      _f('pasta-amendoim', 'Pasta de amendoim', 'Oleaginosas', 588, 25.1, 19.6, 49.9,
          fiber: 8.0, sodium: 470, portion: 32, aliases: ['creme de amendoim', 'peanut butter']),

      // ───────────── AÇÚCARES, DOCES E PREPARADOS ─────────────
      _f('acucar', 'Açúcar refinado', 'Açúcares e doces', 387, 0, 99.9, 0,
          sodium: 1, portion: 5, aliases: ['acucar', 'açúcar']),
      _f('mel', 'Mel', 'Açúcares e doces', 309, 0.3, 84.0, 0,
          sodium: 6, portion: 20, aliases: ['mel']),
      _f('chocolate-ao-leite', 'Chocolate ao leite', 'Açúcares e doces', 540, 7.2, 59.4, 30.3,
          fiber: 2.1, sodium: 90, portion: 25, aliases: ['chocolate', 'chocolate ao leite']),
      _f('achocolatado', 'Achocolatado em pó', 'Açúcares e doces', 401, 4.7, 90.9, 1.9,
          fiber: 1.4, sodium: 107, portion: 20, aliases: ['achocolatado', 'toddy', 'nescau']),
      _f('sorvete', 'Sorvete de creme', 'Açúcares e doces', 214, 2.9, 25.8, 11.2,
          fiber: 0.5, sodium: 57, portion: 60, aliases: ['sorvete']),
      _f('bolo-chocolate', 'Bolo de chocolate', 'Açúcares e doces', 410, 6.2, 54.3, 19.1,
          fiber: 1.4, sodium: 198, portion: 80, aliases: ['bolo de chocolate', 'bolo']),
      _f('biscoito-cream', 'Biscoito cream cracker', 'Açúcares e doces', 432, 9.9, 68.7, 13.1,
          fiber: 2.7, sodium: 797, portion: 30, aliases: ['cream cracker', 'biscoito salgado']),
      _f('salgadinho', 'Salgadinho de milho', 'Açúcares e doces', 537, 6.5, 57.1, 31.6,
          fiber: 2.2, sodium: 918, portion: 25, aliases: ['salgadinho', 'chips']),
      _f('brigadeiro', 'Brigadeiro', 'Açúcares e doces', 433, 4.8, 59.3, 20.4,
          fiber: 2.5, sodium: 105, portion: 20, aliases: ['brigadeiro']),
      _f('pudim', 'Pudim de leite', 'Açúcares e doces', 227, 5.3, 31.3, 9.5,
          fiber: 0.7, sodium: 135, portion: 80, aliases: ['pudim']),

      // ───────────── BEBIDAS ─────────────
      _f('cafe', 'Café (sem açúcar)', 'Bebidas', 3, 0.2, 0.6, 0,
          sodium: 2, portion: 50, aliases: ['cafe preto', 'cafe sem acucar', 'cafezinho']),
      _f('cafe-acucar', 'Café com açúcar', 'Bebidas', 39, 0.2, 9.9, 0,
          sodium: 2, portion: 50, aliases: ['cafe com acucar']),
      _f('refrigerante', 'Refrigerante cola', 'Bebidas', 42, 0, 10.6, 0,
          sodium: 5, portion: 200, aliases: ['coca cola', 'coca', 'refrigerante', 'guarana']),
      _f('suco-laranja', 'Suco de laranja natural', 'Bebidas', 43, 0.8, 10.1, 0.1,
          fiber: 0.3, sodium: 1, portion: 200, aliases: ['suco de laranja']),
      _f('agua-coco', 'Água de coco', 'Bebidas', 22, 0.2, 5.3, 0.1,
          fiber: 0.1, sodium: 22, portion: 200, aliases: ['agua de coco']),
      _f('cerveja', 'Cerveja', 'Bebidas alcoólicas', 41, 0.5, 3.3, 0,
          sodium: 5, portion: 350, aliases: ['cerveja']),
      _f('vinho', 'Vinho tinto', 'Bebidas alcoólicas', 85, 0.4, 5.6, 0,
          sodium: 5, portion: 150, aliases: ['vinho', 'vinho tinto']),

      // ───────────── PRATOS E PREPARADOS BRASILEIROS ─────────────
      _f('feijoada', 'Feijoada', 'Pratos prontos', 114, 7.6, 10.5, 4.5,
          fiber: 3.6, sodium: 393, portion: 250, aliases: ['feijoada']),
      _f('farofa', 'Farofa de farinha de mandioca', 'Pratos prontos', 383, 4.0, 58.4, 14.6,
          fiber: 6.8, sodium: 193, portion: 40, aliases: ['farofa']),
      _f('estrogonofe', 'Estrogonofe de frango', 'Pratos prontos', 166, 11.5, 9.5, 9.5,
          fiber: 0.5, sodium: 234, portion: 200, aliases: ['strogonoff', 'estrogonofe de frango', 'strogonoff de frango']),
      _f('lasanha', 'Lasanha à bolonhesa', 'Pratos prontos', 164, 9.7, 12.4, 8.6,
          fiber: 0.7, sodium: 210, portion: 250, aliases: ['lasanha']),
      _f('coxinha', 'Coxinha de frango', 'Pratos prontos', 276, 6.5, 30.9, 14.9,
          fiber: 1.4, sodium: 399, portion: 60, aliases: ['coxinha']),
      _f('pastel', 'Pastel de carne frito', 'Pratos prontos', 300, 7.8, 32.6, 15.4,
          fiber: 1.2, sodium: 379, portion: 60, aliases: ['pastel']),
      _f('pao-queijo', 'Pão de queijo', 'Pratos prontos', 363, 6.4, 36.4, 21.6,
          fiber: 1.2, sodium: 411, portion: 40, aliases: ['pao de queijo']),
      _f('tapioca', 'Tapioca', 'Pratos prontos', 171, 0.5, 41.1, 0.2,
          fiber: 1.1, sodium: 65, portion: 100, aliases: ['beiju']),
      _f('pizza-mussarela', 'Pizza de mussarela', 'Pratos prontos', 269, 10.6, 31.8, 11.3,
          fiber: 1.5, sodium: 478, portion: 100, aliases: ['pizza', 'pizza de queijo']),
      _f('sopa-legumes', 'Sopa de legumes', 'Pratos prontos', 44, 1.9, 8.6, 0.6,
          fiber: 2.5, sodium: 25, portion: 250, aliases: ['sopa de legumes', 'sopa']),
      _f('arroz-feijao', 'Arroz com feijão', 'Pratos prontos', 105, 3.6, 20.8, 0.3,
          fiber: 5.0, sodium: 122, portion: 250, aliases: ['maravilha', 'arroz e feijao', 'pf']),
      _f('strogonoff-carne', 'Estrogonofe de carne', 'Pratos prontos', 181, 13.1, 10.4, 9.8,
          fiber: 0.5, sodium: 240, portion: 200, aliases: ['estrogonofe de carne']),
      _f('virado-paulista', 'Virado à paulista', 'Pratos prontos', 150, 7.2, 18.0, 5.4,
          fiber: 3.8, sodium: 310, portion: 200, aliases: ['virado']),
      _f('acai-xarope', 'Açaí com xarope e guaraná', 'Pratos prontos', 119, 0.6, 19.4, 4.6,
          fiber: 1.2, sodium: 2, portion: 100, aliases: ['acai', 'acai na tigela']),
    ];
  }
}