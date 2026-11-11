import 'package:flutter/foundation.dart';

/// Origem dos dados importados do dispositivo/saúde
enum HealthDataSource {
  manual,
  healthConnect,
  deviceImport,
  other,
}

/// Registro de passos importado do Health Connect
@immutable
class DailyStepsRecord {
  const DailyStepsRecord({
    required this.date,
    required this.steps,
    required this.distanceMeters,
    required this.caloriesBurned,
    required this.source,
    this.lastSyncAt,
  });

  final DateTime date;
  final int steps;
  final double distanceMeters;
  final double caloriesBurned;
  final HealthDataSource source;
  final DateTime? lastSyncAt;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'steps': steps,
        'distanceMeters': distanceMeters,
        'caloriesBurned': caloriesBurned,
        'source': source.name,
        'lastSyncAt': lastSyncAt?.toIso8601String(),
      };

  factory DailyStepsRecord.fromJson(Map<String, dynamic> json) => DailyStepsRecord(
        date: DateTime.tryParse(json['date'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        steps: (json['steps'] as num?)?.toInt() ?? 0,
        distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
        caloriesBurned: (json['caloriesBurned'] as num?)?.toDouble() ?? 0,
        source: HealthDataSource.values.firstWhere(
          (e) => e.name == json['source'],
          orElse: () => HealthDataSource.healthConnect,
        ),
        lastSyncAt: json['lastSyncAt'] != null
            ? DateTime.tryParse(json['lastSyncAt'] as String)?.toLocal()
            : null,
      );

  DailyStepsRecord copyWith({
    DateTime? date,
    int? steps,
    double? distanceMeters,
    double? caloriesBurned,
    HealthDataSource? source,
    DateTime? lastSyncAt,
  }) =>
      DailyStepsRecord(
        date: date ?? this.date,
        steps: steps ?? this.steps,
        distanceMeters: distanceMeters ?? this.distanceMeters,
        caloriesBurned: caloriesBurned ?? this.caloriesBurned,
        source: source ?? this.source,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      );
}

/// Treino importado do Health Connect (sessões do relógio)
@immutable
class DeviceWorkoutSession {
  const DeviceWorkoutSession({
    required this.id,
    required this.startAt,
    required this.endAt,
    required this.activityType,
    this.durationMinutes,
    this.caloriesBurned,
    this.distanceMeters,
    this.heartRateAvg,
    this.source,
    this.sourceId,
    this.lastSyncAt,
  });

  final String id;
  final DateTime startAt;
  final DateTime endAt;
  final String activityType;
  final int? durationMinutes;
  final double? caloriesBurned;
  final double? distanceMeters;
  final double? heartRateAvg;
  final HealthDataSource? source;
  final String? sourceId;
  final DateTime? lastSyncAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'startAt': startAt.toIso8601String(),
        'endAt': endAt.toIso8601String(),
        'activityType': activityType,
        'durationMinutes': durationMinutes,
        'caloriesBurned': caloriesBurned,
        'distanceMeters': distanceMeters,
        'heartRateAvg': heartRateAvg,
        'source': source?.name,
        'sourceId': sourceId,
        'lastSyncAt': lastSyncAt?.toIso8601String(),
      };

  factory DeviceWorkoutSession.fromJson(Map<String, dynamic> json) => DeviceWorkoutSession(
        id: json['id'] as String? ?? '',
        startAt: DateTime.tryParse(json['startAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        endAt: DateTime.tryParse(json['endAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        activityType: json['activityType'] as String? ?? 'unknown',
        durationMinutes: json['durationMinutes'] as int?,
        caloriesBurned: (json['caloriesBurned'] as num?)?.toDouble(),
        distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
        heartRateAvg: (json['heartRateAvg'] as num?)?.toDouble(),
        source: json['source'] != null
            ? HealthDataSource.values.firstWhere(
                (e) => e.name == json['source'],
                orElse: () => HealthDataSource.healthConnect,
              )
            : HealthDataSource.healthConnect,
        sourceId: json['sourceId'] as String?,
        lastSyncAt: json['lastSyncAt'] != null
            ? DateTime.tryParse(json['lastSyncAt'] as String)?.toLocal()
            : null,
      );
}

/// Sono importado do Health Connect
@immutable
class SleepSessionRecord {
  const SleepSessionRecord({
    required this.id,
    required this.startAt,
    required this.endAt,
    required this.durationMinutes,
    this.stages,
    this.lastSyncAt,
  });

  final String id;
  final DateTime startAt;
  final DateTime endAt;
  final int durationMinutes;
  final String? stages;
  final DateTime? lastSyncAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'startAt': startAt.toIso8601String(),
        'endAt': endAt.toIso8601String(),
        'durationMinutes': durationMinutes,
        'stages': stages,
        'lastSyncAt': lastSyncAt?.toIso8601String(),
      };

  factory SleepSessionRecord.fromJson(Map<String, dynamic> json) => SleepSessionRecord(
        id: json['id'] as String? ?? '',
        startAt: DateTime.tryParse(json['startAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        endAt: DateTime.tryParse(json['endAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
        stages: json['stages'] as String?,
        lastSyncAt: json['lastSyncAt'] != null
            ? DateTime.tryParse(json['lastSyncAt'] as String)?.toLocal()
            : null,
      );
}

/// Registro de frequência cardíaca
@immutable
class HeartRateRecord {
  const HeartRateRecord({
    required this.date,
    required this.valueBpm,
    this.timestamp,
    this.lastSyncAt,
  });

  final DateTime date;
  final double valueBpm;
  final DateTime? timestamp;
  final DateTime? lastSyncAt;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'valueBpm': valueBpm,
        'timestamp': timestamp?.toIso8601String(),
        'lastSyncAt': lastSyncAt?.toIso8601String(),
      };

  factory HeartRateRecord.fromJson(Map<String, dynamic> json) => HeartRateRecord(
        date: DateTime.tryParse(json['date'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        valueBpm: (json['valueBpm'] as num?)?.toDouble() ?? 0,
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String)?.toLocal()
            : null,
        lastSyncAt: json['lastSyncAt'] != null
            ? DateTime.tryParse(json['lastSyncAt'] as String)?.toLocal()
            : null,
      );
}

/// Histórico de sincronização
@immutable
class HealthSyncHistory {
  const HealthSyncHistory({
    required this.syncAt,
    required this.status,
    this.details,
    this.error,
  });

  final DateTime syncAt;
  final String status;
  final String? details;
  final String? error;

  Map<String, dynamic> toJson() => {
        'syncAt': syncAt.toIso8601String(),
        'status': status,
        'details': details,
        'error': error,
      };

  factory HealthSyncHistory.fromJson(Map<String, dynamic> json) => HealthSyncHistory(
        syncAt: DateTime.tryParse(json['syncAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        status: json['status'] as String? ?? 'unknown',
        details: json['details'] as String?,
        error: json['error'] as String?,
      );
}

/// Configuração de integração
@immutable
class HealthIntegrationConfig {
  const HealthIntegrationConfig({
    required this.enabled,
    required this.connected,
    required this.lastSyncAt,
    required this.permissionsGranted,
    this.syncOnAppStart = true,
  });

  final bool enabled;
  final bool connected;
  final DateTime? lastSyncAt;
  final List<String> permissionsGranted;
  final bool syncOnAppStart;

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'connected': connected,
        'lastSyncAt': lastSyncAt?.toIso8601String(),
        'permissionsGranted': permissionsGranted,
        'syncOnAppStart': syncOnAppStart,
      };

  factory HealthIntegrationConfig.fromJson(Map<String, dynamic> json) => HealthIntegrationConfig(
        enabled: json['enabled'] as bool? ?? false,
        connected: json['connected'] as bool? ?? false,
        lastSyncAt: json['lastSyncAt'] != null
            ? DateTime.tryParse(json['lastSyncAt'] as String)?.toLocal()
            : null,
        permissionsGranted: (json['permissionsGranted'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        syncOnAppStart: json['syncOnAppStart'] as bool? ?? true,
      );

  HealthIntegrationConfig copyWith({
    bool? enabled,
    bool? connected,
    DateTime? lastSyncAt,
    List<String>? permissionsGranted,
    bool? syncOnAppStart,
  }) =>
      HealthIntegrationConfig(
        enabled: enabled ?? this.enabled,
        connected: connected ?? this.connected,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        permissionsGranted: permissionsGranted ?? this.permissionsGranted,
        syncOnAppStart: syncOnAppStart ?? this.syncOnAppStart,
      );
}