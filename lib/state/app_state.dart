import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../core/utils/nutrition_calculator.dart';
import '../data/food_db/food_database.dart';
import '../data/models/body_track.dart';
import '../data/models/bioimpedance.dart';
import '../data/models/daily_summary.dart';
import '../data/models/food.dart';
import '../data/models/meal.dart';
import '../data/models/tracking.dart';
import '../data/models/training.dart';
import '../data/models/user_profile.dart';
import '../data/repositories/cloud_sync.dart';
import '../data/repositories/local_store.dart';
import '../services/bioimpedance_text_parser.dart';
import '../services/diet_transfer.dart';
import '../services/household_measure.dart';
import '../services/insight_rules_engine.dart';
import '../services/meal_text_parser.dart';
import '../services/nutrition_label_text_parser.dart';
import '../data/models/diet.dart';

/// Estado central do app (ChangeNotifier). Offline-first com persistência
/// local; pronto para sincronizar com Firestore quando configurado.
class AppState extends ChangeNotifier {
  AppState(this._store);

  final LocalStore _store;
  final Uuid _uuid = const Uuid();

  /// Serviços locais (sem IA).
  late final MealTextParser mealParser = const MealTextParser();
  late final InsightRulesEngine insights = const InsightRulesEngine();
  late final BioimpedanceTextParser bioimpedanceParser = const BioimpedanceTextParser();
  late final NutritionLabelTextParser labelParser = const NutritionLabelTextParser();

  // ── Dados em memória ──
  bool _initialized = false;
  bool get initialized => _initialized;

  UserProfile? _profile;
  UserProfile? get profile => _profile;

  List<Meal> _meals = [];
  List<Workout> _workouts = [];
  List<WeightRecord> _weights = [];
  List<BodyMeasurement> _measurements = [];
  List<ProgressPhoto> _photos = [];
  List<WaterRecord> _water = [];
  List<Bioimpedance> _bioimpedances = [];
  List<String> _favoriteIds = [];
  List<Food> _customFoods = [];
  String? _userEmail;

  List<DietPlan> _dietPlans = [];
  String? _activeDietId;

  List<TrainingPlan> _trainingPlans = [];
  String? _activeTrainingPlanId;
  List<TrainingSession> _trainingSessions = [];

  bool _saving = false;
  String _statusMessage = '';
  bool get saving => _saving;
  String get statusMessage => _statusMessage;

  // ── Getters ──
  List<Meal> get meals => List.unmodifiable(_meals);
  List<Workout> get workouts => List.unmodifiable(_workouts);
  List<WeightRecord> get weights => List.unmodifiable(_weights);
  List<BodyMeasurement> get measurements => List.unmodifiable(_measurements);
  List<ProgressPhoto> get photos => List.unmodifiable(_photos);
  List<WaterRecord> get water => List.unmodifiable(_water);
  List<Bioimpedance> get bioimpedances => List.unmodifiable(_bioimpedances);
  String? get userEmail => _userEmail;

  List<Food> get favorites => [
        for (final id in _favoriteIds)
          if (FoodDatabase.byId(id) != null) FoodDatabase.byId(id)!,
        for (final f in _customFoods)
          if (_favoriteIds.contains(f.id)) f,
      ];

  List<Food> get customFoods => List.unmodifiable(_customFoods);
  bool get hasProfile => _profile != null;

  // ── Dieta ──
  List<DietPlan> get dietPlans => List.unmodifiable(_dietPlans);
  DietPlan? get activeDiet {
    if (_dietPlans.isEmpty) return null;
    if (_activeDietId != null) {
      final found = _dietPlans.where((d) => d.id == _activeDietId).toList();
      if (found.isNotEmpty) return found.first;
    }
    return _dietPlans.firstWhere((d) => d.isActive, orElse: () => _dietPlans.first);
  }

  bool get hasDiet => activeDiet != null && activeDiet!.meals.isNotEmpty;

  // ── Treino ──
  List<TrainingPlan> get trainingPlans => List.unmodifiable(_trainingPlans);
  TrainingPlan? get activeTrainingPlan {
    if (_trainingPlans.isEmpty) return null;
    if (_activeTrainingPlanId != null) {
      final found = _trainingPlans.where((p) => p.id == _activeTrainingPlanId).toList();
      if (found.isNotEmpty) return found.first;
    }
    return _trainingPlans.firstWhere((p) => p.isActive, orElse: () => _trainingPlans.first);
  }
  bool get hasTrainingPlan => activeTrainingPlan != null && activeTrainingPlan!.days.isNotEmpty;
  List<TrainingSession> get trainingSessions => List.unmodifiable(_trainingSessions);
  TrainingSession? get activeTrainingSession {
    try { return _trainingSessions.firstWhere((s) => s.status == TrainingStatus.active); } catch (_) { return null; }
  }

