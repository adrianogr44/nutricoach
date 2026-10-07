import 'package:flutter/foundation.dart';

/// Exercício dentro de um treino.
class ExerciseDef {
  const ExerciseDef({
    required this.id,
    required this.name,
    this.muscleGroup,
    this.sets = 3,
    this.repsMin = 10,
    this.repsMax = 12,
    this.loadKg = 0,
    this.restSeconds = 90,
    this.notes,
    this.order = 0,
  });

  final String id;
  final String name;
  final String? muscleGroup;
  final int sets;
  final int repsMin;
  final int repsMax;
  final double loadKg;
  final int restSeconds;
  final String? notes;
  final int order;

  String get repsLabel => repsMin == repsMax ? '$repsMin' : '$repsMin–$repsMax';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'muscleGroup': muscleGroup,
        'sets': sets,
        'repsMin': repsMin,
        'repsMax': repsMax,
        'loadKg': loadKg,
        'restSeconds': restSeconds,
        'notes': notes,
        'order': order,
      };

  factory ExerciseDef.fromJson(Map<String, dynamic> json) => ExerciseDef(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        muscleGroup: json['muscleGroup'] as String?,
        sets: (json['sets'] as num?)?.toInt() ?? 3,
        repsMin: (json['repsMin'] as num?)?.toInt() ?? 10,
        repsMax: (json['repsMax'] as num?)?.toInt() ?? 12,
        loadKg: (json['loadKg'] as num?)?.toDouble() ?? 0,
        restSeconds: (json['restSeconds'] as num?)?.toInt() ?? 90,
        notes: json['notes'] as String?,
        order: (json['order'] as num?)?.toInt() ?? 0,
      );

  ExerciseDef copyWith({String? name, String? muscleGroup, int? sets, int? repsMin, int? repsMax, double? loadKg, int? restSeconds, String? notes, int? order}) {
    return ExerciseDef(id: id, name: name ?? this.name, muscleGroup: muscleGroup ?? this.muscleGroup, sets: sets ?? this.sets, repsMin: repsMin ?? this.repsMin, repsMax: repsMax ?? this.repsMax, loadKg: loadKg ?? this.loadKg, restSeconds: restSeconds ?? this.restSeconds, notes: notes ?? this.notes, order: order ?? this.order);
  }
}

/// Treino do dia (ex: Costas + Bíceps)
class TrainingDay {
  const TrainingDay({
    required this.id,
    required this.name,
    this.weekday,
    this.time,
    this.exercises = const [],
    this.estimatedMinutes,
  });

  final String id;
  final String name;
  final int? weekday; // 0-6 = seg-dom, null = sem dia fixo
  final String? time; // "19:00"
  final List<ExerciseDef> exercises;
  final int? estimatedMinutes;

  int get totalSets => exercises.fold(0, (s, e) => s + e.sets);
  int get totalExercises => exercises.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'weekday': weekday,
        'time': time,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'estimatedMinutes': estimatedMinutes,
      };

  factory TrainingDay.fromJson(Map<String, dynamic> json) => TrainingDay(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        weekday: (json['weekday'] as num?)?.toInt(),
        time: json['time'] as String?,
        exercises: (json['exercises'] as List? ?? []).map((e) => ExerciseDef.fromJson(e as Map<String, dynamic>)).toList(),
        estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt(),
      );

  TrainingDay copyWith({String? name, int? weekday, String? time, List<ExerciseDef>? exercises, int? estimatedMinutes}) {
    return TrainingDay(id: id, name: name ?? this.name, weekday: weekday ?? this.weekday, time: time ?? this.time, exercises: exercises ?? this.exercises, estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes);
  }
}

/// Plano de treino (rotina semanal)
class TrainingPlan {
  const TrainingPlan({required this.id, required this.name, this.days = const [], this.createdAt, this.updatedAt, this.isActive = true});
  final String id;
  final String name;
  final List<TrainingDay> days;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isActive;

  TrainingDay? get today {
    final now = DateTime.now().weekday % 7; // 1=seg -> 1, 7=dom ->0
    final wd = now == 7 ? 0 : now;
    // tenta achar pelo weekday, senão primeiro
    final found = days.where((d) => d.weekday == wd).toList();
    if (found.isNotEmpty) return found.first;
    if (days.isNotEmpty) return days.first;
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'days': days.map((e) => e.toJson()).toList(),
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'isActive': isActive,
      };

