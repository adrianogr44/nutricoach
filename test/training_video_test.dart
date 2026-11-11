import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/data/models/training.dart';
import 'package:nutricoach_ai/services/training_transfer.dart';

void main() {
  group('ExerciseDef — vídeo demonstrativo', () {
    test('preserva videoUrl e thumbnailUrl no JSON', () {
      const exercise = ExerciseDef(
        id: 'e1',
        name: 'Supino reto',
        videoUrl: 'https://youtu.be/abc123',
        thumbnailUrl: 'https://img.example/supino.jpg',
      );

      final decoded = ExerciseDef.fromJson(exercise.toJson());

      expect(decoded.videoUrl, 'https://youtu.be/abc123');
      expect(decoded.thumbnailUrl, 'https://img.example/supino.jpg');
    });

    test('ficha antiga (sem vídeo) continua válida', () {
      final decoded = ExerciseDef.fromJson({
        'id': 'e1',
        'name': 'Rosca direta',
      });

      expect(decoded.videoUrl, isNull);
      expect(decoded.thumbnailUrl, isNull);
      expect(decoded.sets, 3);
    });

    test('copyWith preserva os vídeos ao mudar outros campos', () {
      const exercise = ExerciseDef(
        id: 'e1',
        name: 'Supino reto',
        videoUrl: 'https://youtu.be/abc123',
        thumbnailUrl: 'https://img.example/supino.jpg',
      );

      final updated = exercise.copyWith(name: 'Supino inclinado');

      expect(updated.name, 'Supino inclinado');
      expect(updated.videoUrl, 'https://youtu.be/abc123');
      expect(updated.thumbnailUrl, 'https://img.example/supino.jpg');
    });
  });

  group('TrainingDay — ênfase muscular', () {
    test('usa os grupos musculares cadastrados, sem repetir', () {
      const day = TrainingDay(
        id: 'd1',
        name: 'A',
        exercises: [
          ExerciseDef(id: 'e1', name: 'Supino reto', muscleGroup: 'Peito'),
          ExerciseDef(id: 'e2', name: 'Crucifixo', muscleGroup: 'Peito'),
          ExerciseDef(id: 'e3', name: 'Tríceps corda', muscleGroup: 'Tríceps'),
        ],
      );

      expect(day.emphasis, 'Peito · Tríceps');
    });

    test('sem grupos cadastrados usa o complemento do nome da divisão', () {
      const day = TrainingDay(id: 'd1', name: 'A - Peito e Tríceps');
      expect(day.emphasis, 'Peito e Tríceps');
    });

    test('nome sem prefixo é usado como está', () {
      const day = TrainingDay(id: 'd1', name: 'Full body');
      expect(day.emphasis, 'Full body');
    });
  });

  group('TrainingTransfer — vídeo no arquivo exportado', () {
    test('exportar e importar mantém as URLs dos exercícios', () {
      const plan = TrainingPlan(
        id: 'p1',
        name: 'Força A',
        days: [
          TrainingDay(
            id: 'd1',
            name: 'A - Peito',
            exercises: [
              ExerciseDef(
                id: 'e1',
                name: 'Supino reto',
                videoUrl: 'https://youtu.be/abc123',
                thumbnailUrl: 'https://img.example/supino.jpg',
              ),
            ],
          ),
        ],
      );

      final json = TrainingTransfer.export(plan);
      final imported = TrainingTransfer.decode(json);

      final exercise = imported.days.single.exercises.single;
      expect(exercise.videoUrl, 'https://youtu.be/abc123');
      expect(exercise.thumbnailUrl, 'https://img.example/supino.jpg');
    });
  });
}
