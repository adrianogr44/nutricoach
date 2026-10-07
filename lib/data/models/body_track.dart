/// Registro de peso diário.
class WeightRecord {
  const WeightRecord({required this.date, required this.weightKg});

  final DateTime date;
  final double weightKg;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'weightKg': weightKg,
      };

  factory WeightRecord.fromJson(Map<String, dynamic> json) => WeightRecord(
        date: DateTime.tryParse(json['date'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0,
      );
}

/// Medida corporal (circunferência).
enum MeasureType { abdominal, peito, braco, coxa, panturrilha }

extension MeasureTypeX on MeasureType {
  String get label {
    switch (this) {
      case MeasureType.abdominal:
        return 'Abdominal';
      case MeasureType.peito:
        return 'Peito';
      case MeasureType.braco:
        return 'Braço';
      case MeasureType.coxa:
        return 'Coxa';
      case MeasureType.panturrilha:
        return 'Panturrilha';
    }
  }
}

class BodyMeasurement {
  const BodyMeasurement({
    required this.date,
    required this.type,
    required this.valueCm,
  });

  final DateTime date;
  final MeasureType type;
  final double valueCm;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'type': type.name,
        'valueCm': valueCm,
      };

  factory BodyMeasurement.fromJson(Map<String, dynamic> json) =>
      BodyMeasurement(
        date: DateTime.tryParse(json['date'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        type: MeasureType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => MeasureType.abdominal,
        ),
        valueCm: (json['valueCm'] as num?)?.toDouble() ?? 0,
      );
}

/// Foto de evolução.
class ProgressPhoto {
  const ProgressPhoto({
    required this.id,
    required this.date,
    required this.dataUri,
  });

  final String id;
  final DateTime date;
  final String dataUri; // base64 (demo/local) ou path (device)

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'dataUri': dataUri,
      };

  factory ProgressPhoto.fromJson(Map<String, dynamic> json) => ProgressPhoto(
        id: json['id'] as String? ?? '',
        date: DateTime.tryParse(json['date'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        dataUri: json['dataUri'] as String? ?? '',
      );
}