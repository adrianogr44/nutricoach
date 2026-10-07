import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutricoach_ai/data/food_db/open_food_facts_api.dart';

void main() {
  test('consulta produto pela API v3 com User-Agent identificável', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'status': 'success',
          'product': {
            'code': '7891000000000',
            'product_name': 'Produto teste',
            'nutriments': {'energy-kcal_100g': 100},
          },
        }),
        200,
      );
    });
    final api = OpenFoodFactsApi(client: client);

    final food = await api.byBarcode('7891000000000');

    expect(food, isNotNull);
    expect(captured.url.path, '/api/v3/product/7891000000000.json');
    expect(captured.headers['User-Agent'], contains('NutriCoach/'));
  });

  test('converte energia em kJ para kcal quando kcal não existe', () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({
            'status': 'success',
            'product': {
              'product_name': 'Produto em kJ',
              'nutriments': {
                'energy_100g': 418.4,
                'sodium_100g': 0.25,
              },
            },
          }),
          200,
        ));
    final food = await OpenFoodFactsApi(client: client).byBarcode('123');

    expect(food?.kcal, closeTo(100, 0.01));
  });

  test('converte sódio de gramas para miligramas', () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({
            'status': 'success',
            'product': {
              'product_name': 'Produto com sódio',
              'nutriments': {
                'energy-kcal_100g': 50,
                'sodium_100g': 0.25,
              },
            },
          }),
          200,
        ));
    final food = await OpenFoodFactsApi(client: client).byBarcode('456');

    expect(food?.sodium, 250);
  });

  test('busca solicita código para produzir IDs persistentes', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'products': [
            {
              'code': '789',
              'product_name': 'Busca teste',
              'nutriments': {'energy-kcal_100g': 10},
            },
          ],
        }),
        200,
      );
    });

    final foods = await OpenFoodFactsApi(client: client).search('teste');

    expect(captured.url.queryParameters['fields'], contains('code'));
    expect(foods.single.id, 'off-789');
  });

  test('reutiliza produto em cache sem repetir a chamada HTTP', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response(
        jsonEncode({
          'status': 'success',
          'product': {
            'product_name': 'Produto cacheado',
            'nutriments': {'energy-kcal_100g': 10},
          },
        }),
        200,
      );
    });
    final api = OpenFoodFactsApi(client: client);

    await api.byBarcode('999');
    await api.byBarcode('999');

    expect(calls, 1);
  });

  test('normaliza energia dos resultados de busca', () async {
    final client = MockClient((_) async => http.Response(
          jsonEncode({
            'products': [
              {
                'code': '321',
                'product_name': 'Busca em kJ',
                'nutriments': {'energy_100g': 836.8},
              },
            ],
          }),
          200,
        ));

    final foods = await OpenFoodFactsApi(client: client).search('busca');

    expect(foods.single.kcal, closeTo(200, 0.01));
  });
}
