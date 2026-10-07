import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/food.dart';
import '../../core/constants.dart';

/// Busca de alimentos industrializados via API pública do Open Food Facts
/// (banco colaborativo). Usado como FONTE EXTERNA VALIDADA para produtos
/// com código de barras. Nunca inventa valores.
class OpenFoodFactsApi {
  OpenFoodFactsApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, Food> _barcodeCache = {};
  static const _headers = {
    'User-Agent': 'NutriCoach/1.0 (contato: suporte@nutricoach.app)',
  };

  /// Busca produto por código de barras (EAN).
  Future<Food?> byBarcode(String barcode) async {
    final cached = _barcodeCache[barcode];
    if (cached != null) return cached;
    final uri = Uri.parse(
      '${AppConstants.openFoodFactsBase}/product/$barcode.json?fields=code,product_name,brands,categories_tags,nutriments,image_front_url',
    );
    try {
      final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final status = data['status'];
      if (status != 1 && status != 'success') return null;
      final product = data['product'] as Map<String, dynamic>?;
      if (product == null) return null;

      final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};

      double getValue(String key, [String? sub]) {
        var v = nutriments['$key${sub == null ? '_100g' : ''}'];
        if (sub == null && (v == null || v == 'null')) {
          v = nutriments[key];
        }
        if (v == null || v == 'null') return 0;
        return double.tryParse(v.toString()) ?? 0;
      }

      final name = (product['product_name'] as String?)?.trim() ?? 'Produto $barcode';
      final energyKcal = getValue('energy-kcal');
      final energy = energyKcal > 0 ? energyKcal : getValue('energy') / 4.184;
      final food = Food(
        id: 'off-$barcode',
        name: name,
        category: (product['categories_tags'] as List?)?.isNotEmpty == true
            ? ((product['categories_tags'] as List).first as String)
                .replaceAll('en:', '')
                .replaceAll('pt:', '')
                .split('-')
                .map((p) => p[0].toUpperCase() + p.substring(1))
                .join(' ')
            : 'Industrializados',
        kcal: energy,
        protein: getValue('proteins'),
        carbs: getValue('carbohydrates'),
        fat: getValue('fat'),
        fiber: getValue('fiber'),
        sodium: getValue('sodium') * 1000,
        standardPortionGrams: 100,
        source: 'OpenFoodFacts',
        barcode: barcode,
        brand: product['brands'] as String?,
      );
      _barcodeCache[barcode] = food;
      return food;
    } catch (_) {
      return null;
    }
  }

  /// Busca por nome/texto (fallback para itens não encontrados no banco).
  Future<List<Food>> search(String query) async {
    final uri = Uri.parse(
      '${AppConstants.openFoodFactsBase}/search?search_terms=${Uri.encodeQueryComponent(query)}'
      '&fields=code,product_name,brands,categories_tags,nutriments&page_size=20',
    );
    try {
      final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final products = data['products'] as List? ?? [];
      final foods = <Food>[];
      for (final p in products.take(20)) {
        final map = p as Map<String, dynamic>;
        final nutriments = map['nutriments'] as Map<String, dynamic>? ?? {};
        double gv(String key) {
          var v = nutriments['${key}_100g'];
          if (v == null || v == 'null') v = nutriments[key];
          return double.tryParse(v.toString()) ?? 0;
        }

        final barcode = map['code'] as String?;
        final name = (map['product_name'] as String?)?.trim();
        if (name == null || name.isEmpty) continue;
        foods.add(Food(
          id: 'off-${barcode ?? name.hashCode}',
          name: name,
          category: 'Industrializados',
          kcal: gv('energy-kcal') > 0 ? gv('energy-kcal') : gv('energy') / 4.184,
          protein: gv('proteins'),
          carbs: gv('carbohydrates'),
          fat: gv('fat'),
          fiber: gv('fiber'),
          sodium: gv('sodium'),
          standardPortionGrams: 100,
          source: 'OpenFoodFacts',
          barcode: barcode,
          brand: map['brands'] as String?,
        ));
      }
      return foods;
    } catch (_) {
      return [];
    }
  }
}