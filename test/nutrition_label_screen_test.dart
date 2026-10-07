import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/features/meals/nutrition_label_screen.dart';

void main() {
  testWidgets('tela de rótulo explica OCR local e revisão humana', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: NutritionLabelScreen()),
    );

    expect(find.textContaining('OCR local'), findsOneWidget);
    expect(find.textContaining('revise'), findsWidgets);
    expect(find.textContaining('A IA'), findsNothing);
  });
}