  Map<String, Food> get _foodById {
    final map = <String, Food>{};
    for (final f in FoodDatabase.all) map[f.id] = f;
    for (final f in _customFoods) map[f.id] = f;
    return map;
  }

  Map<String, Food> get foodByIdMap => _foodById;

  Food? foodById(String id) => _foodById[id];

  // ── Inicialização ──
  Future<void> init() async {
    // Tenta conectar ao Firestore; se falhar, opera offline.
    unawaited(CloudSync.initialize());

    _profile = _store.profile != null
        ? UserProfile.fromJson(_store.profile!)
        : null;
    _meals = (_store.meals).map(Meal.fromJson).toList();
    _workouts = (_store.workouts).map(Workout.fromJson).toList();
    _weights = (_store.weights).map(WeightRecord.fromJson).toList();
    _measurements = (_store.measurements).map(BodyMeasurement.fromJson).toList();
    _photos = (_store.photos).map(ProgressPhoto.fromJson).toList();
    _water = (_store.water).map(WaterRecord.fromJson).toList();
    _bioimpedances = (_store.bioimpedances).map(Bioimpedance.fromJson).toList();
    _favoriteIds = _store.favoriteIds;
    _customFoods = (_store.customFoods).map(Food.fromJson).toList();
    _userEmail = _store.userEmail;
    _dietPlans = (_store.dietPlans).map(DietPlan.fromJson).toList();
    _activeDietId = _store.activeDietId;
    if (_dietPlans.isNotEmpty && _activeDietId == null) {
      _activeDietId = _dietPlans.first.id;
    }
    _trainingPlans = (_store.trainingPlans).map(TrainingPlan.fromJson).toList();
    _activeTrainingPlanId = _store.activeTrainingPlanId;
    if (_trainingPlans.isNotEmpty && _activeTrainingPlanId == null) {
      _activeTrainingPlanId = _trainingPlans.first.id;
    }
    _trainingSessions = (_store.trainingSessions).map(TrainingSession.fromJson).toList();
    _initialized = true;
    notifyListeners();
  }

  void _persist() {
    _store.setMeals(_meals.map((e) => e.toJson()).toList());
    _store.setWorkouts(_workouts.map((e) => e.toJson()).toList());
    _store.setWeights(_weights.map((e) => e.toJson()).toList());
    _store.setMeasurements(_measurements.map((e) => e.toJson()).toList());
    _store.setPhotos(_photos.map((e) => e.toJson()).toList());
    _store.setWater(_water.map((e) => e.toJson()).toList());
    _store.setBioimpedances(_bioimpedances.map((e) => e.toJson()).toList());
    _store.setFavoriteIds(_favoriteIds);
    _store.setCustomFoods(_customFoods.map((e) => e.toJson()).toList());
  }

  void _persistDiet() {
    _store.setDietPlans(_dietPlans.map((e) => e.toJson()).toList());
    _store.setActiveDietId(_activeDietId);
  }

  // ── Dieta ──
  Future<DietPlan> createDiet(String name) async {
    final plan = DietPlan(id: _uuid.v4(), name: name.trim().isEmpty ? 'Minha Dieta' : name.trim(), meals: [], createdAt: DateTime.now(), updatedAt: DateTime.now(), isActive: true);
    _dietPlans.add(plan);
    _activeDietId = plan.id;
    _persistDiet();
    notifyListeners();
    return plan;
  }

  Future<void> updateDiet(DietPlan plan) async {
    final idx = _dietPlans.indexWhere((d) => d.id == plan.id);
    if (idx < 0) return;
    _dietPlans[idx] = plan.copyWith(updatedAt: DateTime.now());
    _persistDiet();
    notifyListeners();
  }

  Future<void> deleteDiet(String id) async {
    _dietPlans.removeWhere((d) => d.id == id);
    if (_activeDietId == id) _activeDietId = _dietPlans.isNotEmpty ? _dietPlans.first.id : null;
    _persistDiet();
    notifyListeners();
  }

  Future<void> setActiveDiet(String id) async {
    if (!_dietPlans.any((d) => d.id == id)) return;
    _activeDietId = id;
    _persistDiet();
    notifyListeners();
  }

