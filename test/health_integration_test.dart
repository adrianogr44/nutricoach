import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/data/models/device_health.dart';
import 'package:nutricoach_ai/data/repositories/local_store.dart';
import 'package:nutricoach_ai/services/health_connect_service.dart';
import 'package:nutricoach_ai/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serviço falso: devolve dados fixos e controla a permissão do usuário.
class _FakeHealthService implements IHealthConnectService {
  _FakeHealthService({this.grantPermission = true, this.available = true});

  final bool grantPermission;
  final bool available;
  int requestCount = 0;
  int syncCount = 0;

  @override
  bool get isAvailable => available;

  @override
  bool get isConfigured => true;

  @override
  Future<bool> configure() async => true;

  @override
  Future<bool> hasAllPermissions() async => false;

  @override
  Future<bool> requestPermissions() async {
    requestCount++;
    if (!available) return false;
    return grantPermission;
  }

  @override
  Future<void> revokePermissions() async {}

  @override
  Future<HealthIntegrationConfig> getConfig() async => const HealthIntegrationConfig(
        enabled: true,
        connected: true,
        lastSyncAt: null,
        permissionsGranted: [],
      );

  @override
  Future<List<DailyStepsRecord>> fetchDailySteps({
    required DateTime start,
    required DateTime end,
  }) async {
    syncCount++;
    final today = DateTime.now();
    return [
      DailyStepsRecord(
        date: DateTime(today.year, today.month, today.day),
        steps: 8123,
        distanceMeters: 6120,
        caloriesBurned: 321,
        source: HealthDataSource.healthConnect,
      ),
    ];
  }

  @override
  Future<List<DeviceWorkoutSession>> fetchWorkoutSessions({
    required DateTime start,
    required DateTime end,
  }) async {
    final today = DateTime.now();
    return [
      DeviceWorkoutSession(
        id: 'w1',
        startAt: DateTime(today.year, today.month, today.day, 7),
        endAt: DateTime(today.year, today.month, today.day, 8),
        activityType: 'running',
        durationMinutes: 60,
        caloriesBurned: 480,
        sourceId: 'hc-w1',
      ),
    ];
  }

  @override
  Future<List<SleepSessionRecord>> fetchSleepSessions({
    required DateTime start,
    required DateTime end,
  }) async {
    final today = DateTime.now();
    return [
      SleepSessionRecord(
        id: 's1',
        startAt: DateTime(today.year, today.month, today.day, 0),
        endAt: DateTime(today.year, today.month, today.day, 7, 30),
        durationMinutes: 450,
      ),
    ];
  }

  @override
  Future<List<HeartRateRecord>> fetchHeartRate({
    required DateTime start,
    required DateTime end,
  }) async =>
      [
        HeartRateRecord(date: DateTime.now(), valueBpm: 72),
      ];

  @override
  Future<double?> fetchRestingHeartRate({required DateTime date}) async => 58;

  @override
  Future<double?> fetchLatestWeightKg() async => 92.4;
}

Future<AppState> _state(IHealthConnectService service) async {
  SharedPreferences.setMockInitialValues({});
  final state = AppState(await LocalStore.open(), healthService: service);
  await state.init();
  return state;
}

void main() {
  group('integração com a saúde do dispositivo', () {
    test('sem permissão, conectar não marca como conectado', () async {
      final fake = _FakeHealthService(grantPermission: false);
      final state = await _state(fake);

      final ok = await state.connectHealth();

      expect(ok, isFalse);
      expect(fake.requestCount, 1);
      expect(state.healthConfig.connected, isFalse);
      expect(state.healthSteps, isEmpty);
    });

    test('com permissão, conectar sincroniza passos, sono, FC e peso', () async {
      final fake = _FakeHealthService();
      final state = await _state(fake);

      final ok = await state.connectHealth();

      expect(ok, isTrue);
      expect(state.healthConfig.connected, isTrue);
      expect(state.todaySteps?.steps, 8123);
      expect(state.todaySteps?.distanceMeters, 6120);
      expect(state.todaySteps?.caloriesBurned, 321);
      expect(state.healthSleep.single.durationMinutes, 450);
      expect(state.healthHeartRate.single.valueBpm, 72);
      expect(state.healthRestingHr, 58);
      expect(state.healthWeightKg, 92.4);
      expect(state.deviceWorkouts.single.activityType, 'running');
      expect(state.healthSyncHistory.first.status, 'success');
    });

    test('sincronizar sem conexão não busca dados', () async {
      final fake = _FakeHealthService();
      final state = await _state(fake);

      await state.syncHealthData();

      expect(fake.syncCount, 0);
      expect(state.healthSteps, isEmpty);
    });

    test('dados do dispositivo sobrevivem ao reiniciar o app', () async {
      final state = await _state(_FakeHealthService());
      await state.connectHealth();

      final reopened = AppState(await LocalStore.open(), healthService: _FakeHealthService());
      await reopened.init();

      expect(reopened.healthConfig.connected, isTrue);
      expect(reopened.todaySteps?.steps, 8123);
      expect(reopened.healthRestingHr, 58);
      expect(reopened.healthWeightKg, 92.4);
      expect(reopened.healthSyncHistory, isNotEmpty);
    });

    test('peso do dispositivo pode ser aplicado ao histórico de peso', () async {
      final state = await _state(_FakeHealthService());
      await state.connectHealth();

      await state.applyDeviceWeight();

      expect(state.weights, hasLength(1));
      expect(state.weights.single.weightKg, 92.4);
      final today = DateTime.now();
      expect(state.weights.single.date.day, today.day);

      // Aplicar duas vezes no mesmo dia não duplica o registro.
      await state.applyDeviceWeight();
      expect(state.weights, hasLength(1));
    });

    test('desconectar mantém os dados já sincronizados', () async {
      final state = await _state(_FakeHealthService());
      await state.connectHealth();

      await state.disconnectHealth();

      expect(state.healthConfig.connected, isFalse);
      expect(state.todaySteps?.steps, 8123);
    });

    test('plataforma sem suporte expõe healthSupported = false', () async {
      final state = await _state(_FakeHealthService(available: false));

      expect(state.healthSupported, isFalse);
      expect(await state.connectHealth(), isFalse);
    });
  });
}
