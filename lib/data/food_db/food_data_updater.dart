import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/food.dart';
import 'food_database.dart';

class FoodDataUpdateResult {
  const FoodDataUpdateResult({required this.updated, required this.revision});

  final bool updated;
  final int revision;
}

class FoodDataUpdater {
  FoodDataUpdater({
    required http.Client client,
    required SharedPreferences preferences,
    required this.manifestUri,
  })  : _client = client,
        _preferences = preferences;

  static const supportedSchemaVersion = 1;

  final http.Client _client;
  final SharedPreferences _preferences;
  final Uri manifestUri;

  bool loadCached() {
    final activeSlot = _preferences.getString('food_db.active_slot');
    final revision = _preferences.getInt('food_db.revision');
    if (activeSlot == null || revision == null) return false;
    final payload = _preferences.getString('food_db.slot_$activeSlot.payload');
    if (payload == null) return false;
    try {
      FoodDatabase.installOverlay(_parseFoods(payload), revision: revision);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<FoodDataUpdateResult> checkForUpdates() async {
    final manifestResponse = await _client.get(manifestUri).timeout(
          const Duration(seconds: 20),
        );
    if (manifestResponse.statusCode != 200) {
      throw StateError('Manifesto indisponível (${manifestResponse.statusCode}).');
    }
    final manifestRaw = utf8.decode(manifestResponse.bodyBytes);
    final manifest = _asMap(jsonDecode(manifestRaw), 'manifesto');
    final schemaVersion = _requiredInt(manifest, 'schemaVersion');
    if (schemaVersion != supportedSchemaVersion) {
      throw StateError('Schema de dados não suportado: $schemaVersion.');
    }
    final revision = _requiredInt(manifest, 'revision');
    final currentRevision = _preferences.getInt('food_db.revision') ?? 0;
    if (revision <= currentRevision) {
      return FoodDataUpdateResult(updated: false, revision: currentRevision);
    }

    final dataUrl = Uri.parse(_requiredString(manifest, 'dataUrl'));
    final expectedHash = _requiredString(manifest, 'sha256').toLowerCase();
    final payloadResponse = await _client.get(dataUrl).timeout(
          const Duration(seconds: 30),
        );
    if (payloadResponse.statusCode != 200) {
      throw StateError('Pacote de dados indisponível (${payloadResponse.statusCode}).');
    }
    final actualHash = sha256.convert(payloadResponse.bodyBytes).toString();
    if (actualHash != expectedHash) {
      throw StateError('O pacote de dados falhou na verificação SHA-256.');
    }

    final payloadRaw = utf8.decode(payloadResponse.bodyBytes);
    final foods = _parseFoods(payloadRaw);
    final activeSlot = _preferences.getString('food_db.active_slot') ?? 'a';
    final inactiveSlot = activeSlot == 'a' ? 'b' : 'a';
    await _preferences.setString('food_db.slot_$inactiveSlot.manifest', manifestRaw);
    await _preferences.setString('food_db.slot_$inactiveSlot.payload', payloadRaw);
    await _preferences.setInt('food_db.revision', revision);
    await _preferences.setString('food_db.active_slot', inactiveSlot);

    FoodDatabase.installOverlay(foods, revision: revision);
    return FoodDataUpdateResult(updated: true, revision: revision);
  }

  List<Food> _parseFoods(String raw) {
    final payload = _asMap(jsonDecode(raw), 'pacote');
    final values = payload['foods'];
    if (values is! List || values.isEmpty) {
      throw StateError('O pacote precisa conter uma lista não vazia de alimentos.');
    }
    final ids = <String>{};
    final foods = <Food>[];
    for (final value in values) {
      final map = _asMap(value, 'alimento');
      for (final key in const [
        'id',
        'name',
        'category',
        'source',
        'kcal',
        'protein',
        'carbs',
        'fat',
      ]) {
        if (!map.containsKey(key)) {
          throw StateError('Campo obrigatório ausente no alimento: $key.');
        }
      }
      final id = _requiredString(map, 'id');
      if (!ids.add(id)) throw StateError('ID de alimento duplicado: $id.');
      _requiredString(map, 'name');
      _requiredString(map, 'category');
      _requiredString(map, 'source');
      for (final key in const [
        'kcal',
        'protein',
        'carbs',
        'fat',
        'fiber',
        'sodium',
        'standardPortionGrams',
      ]) {
        final value = map[key];
        if (value == null && !const {'fiber', 'sodium', 'standardPortionGrams'}.contains(key)) {
          throw StateError('Nutriente obrigatório ausente: $key.');
        }
        if (value != null) {
          if (value is! num || !value.toDouble().isFinite || value < 0) {
            throw StateError('Valor inválido para $key no alimento $id.');
          }
        }
      }
      foods.add(Food.fromJson(map));
    }
    return foods;
  }

  Map<String, dynamic> _asMap(Object? value, String label) {
    if (value is! Map<String, dynamic>) {
      throw StateError('Formato inválido para $label.');
    }
    return value;
  }

  String _requiredString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String || value.trim().isEmpty) {
      throw StateError('Campo textual inválido: $key.');
    }
    return value.trim();
  }

  int _requiredInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! num || value.toInt() != value) {
      throw StateError('Campo inteiro inválido: $key.');
    }
    return value.toInt();
  }
}