  /// Importa dieta exportada em outro dispositivo/navegador (JSON offline).
  ///
  /// [DietTransfer.decode] valida o arquivo e lança [FormatException] com
  /// mensagem amigável. Se já existir plano com o mesmo id, substitui
  /// (importar de novo não duplica); caso contrário cria um id novo.
  Future<DietPlan> importDiet(String raw) async {
    final plan = DietTransfer.decode(raw);
    // Mantém o id do arquivo quando ele não colide — importar de novo
    // substitui o mesmo plano em vez de duplicar. Sem id, gera um novo.
    final stored = plan.id.isEmpty
        ? DietPlan(
            id: _uuid.v4(),
            name: plan.name,
            meals: plan.meals,
            createdAt: plan.createdAt ?? DateTime.now(),
            updatedAt: DateTime.now(),
            isActive: true,
          )
        : plan;

    final idx = _dietPlans.indexWhere((d) => d.id == stored.id);
    if (idx >= 0) {
      _dietPlans[idx] = stored;
    } else {
      _dietPlans.add(stored);
    }
    _activeDietId = stored.id;
    _persistDiet();
    notifyListeners();
    return stored;
  }

  Future<DietMeal> addDietMeal(String planId, {required String name, String? time}) async {
    final pIdx = _dietPlans.indexWhere((d) => d.id == planId);
    if (pIdx < 0) throw StateError('Dieta não encontrada');
    final meal = DietMeal(id: _uuid.v4(), name: name.trim().isEmpty ? 'Refeição' : name.trim(), time: time, order: _dietPlans[pIdx].meals.length);
    final updatedMeals = [..._dietPlans[pIdx].meals, meal];
    _dietPlans[pIdx] = _dietPlans[pIdx].copyWith(meals: updatedMeals, updatedAt: DateTime.now());
    _persistDiet();
    notifyListeners();
    return meal;
  }

  Future<void> updateDietMeal(String planId, DietMeal meal) async {
    final pIdx = _dietPlans.indexWhere((d) => d.id == planId);
    if (pIdx < 0) return;
    final mIdx = _dietPlans[pIdx].meals.indexWhere((m) => m.id == meal.id);
    if (mIdx < 0) return;
    final meals = [..._dietPlans[pIdx].meals];
    meals[mIdx] = meal;
    _dietPlans[pIdx] = _dietPlans[pIdx].copyWith(meals: meals, updatedAt: DateTime.now());
    _persistDiet();
    notifyListeners();
  }

  Future<void> removeDietMeal(String planId, String mealId) async {
    final pIdx = _dietPlans.indexWhere((d) => d.id == planId);
    if (pIdx < 0) return;
    final meals = _dietPlans[pIdx].meals.where((m) => m.id != mealId).toList();
    _dietPlans[pIdx] = _dietPlans[pIdx].copyWith(meals: meals, updatedAt: DateTime.now());
    _persistDiet();
    notifyListeners();
  }

  Future<void> reorderDietMeals(String planId, List<DietMeal> newOrder) async {
    final pIdx = _dietPlans.indexWhere((d) => d.id == planId);
    if (pIdx < 0) return;
    final reordered = [for (var i = 0; i < newOrder.length; i++) newOrder[i].copyWith(order: i)];
    _dietPlans[pIdx] = _dietPlans[pIdx].copyWith(meals: reordered, updatedAt: DateTime.now());
    _persistDiet();
    notifyListeners();
  }

  Future<void> addDietMealItem(String planId, String mealId, DietMealItem item) async {
    final pIdx = _dietPlans.indexWhere((d) => d.id == planId);
    if (pIdx < 0) return;
    final mIdx = _dietPlans[pIdx].meals.indexWhere((m) => m.id == mealId);
    if (mIdx < 0) return;
    final meal = _dietPlans[pIdx].meals[mIdx];
    final items = [...meal.items, item];
    final updatedMeal = meal.copyWith(items: items);
    final meals = [..._dietPlans[pIdx].meals];
    meals[mIdx] = updatedMeal;
    _dietPlans[pIdx] = _dietPlans[pIdx].copyWith(meals: meals, updatedAt: DateTime.now());
    _persistDiet();
    notifyListeners();
  }

