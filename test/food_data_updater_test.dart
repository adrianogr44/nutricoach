import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutricoach_ai/data/food_db/food_data_updater.dart';
import 'package:nutricoach_ai/data/food_db/food_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('instala atualização íntegra em slot inativo e ativa o catálogo', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'foods': [
        {
          'id': 'remote-banana',
          'name': 'Banana atualizada',
          'category': 'Frutas',
          'kcal': 90,
          'protein': 1.1,
          'carbs': 23,
          'fat': 0.3,
          'fiber': 2.6,
          'sodium': 1,
          'standardPortionGrams': 100,
          'aliases': ['banana remota'],
          'source': 'Catálogo NutriCoach 2026.09',
        },
      ],
    });
    final hash = sha256.convert(utf8.encode(payload)).toString();
    final client = MockClient((request) async {
      if (request.url.path.endsWith('manifest.json')) {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'schemaVersion': 1,
            'revision': 2026090301,
            'dataUrl': 'https://dados.example/foods.json',
            'sha256': hash,
            'generatedAt': '2026-09-03T00:00:00Z',
          })),
          200,
        );
      }
      return http.Response.bytes(utf8.encode(payload), 200);
    });
    final updater = FoodDataUpdater(
      client: client,
      preferences: preferences,
      manifestUri: Uri.parse('https://dados.example/manifest.json'),
    );

    final result = await updater.checkForUpdates();

    expect(result.updated, isTrue);
    expect(result.revision, 2026090301);
    expect(preferences.getString('food_db.active_slot'), 'b');
    expect(FoodDatabase.byId('remote-banana')?.name, 'Banana atualizada');
  });

  test('carrega o último slot ativo sem acessar a rede', () async {
    final payload = jsonEncode({
      'foods': [
        {
          'id': 'offline-food',
          'name': 'Alimento em cache',
          'category': 'Outros',
          'kcal': 100,
          'protein': 2,
          'carbs': 20,
          'fat': 1,
          'source': 'Cache versionado',
        },
      ],
    });
    SharedPreferences.setMockInitialValues({
      'food_db.active_slot': 'a',
      'food_db.revision': 7,
      'food_db.slot_a.payload': payload,
    });
    final preferences = await SharedPreferences.getInstance();
    final updater = FoodDataUpdater(
      client: MockClient((_) async => throw StateError('sem rede')),
      preferences: preferences,
      manifestUri: Uri.parse('https://dados.example/manifest.json'),
    );

    final loaded = updater.loadCached();

    expect(loaded, isTrue);
    expect(FoodDatabase.revision, 7);
    expect(FoodDatabase.byId('offline-food')?.name, 'Alimento em cache');
  });
}
