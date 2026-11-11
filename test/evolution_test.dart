import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/core/theme/app_theme.dart';
import 'package:nutricoach_ai/data/models/body_track.dart';
import 'package:nutricoach_ai/data/models/user_profile.dart';
import 'package:nutricoach_ai/data/repositories/local_store.dart';
import 'package:nutricoach_ai/features/history/history_screen.dart';
import 'package:nutricoach_ai/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _state({required bool withEvolution}) async {
  SharedPreferences.setMockInitialValues({});
  final state = AppState(await LocalStore.open());
  await state.init();
  await state.saveProfile(
    const UserProfile(
      name: 'Ana',
      pesoAtualKg: 72,
      pesoDesejadoKg: 66,
      alturaCm: 168,
      idade: 31,
      sexo: Sexo.feminino,
      objetivo: Objetivo.emagrecer,
      nivelAtividade: NivelAtividade.moderado,
    ),
  );
  if (!withEvolution) return state;

  final now = DateTime.now();
  await state.addWeight(
    WeightRecord(date: now.subtract(const Duration(days: 20)), weightKg: 72.6),
  );
  await state.addWeight(
    WeightRecord(date: now.subtract(const Duration(days: 8)), weightKg: 72.2),
  );
  await state.addWeight(WeightRecord(date: now, weightKg: 72));
  await state.addMeasurement(
    BodyMeasurement(
      date: now.subtract(const Duration(days: 3)),
      type: MeasureType.abdominal,
      valueCm: 84,
    ),
  );
  return state;
}

Future<void> _pump(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(390, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const HistoryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('evolução mostra tendência real e explica o gráfico',
      (tester) async {
    await _pump(tester, await _state(withEvolution: true));

    expect(find.text('Evolução e histórico'), findsOneWidget);
    expect(find.text('Evolução do peso'), findsOneWidget);
    expect(
      find.textContaining('3 pesagens em 90 dias'),
      findsOneWidget,
    );
    expect(find.textContaining('0,6 kg'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.textContaining('o que importa é a tendência'), findsOneWidget);

    expect(find.text('Medidas mais recentes'), findsOneWidget);
    expect(find.text('Abdominal'), findsOneWidget);
    expect(find.textContaining('84,0 cm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sem pesagens suficientes não inventa conclusões', (tester) async {
    await _pump(tester, await _state(withEvolution: false));

    expect(find.text('Ainda não há tendência'), findsOneWidget);
    expect(
      find.textContaining('Um registro isolado não mostra evolução'),
      findsOneWidget,
    );
    expect(find.text('Registrar peso'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
