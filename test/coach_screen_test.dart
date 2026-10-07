import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/data/repositories/local_store.dart';
import 'package:nutricoach_ai/features/coach/coach_screen.dart';
import 'package:nutricoach_ai/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('coach é apresentado como insights locais sem chat', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(await LocalStore.open());
    await state.init();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: CoachScreen()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Insights'), findsWidgets);
    expect(find.textContaining('Coach IA'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });
}