  Future<void> updateDietMealItem(String planId, String mealId, int index, DietMealItem item) async {
    final pIdx = _dietPlans.indexWhere((d) => d.id == planId);
    if (pIdx < 0) return;
    final mIdx = _dietPlans[pIdx].meals.indexWhere((m) => m.id == mealId);
    if (mIdx < 0) return;
    final meal = _dietPlans[pIdx].meals[mIdx];
    if (index < 0 || index >= meal.items.length) return;
    final items = [...meal.items];
    items[index] = item;
    final updatedMeal = meal.copyWith(items: items);
    final meals = [..._dietPlans[pIdx].meals];
    meals[mIdx] = updatedMeal;
    _dietPlans[pIdx] = _dietPlans[pIdx].copyWith(meals: meals, updatedAt: DateTime.now());
    _persistDiet();
    notifyListeners();
  }

  Future<void> removeDietMealItem(String planId, String mealId, int index) async {
    final pIdx = _dietPlans.indexWhere((d) => d.id == planId);
    if (pIdx < 0) return;
    final mIdx = _dietPlans[pIdx].meals.indexWhere((m) => m.id == mealId);
    if (mIdx < 0) return;
    final meal = _dietPlans[pIdx].meals[mIdx];
    final items = [...meal.items]..removeAt(index);
    final updatedMeal = meal.copyWith(items: items);
    final meals = [..._dietPlans[pIdx].meals];
    meals[mIdx] = updatedMeal;
    _dietPlans[pIdx] = _dietPlans[pIdx].copyWith(meals: meals, updatedAt: DateTime.now());
    _persistDiet();
    notifyListeners();
  }

  /// Registra no diário a partir da dieta — clone desacoplado (DietTemplate -> DailyMealEntry).
  /// [selectedIndices] permite registrar apenas parte; [quantityOverrides] permite editar quantidade só do dia;
  /// [substitutions] permite trocar alimento só do dia (key = índice original, value = novo Food com quantidade).
  Future<Meal?> logDietMeal({
    required DietMeal dietMeal,
    required DateTime date,
    Set<int>? selectedIndices,
    Map<int, double>? quantityOverrides,
    Map<int, ({Food food, double quantity, MeasureUnit unit, double? customGrams})>? substitutions,
    MealType? typeOverride,
  }) async {
    final foodMap = _foodById;
    final items = <MealItem>[];
    for (var i = 0; i < dietMeal.items.length; i++) {
      if (selectedIndices != null && !selectedIndices.contains(i)) continue;
      final dietItem = dietMeal.items[i];
      // Substituição só do dia
      if (substitutions != null && substitutions.containsKey(i)) {
        final sub = substitutions[i]!;
        final grams = const HouseholdMeasureConverter().toGrams(sub.food, sub.quantity, sub.unit, customGramsPerUnit: sub.customGrams);
        items.add(MealItem(food: sub.food, quantityGrams: grams));
        continue;
      }
      final food = foodMap[dietItem.foodId] ?? dietItem.foodSnapshot;
      if (food == null) continue;
      final qty = quantityOverrides != null && quantityOverrides.containsKey(i) ? quantityOverrides[i]! : dietItem.quantity;
      final grams = const HouseholdMeasureConverter().toGrams(food, qty, dietItem.unit, customGramsPerUnit: dietItem.customGramsPerUnit);
      if (grams <= 0) continue;
      items.add(MealItem(food: food, quantityGrams: grams));
    }
    if (items.isEmpty) return null;
    final mealType = typeOverride ?? _inferMealType(dietMeal.name);
    final meal = Meal(id: _uuid.v4(), date: date, type: mealType, items: items, rawText: 'Dieta:${dietMeal.id}:${dietMeal.name}');
    await addMeal(meal);
    return meal;
  }

  MealType _inferMealType(String name) {
    final n = name.toLowerCase();
    if (n.contains('café') && n.contains('manhã')) return MealType.cafeDaManha;
    if (n.contains('almoço') || n.contains('almoco')) return MealType.almoco;
    if (n.contains('jantar')) return MealType.jantar;
    if (n.contains('ceia')) return MealType.ceia;
    if (n.contains('lanche') || n.contains('café da tarde') || n.contains('tarde')) return MealType.lanche;
    return MealType.outro;
  }

  /// Status da refeição da dieta no dia: planned / partially / consumed / skipped
  String dietMealStatusFor(DateTime date, DietMeal dietMeal) {
    final meals = mealsOn(date);
    final hasFull = meals.any((m) => m.rawText == 'Dieta:${dietMeal.id}:${dietMeal.name}' || m.rawText == 'Dieta: ${dietMeal.name}');
    if (hasFull) return 'consumed';
    final type = _inferMealType(dietMeal.name);
    final dayMealsOfType = meals.where((m) => m.type == type).toList();
    if (dayMealsOfType.isEmpty) return 'planned';
    // Se tem algum meal do tipo mas não full, considera parcialmente
    return 'partially';
  }

