import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persistência local (source of truth offline-first).
/// Todos os dados são guardados em JSON no dispositivo. Quando o Firebase
/// estiver configurado, o [CloudStore] sincroniza lado a lado.
class LocalStore {
  LocalStore._(this._prefs);

  final SharedPreferences _prefs;

  static const _kProfile = 'profile';
  static const _kMeals = 'meals';
  static const _kWorkouts = 'workouts';
  static const _kWeights = 'weights';
  static const _kMeasurements = 'measurements';
  static const _kPhotos = 'photos';
  static const _kWater = 'water';
  static const _kFavorites = 'favorites';
  static const _kCustomFoods = 'custom_foods';
  static const _kUserEmail = 'user_email';
  static const _kBioimpedances = 'bioimpedances';
  static const _kDietPlans = 'diet_plans';
  static const _kActiveDietId = 'active_diet_id';
  static const _kTrainingPlans = 'training_plans';
  static const _kActiveTrainingPlanId = 'active_training_plan_id';
  static const _kTrainingSessions = 'training_sessions';

  static Future<LocalStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStore._(prefs);
  }

  List<Map<String, dynamic>> _read(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> _write(String key, List<Map<String, dynamic>> value) {
    return _prefs.setString(key, jsonEncode(value));
  }

  Future<void> clear() {
    return _prefs.clear();
  }

  // ── Perfil ──
  Map<String, dynamic>? get profile {
    final raw = _prefs.getString(_kProfile);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> setProfile(Map<String, dynamic> json) =>
      _prefs.setString(_kProfile, jsonEncode(json));

  // ── Refeições ──
  List<Map<String, dynamic>> get meals => _read(_kMeals);
  Future<void> setMeals(List<Map<String, dynamic>> value) => _write(_kMeals, value);

  // ── Treinos ──
  List<Map<String, dynamic>> get workouts => _read(_kWorkouts);
  Future<void> setWorkouts(List<Map<String, dynamic>> value) => _write(_kWorkouts, value);

  // ── Pesos ──
  List<Map<String, dynamic>> get weights => _read(_kWeights);
  Future<void> setWeights(List<Map<String, dynamic>> value) => _write(_kWeights, value);

  // ── Medidas ──
  List<Map<String, dynamic>> get measurements => _read(_kMeasurements);
  Future<void> setMeasurements(List<Map<String, dynamic>> value) =>
      _write(_kMeasurements, value);

  // ── Bioimpedâncias ──
  List<Map<String, dynamic>> get bioimpedances => _read(_kBioimpedances);
  Future<void> setBioimpedances(List<Map<String, dynamic>> value) =>
      _write(_kBioimpedances, value);

  // ── Fotos de evolução ──
  List<Map<String, dynamic>> get photos => _read(_kPhotos);
  Future<void> setPhotos(List<Map<String, dynamic>> value) => _write(_kPhotos, value);

  // ── Água ──
  List<Map<String, dynamic>> get water => _read(_kWater);
  Future<void> setWater(List<Map<String, dynamic>> value) => _write(_kWater, value);

  // ── Favoritos (ids de alimentos) ──
  List<String> get favoriteIds {
    final raw = _prefs.getString(_kFavorites);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).whereType<String>().toList();
  }

  Future<void> setFavoriteIds(List<String> ids) =>
      _prefs.setString(_kFavorites, jsonEncode(ids));

  // ── Alimentos customizados (importados de OpenFoodFacts) ──
  List<Map<String, dynamic>> get customFoods => _read(_kCustomFoods);
  Future<void> setCustomFoods(List<Map<String, dynamic>> value) =>
      _write(_kCustomFoods, value);

  // ── Dieta planejada ──
  List<Map<String, dynamic>> get dietPlans => _read(_kDietPlans);
  Future<void> setDietPlans(List<Map<String, dynamic>> value) => _write(_kDietPlans, value);

  String? get activeDietId => _prefs.getString(_kActiveDietId);
  Future<void> setActiveDietId(String? value) =>
      value == null ? _prefs.remove(_kActiveDietId) : _prefs.setString(_kActiveDietId, value);

  // ── Treino ──
  List<Map<String, dynamic>> get trainingPlans => _read(_kTrainingPlans);
  Future<void> setTrainingPlans(List<Map<String, dynamic>> value) => _write(_kTrainingPlans, value);
  String? get activeTrainingPlanId => _prefs.getString(_kActiveTrainingPlanId);
  Future<void> setActiveTrainingPlanId(String? value) =>
      value == null ? _prefs.remove(_kActiveTrainingPlanId) : _prefs.setString(_kActiveTrainingPlanId, value);
  List<Map<String, dynamic>> get trainingSessions => _read(_kTrainingSessions);
  Future<void> setTrainingSessions(List<Map<String, dynamic>> value) => _write(_kTrainingSessions, value);

  // ── Usuário autenticado (email de demo) ──
  String? get userEmail => _prefs.getString(_kUserEmail);
  Future<void> setUserEmail(String? value) =>
      value == null ? _prefs.remove(_kUserEmail) : _prefs.setString(_kUserEmail, value);
}