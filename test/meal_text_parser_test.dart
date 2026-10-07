import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/services/meal_text_parser.dart';

void main() {
  group('MealTextParser', () {
    test('interpreta vários alimentos com quantidades explícitas', () {
      const parser = MealTextParser();

      final items = parser.parse(
        'Comi 150g de arroz, 100g de feijão e 2 ovos',
      );

      expect(items, hasLength(3));
      expect(items[0].name, 'arroz');
      expect(items[0].quantity, 150);
      expect(items[0].unit, 'g');
      expect(items[1].name, 'feijão');
      expect(items[1].quantity, 100);
      expect(items[2].name, 'ovos');
      expect(items[2].quantity, 2);
      expect(items[2].unit, 'unidade');
    });

    test('normaliza unidades escritas por extenso', () {
      const parser = MealTextParser();

      final items = parser.parse('200 gramas de peito de frango e 1 xícara de arroz');

      expect(items, hasLength(2));
      expect(items[0].name, 'peito de frango');
      expect(items[0].quantity, 200);
      expect(items[0].unit, 'g');
      expect(items[1].name, 'arroz');
      expect(items[1].unit, 'xicara');
    });
  });
}