  void _persistTraining() {
    _store.setTrainingPlans(_trainingPlans.map((e) => e.toJson()).toList());
    _store.setActiveTrainingPlanId(_activeTrainingPlanId);
    _store.setTrainingSessions(_trainingSessions.map((e) => e.toJson()).toList());
  }

  // ── Treino ──
  Future<TrainingPlan> createTrainingPlan(String name) async {
    final plan = TrainingPlan(id: _uuid.v4(), name: name.trim().isEmpty ? 'Meu Treino' : name.trim(), days: [], createdAt: DateTime.now(), updatedAt: DateTime.now());
    _trainingPlans.add(plan);
    _activeTrainingPlanId = plan.id;
    _persistTraining();
    notifyListeners();
    return plan;
  }

  Future<void> updateTrainingPlan(TrainingPlan plan) async {
    final idx = _trainingPlans.indexWhere((p) => p.id == plan.id);
    if (idx < 0) return;
    _trainingPlans[idx] = plan.copyWith(updatedAt: DateTime.now());
    _persistTraining();
    notifyListeners();
  }

  Future<void> deleteTrainingPlan(String id) async {
    _trainingPlans.removeWhere((p) => p.id == id);
    if (_activeTrainingPlanId == id) _activeTrainingPlanId = _trainingPlans.isNotEmpty ? _trainingPlans.first.id : null;
    _persistTraining();
    notifyListeners();
  }

  Future<TrainingDay> addTrainingDay(String planId, {required String name, int? weekday, String? time}) async {
    final pIdx = _trainingPlans.indexWhere((p) => p.id == planId);
    if (pIdx < 0) throw StateError('Plano não encontrado');
    final day = TrainingDay(id: _uuid.v4(), name: name.trim().isEmpty ? 'Treino' : name.trim(), weekday: weekday, time: time, exercises: []);
    final updated = [..._trainingPlans[pIdx].days, day];
    _trainingPlans[pIdx] = _trainingPlans[pIdx].copyWith(days: updated, updatedAt: DateTime.now());
    _persistTraining();
    notifyListeners();
    return day;
  }

  Future<void> updateTrainingDay(String planId, TrainingDay day) async {
    final pIdx = _trainingPlans.indexWhere((p) => p.id == planId);
    if (pIdx < 0) return;
    final dIdx = _trainingPlans[pIdx].days.indexWhere((d) => d.id == day.id);
    if (dIdx < 0) return;
    final days = [..._trainingPlans[pIdx].days];
    days[dIdx] = day;
    _trainingPlans[pIdx] = _trainingPlans[pIdx].copyWith(days: days, updatedAt: DateTime.now());
    _persistTraining();
    notifyListeners();
  }

  Future<void> removeTrainingDay(String planId, String dayId) async {
    final pIdx = _trainingPlans.indexWhere((p) => p.id == planId);
    if (pIdx < 0) return;
    final days = _trainingPlans[pIdx].days.where((d) => d.id != dayId).toList();
    _trainingPlans[pIdx] = _trainingPlans[pIdx].copyWith(days: days, updatedAt: DateTime.now());
    _persistTraining();
    notifyListeners();
  }

  Future<void> addExerciseToDay(String planId, String dayId, ExerciseDef exercise) async {
    final pIdx = _trainingPlans.indexWhere((p) => p.id == planId);
    if (pIdx < 0) return;
    final dIdx = _trainingPlans[pIdx].days.indexWhere((d) => d.id == dayId);
    if (dIdx < 0) return;
    final day = _trainingPlans[pIdx].days[dIdx];
    final exs = [...day.exercises, exercise.copyWith(order: day.exercises.length)];
    final updatedDay = day.copyWith(exercises: exs);
    final days = [..._trainingPlans[pIdx].days];
    days[dIdx] = updatedDay;
    _trainingPlans[pIdx] = _trainingPlans[pIdx].copyWith(days: days, updatedAt: DateTime.now());
    _persistTraining();
    notifyListeners();
  }

  Future<TrainingSession> startTrainingSession(String planId, String dayId) async {
    final session = TrainingSession(id: _uuid.v4(), planId: planId, dayId: dayId, date: DateTime.now(), startAt: DateTime.now(), exercises: [], status: TrainingStatus.active);
    _trainingSessions.insert(0, session);
    // also log a simple Workout for compatibility (kcal placeholder)
    await addWorkout(Workout(id: _uuid.v4(), date: DateTime.now(), kcalBurned: 0, source: 'training'));
    _persistTraining();
    notifyListeners();
    return session;
  }

