import '../models/meal.dart';
import '../models/tracking.dart';
import '../models/user_profile.dart';
import '../../core/constants.dart';

/// Resumo agregado de um dia (refeições, água, peso, treino, status).
class DailySummary {
  DailySummary({
    required this.date,
    required this.meals,
    required this.workouts,
    required this.waterRecords,
    this.weightKg,
    required this.profile,
  });

  final DateTime date;
  final List<Meal> meals;
  final List<Workout> workouts;
  final List<WaterRecord> waterRecords;
  final double? weightKg;
  final UserProfile? profile;

  double get kcalConsumed =>
      meals.fold(0.0, (s, m) => s + m.totalKcal);

  double get protein => meals.fold(0.0, (s, m) => s + m.totalProtein);
  double get carbs => meals.fold(0.0, (s, m) => s + m.totalCarbs);
  double get fat => meals.fold(0.0, (s, m) => s + m.totalFat);
  double get fiber => meals.fold(0.0, (s, m) => s + m.totalFiber);
  double get sodium => meals.fold(0.0, (s, m) => s + m.totalSodium);

  double get kcalBurned =>
      workouts.fold(0.0, (s, w) => s + w.kcalBurned);

  double get waterMl =>
      waterRecords.fold(0.0, (s, w) => s + w.amountMl);

  double get metaKcal => profile?.metaCalorica ?? 2000;

  double get netCalories => kcalConsumed - kcalBurned;

  /// Déficit = meta - (consumido - gasto)
  double get balanceKcal => metaKcal - netCalories;

  DayStatus get status {
    if (balanceKcal > 50) return DayStatus.deficit;
    if (balanceKcal < -50) return DayStatus.surplus;
    return DayStatus.maintenance;
  }

  double get metaProtein => profile?.metaProteina ?? 120;
  double get metaCarbs => profile?.metaCarboidrato ?? 250;
  double get metaFat => profile?.metaGordura ?? 60;
  double get metaWater => profile?.metaAguaMl ?? 2500;
}

/// Resumo semanal de metas.
class WeeklySummary {
  WeeklySummary({required this.days});

  final List<DailySummary> days;

  double get avgKcal =>
      days.isEmpty ? 0 : days.map((d) => d.kcalConsumed).reduce((a, b) => a + b) / days.length;

  double get avgProtein =>
      days.isEmpty ? 0 : days.map((d) => d.protein).reduce((a, b) => a + b) / days.length;

  double get avgKcalBurned =>
      days.isEmpty ? 0 : days.map((d) => d.kcalBurned).reduce((a, b) => a + b) / days.length;

  int get deficitDays => days.where((d) => d.status == DayStatus.deficit).length;
  int get aderenciaKcal =>
      days.isEmpty ? 0 : (days.where((d) {
            final meta = d.metaKcal;
            return d.kcalConsumed <= meta * 1.1;
          }).length * 100 / days.length).round();
}