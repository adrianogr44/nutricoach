import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import '../data/models/device_health.dart';

/// Interface abstrata para permitir testes com mocks
abstract class IHealthConnectService {
  bool get isAvailable;
  bool get isConfigured;

  Future<bool> configure();
  Future<bool> hasAllPermissions();
  Future<bool> requestPermissions();
  Future<void> revokePermissions();
  Future<HealthIntegrationConfig> getConfig();

  Future<List<DailyStepsRecord>> fetchDailySteps({required DateTime start, required DateTime end});
  Future<List<DeviceWorkoutSession>> fetchWorkoutSessions({required DateTime start, required DateTime end});
  Future<List<SleepSessionRecord>> fetchSleepSessions({required DateTime start, required DateTime end});
  Future<List<HeartRateRecord>> fetchHeartRate({required DateTime start, required DateTime end});
  Future<double?> fetchRestingHeartRate({required DateTime date});
  Future<double?> fetchLatestWeightKg();
}

/// Implementação real usando o pacote health
class HealthConnectService implements IHealthConnectService {
  HealthConnectService({Health? health}) : _health = health ?? Health();

  final Health _health;
  bool _configured = false;

  @override
  bool get isAvailable => kIsWeb ? false : true;

  @override
  bool get isConfigured => _configured;

  final List<HealthDataType> _requiredTypes = const [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.WORKOUT,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.WEIGHT,
  ];

  @override
  Future<bool> configure() async {
    try {
      _configured = true;
      return true;
    } catch (e) {
      debugPrint('HealthConnectService.configure error: $e');
      return false;
    }
  }

  @override
  Future<bool> hasAllPermissions() async {
    if (!isAvailable) return false;
    try {
      final has = await _health.hasPermissions(_requiredTypes);
      return has ?? false;
    } catch (e) {
      debugPrint('HealthConnectService.hasAllPermissions error: $e');
      return false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    if (!isAvailable) return false;
    try {
      final requested = await _health.requestAuthorization(_requiredTypes);
      return requested;
    } catch (e) {
      debugPrint('HealthConnectService.requestPermissions error: $e');
      return false;
    }
  }

  @override
  Future<void> revokePermissions() async {
    if (!isAvailable) return;
    try {
      await _health.revokePermissions();
    } catch (e) {
      debugPrint('HealthConnectService.revokePermissions error: $e');
    }
  }

  @override
  Future<HealthIntegrationConfig> getConfig() async {
    return const HealthIntegrationConfig(
      enabled: true,
      connected: false,
      lastSyncAt: null,
      permissionsGranted: [],
      syncOnAppStart: true,
    );
  }

  @override
  Future<List<DailyStepsRecord>> fetchDailySteps({required DateTime start, required DateTime end}) async {
    if (!isAvailable) return [];
    try {
      final steps = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: start,
        endTime: end,
      );
      // Agrupar por dia - implementação simplificada
      final Map<String, int> dailySteps = {};
      final Map<String, double> dailyDist = {};
      final Map<String, double> dailyCal = {};
      
      for (final p in steps) {
        final key = _dateKey(p.dateFrom);
        dailySteps[key] = (dailySteps[key] ?? 0) + (p.value as NumericHealthValue).numericValue.toInt();
      }
      // Para cálculos reais, implementar agregação adequada
      final result = <DailyStepsRecord>[];
      for (final entry in dailySteps.entries) {
        final d = _parseDateKey(entry.key);
        result.add(DailyStepsRecord(
          date: d,
          steps: entry.value,
          distanceMeters: dailyDist[entry.key] ?? 0,
          caloriesBurned: dailyCal[entry.key] ?? 0,
          source: HealthDataSource.healthConnect,
          lastSyncAt: DateTime.now(),
        ));
      }
      return result;
    } catch (e) {
      debugPrint('fetchDailySteps error: $e');
      return [];
    }
  }

  @override
  Future<List<DeviceWorkoutSession>> fetchWorkoutSessions({required DateTime start, required DateTime end}) async {
    if (!isAvailable) return [];
    try {
      final workouts = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: start,
        endTime: end,
      );
      final result = <DeviceWorkoutSession>[];
      for (final p in workouts) {
        final value = p.value as WorkoutHealthValue;
        result.add(DeviceWorkoutSession(
          id: p.uuid,
          startAt: p.dateFrom,
          endAt: p.dateTo,
          activityType: value.workoutActivityType.name,
          durationMinutes: p.dateTo.difference(p.dateFrom).inMinutes,
          caloriesBurned: value.totalEnergyBurned?.toDouble(),
          distanceMeters: value.totalDistance?.toDouble(),
          source: HealthDataSource.healthConnect,
          sourceId: p.sourceId,
          lastSyncAt: DateTime.now(),
        ));
      }
      return result;
    } catch (e) {
      debugPrint('fetchWorkoutSessions error: $e');
      return [];
    }
  }

  @override
  Future<List<SleepSessionRecord>> fetchSleepSessions({required DateTime start, required DateTime end}) async {
    if (!isAvailable) return [];
    try {
      final sleep = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_IN_BED],
        startTime: start,
        endTime: end,
      );
      final result = <SleepSessionRecord>[];
      for (final p in sleep) {
        result.add(SleepSessionRecord(
          id: p.uuid,
          startAt: p.dateFrom,
          endAt: p.dateTo,
          durationMinutes: p.dateTo.difference(p.dateFrom).inMinutes,
          stages: p.type.name,
          lastSyncAt: DateTime.now(),
        ));
      }
      return result;
    } catch (e) {
      debugPrint('fetchSleepSessions error: $e');
      return [];
    }
  }

  @override
  Future<List<HeartRateRecord>> fetchHeartRate({required DateTime start, required DateTime end}) async {
    if (!isAvailable) return [];
    try {
      final hr = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: start,
        endTime: end,
      );
      final result = <HeartRateRecord>[];
      for (final p in hr) {
        result.add(HeartRateRecord(
          date: p.dateFrom,
          valueBpm: (p.value as NumericHealthValue).numericValue.toDouble(),
          timestamp: p.dateFrom,
          lastSyncAt: DateTime.now(),
        ));
      }
      return result;
    } catch (e) {
      debugPrint('fetchHeartRate error: $e');
      return [];
    }
  }

  @override
  Future<double?> fetchRestingHeartRate({required DateTime date}) async {
    if (!isAvailable) return null;
    try {
      final rhr = await _health.getHealthDataFromTypes(
        types: [HealthDataType.RESTING_HEART_RATE],
        startTime: DateTime(date.year, date.month, date.day),
        endTime: DateTime(date.year, date.month, date.day, 23, 59, 59),
      );
      if (rhr.isEmpty) return null;
      return (rhr.last.value as NumericHealthValue).numericValue.toDouble();
    } catch (e) {
      debugPrint('fetchRestingHeartRate error: $e');
      return null;
    }
  }

  @override
  Future<double?> fetchLatestWeightKg() async {
    if (!isAvailable) return null;
    try {
      final w = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WEIGHT],
        startTime: DateTime.now().subtract(const Duration(days: 365)),
        endTime: DateTime.now(),
      );
      if (w.isEmpty) return null;
      final latest = w.last;
      final kg = (latest.value as NumericHealthValue).numericValue.toDouble();
      return kg;
    } catch (e) {
      debugPrint('fetchLatestWeightKg error: $e');
      return null;
    }
  }

  String _dateKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  DateTime _parseDateKey(String k) {
    final parts = k.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }
}