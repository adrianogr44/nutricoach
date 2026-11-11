import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/features/bioimpedance/bioimpedance_json_dialog.dart';
import 'package:nutricoach_ai/services/bioimpedance_text_parser.dart';

class _DialogResult {
  BioimpedanceParseResult? value;
}

/// Abre o diálogo dentro de um app de teste e devolve o contêiner do resultado.
Future<_DialogResult> _openDialog(WidgetTester tester) async {
  final holder = _DialogResult();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                holder.value = await showBioimpedanceJsonDialog(context);
              },
              child: const Text('abrir json'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir json'));
  await tester.pumpAndSettle();
  expect(find.text('Preencher com JSON'), findsOneWidget);
  return holder;
}

void main() {
  testWidgets('lê o JSON informado e devolve o resultado', (tester) async {
    final result = await _openDialog(tester);

    await tester.enterText(
      find.byType(TextField),
      '{"data": "2026-09-03", "pesoKg": 121.2, "imc": 35.4, "gorduraPct": 40.4}',
    );
    await tester.tap(find.text('Ler JSON'));
    await tester.pumpAndSettle();

    expect(result.value, isNotNull);
    expect(result.value!.bioimpedance.data, DateTime(2026, 9, 3));
    expect(result.value!.bioimpedance.pesoKg, 121.2);
    expect(result.value!.bioimpedance.imc, 35.4);
    expect(result.value!.bioimpedance.gorduraPct, 40.4);
    expect(find.text('Preencher com JSON'), findsNothing);
  });

  testWidgets('mantém o diálogo aberto e exibe o erro do JSON inválido', (tester) async {
    final result = await _openDialog(tester);

    await tester.enterText(find.byType(TextField), '{"pesoKg": 90,}');
    await tester.tap(find.text('Ler JSON'));
    await tester.pumpAndSettle();

    expect(result.value, isNull);
    expect(find.text('Preencher com JSON'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SelectableText && (widget.data ?? '').contains('JSON inválido'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('o botão Exemplo preenche um JSON que pode ser lido', (tester) async {
    final result = await _openDialog(tester);

    await tester.tap(find.text('Exemplo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ler JSON'));
    await tester.pumpAndSettle();

    expect(result.value, isNotNull);
    expect(result.value!.bioimpedance.pesoKg, 121.2);
    expect(result.value!.bioimpedance.massaMuscularEsqueleticaKg, 41.1);
  });
}
