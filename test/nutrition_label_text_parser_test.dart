import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/services/nutrition_label_text_parser.dart';

void main() {
  test('extrai valores por 100 g de texto OCR de rótulo', () {
    const parser = NutritionLabelTextParser();

    final label = parser.parse('''
Produto: Iogurte natural
Marca: Exemplo
INFORMAÇÃO NUTRICIONAL - 100 g
Valor energético: 61 kcal
Carboidratos: 4,7 g
Proteínas: 3,2 g
Gorduras totais: 3,3 g
Fibra alimentar: 0 g
Sódio: 56 mg
''');

    expect(label.name, 'Iogurte natural');
    expect(label.brand, 'Exemplo');
    expect(label.kcal, 61);
    expect(label.carbs, 4.7);
    expect(label.protein, 3.2);
    expect(label.fat, 3.3);
    expect(label.fiber, 0);
    expect(label.sodium, 56);
  });
}
