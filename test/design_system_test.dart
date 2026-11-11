import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/core/theme/app_theme.dart';
import 'package:nutricoach_ai/data/repositories/local_store.dart';
import 'package:nutricoach_ai/state/app_state.dart';
import 'package:nutricoach_ai/widgets/app_components.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _makeState() async {
  SharedPreferences.setMockInitialValues({});
  final state = AppState(await LocalStore.open());
  await state.init();
  return state;
}

void main() {
  test('paleta oficial do Dark Premium está centralizada nos tokens', () {
    expect(AppTheme.background, const Color(0xFF101014));
    expect(AppTheme.surface, const Color(0xFF202027));
    expect(AppTheme.textPrimary, const Color(0xFFFFFFFF));
    expect(AppTheme.primary, const Color(0xFFC5FF5A));
    expect(AppTheme.textSecondary, const Color(0xFF8A8793));
    expect(AppTheme.textOnPrimary, AppTheme.background);
  });

  testWidgets('componentes compartilhados renderizam em tela estreita',
      (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSectionHeader(
                      title: 'Seção de teste',
                      subtitle: 'Subtítulo explicativo sem jargão.',
                      icon: Icons.insights_outlined,
                    ),
                    const SizedBox(height: 12),
                    const AppBadge(label: 'Destaque', icon: Icons.check),
                    const SizedBox(height: 12),
                    AppProgressLine(value: 0.5, label: 'Metade do caminho'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const AppInfoNote(
                title: 'Orientação',
                text: 'Uma explicação curta e útil.',
              ),
              const AppEmptyState(
                icon: Icons.inbox_outlined,
                title: 'Nada por aqui',
                message: 'Quando houver dados, eles aparecem aqui.',
              ),
              AppListTile(
                icon: Icons.settings_outlined,
                title: 'Ajustes',
                subtitle: 'Configurações do aplicativo',
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Seção de teste'), findsOneWidget);
    expect(find.text('Destaque'), findsOneWidget);
    expect(find.text('Orientação'), findsOneWidget);
    expect(find.text('Nada por aqui'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dica contextual some após "Entendi" e fica persistida',
      (tester) async {
    final state = await _makeState();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: ContextualTip(
              tipId: 'teste-persistencia',
              title: 'Dica de teste',
              message: 'Você só deve ver isto uma vez.',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dica de teste'), findsOneWidget);
    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();
    expect(find.text('Dica de teste'), findsNothing);

    // Recarrega o estado a partir do armazenamento local.
    final reloaded = AppState(await LocalStore.open());
    await reloaded.init();
    expect(reloaded.hasSeenTip('teste-persistencia'), isTrue);
  });

  testWidgets('seção expansível revela detalhes sob demanda', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: AppExpandableSection(
            title: 'Detalhes avançados',
            subtitle: 'Toque para abrir',
            icon: Icons.tune,
            children: [Text('Conteúdo interno')],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conteúdo interno'), findsNothing);
    await tester.tap(find.text('Detalhes avançados'));
    await tester.pumpAndSettle();
    expect(find.text('Conteúdo interno'), findsOneWidget);
  });
}
