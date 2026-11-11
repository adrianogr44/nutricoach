import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/data/models/bioimpedance.dart';
import 'package:nutricoach_ai/features/bioimpedance/bioimpedance_review.dart';
import 'package:nutricoach_ai/services/bioimpedance_text_parser.dart';

/// A revisão é longa; usa uma tela alta para todos os campos ficarem montados.
void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pumpReview(
  WidgetTester tester,
  BioimpedanceParseResult result, {
  required ValueChanged<Bioimpedance> onApply,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BioimpedanceReview(
          result: result,
          onApply: onApply,
          onDiscard: () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('revisão mostra os campos, avisa o que faltou e aceita correção', (tester) async {
    _useTallScreen(tester);
    final result = const BioimpedanceTextParser().parseDetailed('''
Data: 03/09/2026
Peso 121,2 kg
IMC 35,4
Massa muscular esquelética 41,1 kg
''');

    Bioimpedance? aplicado;
    await _pumpReview(tester, result, onApply: (bio) => aplicado = bio);

    // Campos reconhecidos vêm preenchidos.
    expect(find.text('121,2'), findsOneWidget);
    expect(find.text('35,4'), findsOneWidget);
    expect(find.text('41,1'), findsOneWidget);

    // Campos ausentes aparecem como não identificados.
    expect(find.text('não identificado'), findsWidgets);

    // Dados segmentares são seções separadas e editáveis.
    expect(find.text('Massa magra segmentar'), findsOneWidget);
    expect(find.text('Gordura segmentar'), findsOneWidget);
    expect(find.text('Tronco'), findsNWidgets(2));

    // Corrige o peso manualmente e aplica.
    final pesoRow = find
        .ancestor(of: find.text('Peso'), matching: find.byType(Row))
        .first;
    final pesoField = find.descendant(of: pesoRow, matching: find.byType(TextField));
    await tester.enterText(pesoField, '120,5');

    await tester.tap(find.text('Aplicar ao perfil'));
    await tester.pumpAndSettle();

    expect(aplicado, isNotNull);
    expect(aplicado!.pesoKg, 120.5);
    expect(aplicado!.imc, 35.4);
    expect(aplicado!.massaMuscularEsqueleticaKg, 41.1);
    expect(aplicado!.data, DateTime(2026, 9, 3));
  });

  testWidgets('revisão permite preencher um segmento que o laudo não trouxe', (tester) async {
    _useTallScreen(tester);
    final result = const BioimpedanceTextParser().parseDetailed('Peso 92,4 kg');

    Bioimpedance? aplicado;
    await _pumpReview(tester, result, onApply: (bio) => aplicado = bio);

    final troncoRow = find
        .ancestor(of: find.text('Tronco').first, matching: find.byType(Row))
        .first;
    final campos = find.descendant(of: troncoRow, matching: find.byType(TextField));
    await tester.enterText(campos.first, '24,8');

    await tester.tap(find.text('Aplicar ao perfil'));
    await tester.pumpAndSettle();

    expect(aplicado?.massaMagraSegmentar?.trunk, 24.8);
    expect(aplicado?.pesoKg, 92.4);
  });

  testWidgets('data inválida impede aplicar e mostra aviso', (tester) async {
    _useTallScreen(tester);
    final result = const BioimpedanceTextParser().parseDetailed('Peso 92,4 kg');

    var aplicou = false;
    await _pumpReview(tester, result, onApply: (_) => aplicou = true);

    final dataRow = find
        .ancestor(of: find.text('Data da avaliação'), matching: find.byType(Row))
        .first;
    final dataField = find.descendant(of: dataRow, matching: find.byType(TextField));
    await tester.enterText(dataField, 'sem data');

    await tester.tap(find.text('Aplicar ao perfil'));
    await tester.pumpAndSettle();

    expect(aplicou, isFalse);
    expect(find.text('Use o formato dd/mm/aaaa.'), findsOneWidget);
  });
}
