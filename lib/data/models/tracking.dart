/// Registro de treino/academia.
class Workout {
  const Workout({
    required this.id,
    required this.date,
    required this.kcalBurned,
    this.durationMinutes,
    this.notes,
    this.source,
  });

  final String id;
  final DateTime date;
  final double kcalBurned;
  final int? durationMinutes;
  final String? notes;
  final String? source; // manual | googleFit | miFit | healthConnect

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'kcalBurned': kcalBurned,
        'durationMinutes': durationMinutes,
        'notes': notes,
        'source': source,
      };

  factory Workout.fromJson(Map<String, dynamic> json) => Workout(
        id: json['id'] as String? ?? '',
        date: DateTime.tryParse(json['date'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        kcalBurned: (json['kcalBurned'] as num?)?.toDouble() ?? 0,
        durationMinutes: json['durationMinutes'] as int?,
        notes: json['notes'] as String?,
        source: json['source'] as String?,
      );
}

/// Consumo de água do dia.
class WaterRecord {
  const WaterRecord({required this.date, required this.amountMl});

  final DateTime date;
  final double amountMl;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'amountMl': amountMl,
      };

  factory WaterRecord.fromJson(Map<String, dynamic> json) => WaterRecord(
        date: DateTime.tryParse(json['date'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        amountMl: (json['amountMl'] as num?)?.toDouble() ?? 0,
      );
}