  Future<void> addSetToSession(String sessionId, String exerciseId, TrainingSet set) async {
    final sIdx = _trainingSessions.indexWhere((s) => s.id == sessionId);
    if (sIdx < 0) return;
    final session = _trainingSessions[sIdx];
    final exIdx = session.exercises.indexWhere((e) => e.exerciseId == exerciseId);
    List<ExerciseSession> exSessions;
    if (exIdx < 0) {
      exSessions = [...session.exercises, ExerciseSession(exerciseId: exerciseId, sets: [set])];
    } else {
      final sets = [...session.exercises[exIdx].sets, set];
      final updated = session.exercises[exIdx].copyWith(sets: sets);
      exSessions = [...session.exercises];
      exSessions[exIdx] = updated;
    }
    _trainingSessions[sIdx] = session.copyWith(exercises: exSessions);
    _persistTraining();
    notifyListeners();
  }

  Future<void> finishTrainingSession(String sessionId) async {
    final sIdx = _trainingSessions.indexWhere((s) => s.id == sessionId);
    if (sIdx < 0) return;
    final session = _trainingSessions[sIdx];
    _trainingSessions[sIdx] = session.copyWith(endAt: DateTime.now(), status: TrainingStatus.completed);
    _persistTraining();
    notifyListeners();
  }

  List<TrainingSession> sessionsForDay(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return _trainingSessions.where((s) => s.date.year == d.year && s.date.month == d.month && s.date.day == d.day).toList();
  }

  // ── Perfil / Metas ──
  Future<void> saveProfile(UserProfile profile) async {
    _profile = profile;
    await _store.setProfile(profile.toJson());
    notifyListeners();
  }

  /// Atualiza a foto de perfil (base64). Passar null para remover.
  Future<void> updateProfilePhoto(String? base64) async {
    final current = _profile;
    if (current == null) return;
    _profile = current.copyWith(photoBase64: base64);
    await _store.setProfile(_profile!.toJson());
    notifyListeners();
  }

  /// Calcula automaticamente TMB, TDEE e metas a partir dos dados básicos.
  UserProfile computeGoals(UserProfile base) {
    final tmb = NutritionCalculator.tmb(
      pesoKg: base.pesoAtualKg,
      alturaCm: base.alturaCm,
      idade: base.idade,
      sexo: base.sexo,
    );
    final tdee = NutritionCalculator.tdee(tmb: tmb, nivel: base.nivelAtividade);
    final metaKcal = NutritionCalculator.metaCalorica(
      tdee: tdee,
      objetivo: base.objetivo,
    );
    return base.copyWith(
      metaCalorica: base.metaCalorica ?? metaKcal,
      metaProteina: base.metaProteina ??
          NutritionCalculator.metaProteina(
            pesoKg: base.pesoAtualKg,
            objetivo: base.objetivo,
          ),
      metaCarboidrato: base.metaCarboidrato ??
          NutritionCalculator.metaCarboidrato(
            metaKcal: metaKcal,
            objetivo: base.objetivo,
          ),
      metaGordura: base.metaGordura ??
          NutritionCalculator.metaGordura(
            metaKcal: metaKcal,
            objetivo: base.objetivo,
          ),
      metaAguaMl: base.metaAguaMl ??
          NutritionCalculator.metaAgua(pesoKg: base.pesoAtualKg),
    );
  }

  // ── Bioimpedância ──