  factory TrainingPlan.fromJson(Map<String, dynamic> json) => TrainingPlan(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        days: (json['days'] as List? ?? []).map((e) => TrainingDay.fromJson(e as Map<String, dynamic>)).toList(),
        createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
        updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
        isActive: json['isActive'] as bool? ?? true,
      );

  TrainingPlan copyWith({String? name, List<TrainingDay>? days, DateTime? updatedAt, bool? isActive}) {
    return TrainingPlan(id: id, name: name ?? this.name, days: days ?? this.days, createdAt: createdAt, updatedAt: updatedAt ?? this.updatedAt, isActive: isActive ?? this.isActive);
  }
}

/// Série registrada
class TrainingSet {
  const TrainingSet({required this.weight, required this.reps, this.completedAt, this.isPR = false});
  final double weight;
  final int reps;
  final DateTime? completedAt;
  final bool isPR;

  Map<String, dynamic> toJson() => {'weight': weight, 'reps': reps, 'completedAt': completedAt?.toIso8601String(), 'isPR': isPR};
  factory TrainingSet.fromJson(Map<String, dynamic> json) => TrainingSet(weight: (json['weight'] as num?)?.toDouble() ?? 0, reps: (json['reps'] as num?)?.toInt() ?? 0, completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt'] as String) : null, isPR: json['isPR'] as bool? ?? false);
}

/// Sessão de treino em andamento ou finalizada
class TrainingSession {
  const TrainingSession({
    required this.id,
    required this.planId,
    required this.dayId,
    required this.date,
    this.startAt,
    this.endAt,
    this.exercises = const [],
    this.status = TrainingStatus.active,
  });

  final String id;
  final String planId;
  final String dayId;
  final DateTime date;
  final DateTime? startAt;
  final DateTime? endAt;
  final List<ExerciseSession> exercises;
  final TrainingStatus status;

  int get totalSets => exercises.fold(0, (s, e) => s + e.sets.length);
  int get durationMinutes => startAt != null && endAt != null ? endAt!.difference(startAt!).inMinutes : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'planId': planId,
        'dayId': dayId,
        'date': date.toIso8601String(),
        'startAt': startAt?.toIso8601String(),
        'endAt': endAt?.toIso8601String(),
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'status': status.name,
      };

  factory TrainingSession.fromJson(Map<String, dynamic> json) => TrainingSession(
        id: json['id'] as String? ?? '',
        planId: json['planId'] as String? ?? '',
        dayId: json['dayId'] as String? ?? '',
        date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        startAt: json['startAt'] != null ? DateTime.tryParse(json['startAt'] as String) : null,
        endAt: json['endAt'] != null ? DateTime.tryParse(json['endAt'] as String) : null,
        exercises: (json['exercises'] as List? ?? []).map((e) => ExerciseSession.fromJson(e as Map<String, dynamic>)).toList(),
        status: TrainingStatus.values.firstWhere((s) => s.name == json['status'], orElse: () => TrainingStatus.active),
      );

  TrainingSession copyWith({DateTime? endAt, List<ExerciseSession>? exercises, TrainingStatus? status}) {
    return TrainingSession(id: id, planId: planId, dayId: dayId, date: date, startAt: startAt, endAt: endAt ?? this.endAt, exercises: exercises ?? this.exercises, status: status ?? this.status);
  }
}

class ExerciseSession {
  const ExerciseSession({required this.exerciseId, this.sets = const []});
  final String exerciseId;
  final List<TrainingSet> sets;
  Map<String, dynamic> toJson() => {'exerciseId': exerciseId, 'sets': sets.map((e) => e.toJson()).toList()};
  factory ExerciseSession.fromJson(Map<String, dynamic> json) => ExerciseSession(exerciseId: json['exerciseId'] as String? ?? '', sets: (json['sets'] as List? ?? []).map((e) => TrainingSet.fromJson(e as Map<String, dynamic>)).toList());
  ExerciseSession copyWith({List<TrainingSet>? sets}) => ExerciseSession(exerciseId: exerciseId, sets: sets ?? this.sets);
}

enum TrainingStatus { active, completed, cancelled }

extension TrainingStatusX on TrainingStatus {
  String get label => switch (this) { TrainingStatus.active => 'Em andamento', TrainingStatus.completed => 'Concluído', TrainingStatus.cancelled => 'Cancelado' };
}
