import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/features/bioimpedance/import_bioimpedance_screen.dart';

void main() {
  testWidgets('tela de bioimpedância informa OCR local e revisão', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ImportBioimpedanceScreen()),
    );

    expect(find.textContaining('OCR local'), findsOneWidget);
    expect(find.textContaining('revise'), findsOneWidget);
  });
}