  /// Aplica os dados do laudo de bioimpedância:
  /// atualiza o perfil (peso, altura, idade, sexo), recalcula as metas usando
  /// a TMB medida no laudo (quando disponível) e registra o peso no histórico.
  Future<void> importBioimpedance(Bioimpedance bio) async {
    _bioimpedances
        .removeWhere((b) => b.data.year == bio.data.year &&
            b.data.month == bio.data.month &&
            b.data.day == bio.data.day);
    _bioimpedances.add(bio);
    _bioimpedances.sort((a, b) => b.data.compareTo(a.data));

    if (bio.pesoKg != null) {
      final exists = _weights.any((w) =>
          w.date.year == bio.data.year &&
          w.date.month == bio.data.month &&
          w.date.day == bio.data.day);
      if (!exists) {
        _weights.add(WeightRecord(
          date: bio.data,
          weightKg: bio.pesoKg!,
        ));
        _weights.sort((a, b) => a.date.compareTo(b.date));
      }
    }

    final current = profile;
    if (current == null) {
      final imc = bio.imc ?? NutritionCalculator.imc(
            pesoKg: bio.pesoKg ?? 70,
            alturaCm: bio.alturaCm ?? 170,
          );
      final base = UserProfile(
        pesoAtualKg: bio.pesoKg ?? 70,
        pesoDesejadoKg: bio.pesoIdealKg ??
            NutritionCalculator.pesoIdeal(alturaCm: bio.alturaCm ?? 170),
        alturaCm: bio.alturaCm ?? 170,
        idade: bio.idade ?? 30,
        sexo: bio.sexo ?? Sexo.masculino,
        objetivo: imc >= 25 ? Objetivo.emagrecer : Objetivo.manter,
        nivelAtividade: NivelAtividade.moderado,
      );
      _profile = _goalsComBio(base, bio);
    } else if (bio.pesoKg != null || bio.tmbKcal != null) {
      final updated = current.copyWith(
        pesoAtualKg: bio.pesoKg ?? current.pesoAtualKg,
        alturaCm: bio.alturaCm ?? current.alturaCm,
        idade: bio.idade ?? current.idade,
      );
      _profile = _goalsComBio(updated, bio);
    }

    await _store.setProfile(_profile!.toJson());
    _persist();
    notifyListeners();
  }

  UserProfile _goalsComBio(UserProfile base, Bioimpedance bio) {
    if (bio.tmbKcal == null || bio.tmbKcal! <= 0) {
      return computeGoals(base);
    }
    // TMB medida na bioimpedância (mais precisa que a fórmula).
    final tdee = NutritionCalculator.tdee(
      tmb: bio.tmbKcal!,
      nivel: base.nivelAtividade,
    );
    final metaKcal = NutritionCalculator.metaCalorica(
      tdee: tdee,
      objetivo: base.objetivo,
    );
    return base.copyWith(
      metaCalorica: metaKcal,
      metaProteina: NutritionCalculator.metaProteina(
        pesoKg: base.pesoAtualKg,
        objetivo: base.objetivo,
      ),
      metaCarboidrato: NutritionCalculator.metaCarboidrato(
        metaKcal: metaKcal,
        objetivo: base.objetivo,
      ),
      metaGordura: NutritionCalculator.metaGordura(
        metaKcal: metaKcal,
        objetivo: base.objetivo,
      ),
      metaAguaMl: NutritionCalculator.metaAgua(pesoKg: base.pesoAtualKg),
    );
  }

  // ── Refeições ──
  Future<void> addMeal(Meal meal) async {
    _meals.add(meal);
    _persist();
    notifyListeners();
  }

  Future<void> removeMeal(String id) async {
    _meals.removeWhere((m) => m.id == id);
    _persist();
    notifyListeners();
  }

  List<Meal> mealsOn(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return _meals
        .where((m) =>
            m.date.year == day.year &&
            m.date.month == day.month &&
            m.date.day == day.day)
        .toList();
  }

  /// Consumo total do dia (kcal, macros...).
  DailySummary summaryFor(DateTime date, {UserProfile? profile}) {
    final day = DateTime(date.year, date.month, date.day);
    final weight = _weights
        .where((w) =>
            w.date.year == day.year &&
            w.date.month == day.month &&
            w.date.day == day.day)
        .toList();
    return DailySummary(
      date: day,
      meals: mealsOn(day),
      workouts: _workouts.where((w) {
        final d = DateTime(w.date.year, w.date.month, w.date.day);
        return d == day;
      }).toList(),
      waterRecords: _water.where((w) {
        final d = DateTime(w.date.year, w.date.month, w.date.day);
        return d == day;
      }).toList(),
      weightKg: weight.isNotEmpty ? weight.last.weightKg : null,
      profile: profile ?? _profile,
    );
  }

  // ── Treinos ──
  Future<void> addWorkout(Workout workout) async {
    _workouts.add(workout);
    _persist();
    notifyListeners();
  }

  Future<void> removeWorkout(String id) async {
    _workouts.removeWhere((w) => w.id == id);
    _persist();
    notifyListeners();
  }

  // ── Peso ──
  Future<void> addWeight(WeightRecord record) async {
    _weights.removeWhere((w) =>
        w.date.year == record.date.year &&
        w.date.month == record.date.month &&
        w.date.day == record.date.day);
    _weights.add(record);
    _weights.sort((a, b) => a.date.compareTo(b.date));
    _persist();
    notifyListeners();
  }

  // ── Medidas ──
  Future<void> addMeasurement(BodyMeasurement m) async {
    _measurements.add(m);
    _persist();
    notifyListeners();
  }

  // ── Fotos ──
  Future<void> addPhoto(ProgressPhoto photo) async {
    _photos.add(photo);
    _persist();
    notifyListeners();
  }

  Future<void> removePhoto(String id) async {
    _photos.removeWhere((p) => p.id == id);
    _persist();
    notifyListeners();
  }

  // ── Água ──
  Future<void> addWater(DateTime date, double ml) async {
    final day = DateTime(date.year, date.month, date.day);
    final idx = _water.indexWhere((w) =>
        w.date.year == day.year &&
        w.date.month == day.month &&
        w.date.day == day.day);
    if (idx >= 0) {
      _water[idx] = WaterRecord(date: day, amountMl: _water[idx].amountMl + ml);
    } else {
      _water.add(WaterRecord(date: day, amountMl: ml));
    }
    _persist();
    notifyListeners();
  }

  double waterFor(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final found = _water.where((w) =>
        w.date.year == day.year &&
        w.date.month == day.month &&
        w.date.day == day.day);
    return found.isEmpty ? 0 : found.first.amountMl;
  }

  // ── Favoritos ──
  bool isFavorite(String id) => _favoriteIds.contains(id);

  Future<void> toggleFavorite(String id) async {
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
    } else {
      _favoriteIds.add(id);
    }
    _persist();
    notifyListeners();
  }

  Future<void> addCustomFood(Food food) async {
    _customFoods.add(food);
    _favoriteIds.add(food.id);
    _persist();
    notifyListeners();
  }

  List<Food> allSearchableFoods(String query, {int limit = 40}) {
    final local = FoodDatabase.search(query, limit: limit);
    final k = query.trim().toLowerCase();
    final customs = _customFoods
        .where((f) => f.name.toLowerCase().contains(k) || k.isEmpty)
        .toList();
    final combined = [...local, ...customs];
    final seen = <String>{};
    return [
      for (final f in combined)
        if (seen.add(f.id)) f,
    ].take(limit).toList();
  }

  // ── Consultas agregadas ──
  DailySummary get today => summaryFor(DateTime.now());

  WeightRecord? get latestWeight {
    if (_weights.isEmpty) return null;
    _weights.sort((a, b) => a.date.compareTo(b.date));
    return _weights.last;
  }

  List<DailySummary> lastDays(int n) {
    final now = DateTime.now();
    return [
      for (var i = n - 1; i >= 0; i--)
        summaryFor(now.subtract(Duration(days: i))),
    ];
  }

  /// Semana corrente (segunda a domingo).
  WeeklySummary thisWeek() {
    return WeeklySummary(days: lastDays(7));
  }

  /// Cria refeição a partir de itens validados com alimentos reais.
  Meal buildMeal({
    required DateTime date,
    required MealType type,
    required List<MealItem> items,
    String? rawText,
  }) {
    return Meal(
      id: _uuid.v4(),
      date: date,
      type: type,
      items: items,
      rawText: rawText,
      createdAt: DateTime.now(),
    );
  }

  /// Metricas para o dashboard.
  ({double kcal, double protein, double carbs, double fat, double water, double burned, double weight, DayStatus status, double balance})
      dashboardMetrics() {
    final t = today;
    final weight = t.weightKg ?? latestWeight?.weightKg ?? _profile?.pesoAtualKg ?? 0;
    return (
      kcal: t.kcalConsumed,
      protein: t.protein,
      carbs: t.carbs,
      fat: t.fat,
      water: t.waterMl,
      burned: t.kcalBurned,
      weight: weight,
      status: t.status,
      balance: t.balanceKcal,
    );
  }

  double get tmbValue {
    final p = _profile;
    if (p == null) return 0;
    return NutritionCalculator.tmb(
      pesoKg: p.pesoAtualKg,
      alturaCm: p.alturaCm,
      idade: p.idade,
      sexo: p.sexo,
    );
  }

  double get tdeeValue {
    final p = _profile;
    if (p == null) return 0;
    return NutritionCalculator.tdee(tmb: tmbValue, nivel: p.nivelAtividade);
  }

  double get pesoPerdidoKg {
    final p = _profile;
    if (p == null) return 0;
    final current = latestWeight?.weightKg ?? p.pesoAtualKg;
    return math.max(0, p.pesoAtualKg - current);
  }

  // ── Auth (demo local) ──
  Future<void> setUserEmail(String? email) async {
    _userEmail = email;
    await _store.setUserEmail(email);
    notifyListeners();
  }

  // ── Gerência de estado ──
  void setStatus(String message) {
    _statusMessage = message;
    notifyListeners();
  }
}