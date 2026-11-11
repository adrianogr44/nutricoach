import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../state/app_state.dart';
import '../../widgets/app_components.dart';

/// Primeira experiência do NutriCoach IA.
///
/// Curta, opcional e orientativa: explica o que o app faz, como registrar e
/// como navegar. Pode ser pulada e consultada de novo em Perfil e ajustes.
class OnboardingIntroScreen extends StatefulWidget {
  const OnboardingIntroScreen({super.key, this.review = false});

  /// Quando true, é aberta a partir dos ajustes e apenas fecha ao terminar.
  final bool review;

  @override
  State<OnboardingIntroScreen> createState() => _OnboardingIntroScreenState();
}

class _OnboardingIntroScreenState extends State<OnboardingIntroScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _pages = [
    _IntroPage(
      icon: Icons.eco_outlined,
      eyebrow: 'BEM-VINDO',
      title: 'Seu dia em um só lugar',
      message:
          'Alimentação, treino e evolução reunidos em uma visão simples. '
          'Você entende sua situação em poucos segundos.',
      points: [
        'Resumo do dia com o que importa agora',
        'Próxima ação sugerida, sem excesso de números',
        'Tudo salvo no seu dispositivo',
      ],
      preview: _PreviewKind.overview,
    ),
    _IntroPage(
      icon: Icons.add_circle_outline,
      eyebrow: 'REGISTRAR',
      title: 'Anotar é rápido',
      message:
          'Adicione refeições, água, peso e treinos em poucos toques. '
          'O app calcula o resto para você.',
      points: [
        'Use o botão + para registrar',
        'Deslize uma refeição para concluir',
        'Corrija qualquer registro depois',
      ],
      preview: _PreviewKind.register,
    ),
    _IntroPage(
      icon: Icons.fitness_center,
      eyebrow: 'TREINAR',
      title: 'Foco no exercício atual',
      message:
          'A execução mostra uma coisa por vez: vídeo, carga, repetições, '
          'séries e descanso. Você só precisa seguir.',
      points: [
        'Conclua série por série',
        'O descanso começa sozinho',
        'Ao final, veja o resumo do treino',
      ],
      preview: _PreviewKind.training,
    ),
    _IntroPage(
      icon: Icons.explore_outlined,
      eyebrow: 'NAVEGAR',
      title: 'Cinco áreas, sem labirinto',
      message:
          'Na barra inferior você encontra tudo. Comece pela aba que '
          'resolve o seu momento.',
      points: [
        'Hoje: seu panorama e a próxima ação',
        'Dieta, Treino e Histórico: o dia a dia',
        'Coach: orientações explicadas',
      ],
      preview: _PreviewKind.navigation,
    ),
  ];

  bool get _isLast => _index == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final state = context.read<AppState>();
    await state.completeOnboardingIntro();
    if (!mounted) return;
    if (widget.review && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_index == 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('onboarding-intro'),
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                  child: Row(
                    children: [
                      const Expanded(child: _BrandMark()),
                      const SizedBox(width: 8),
                      TextButton(
                        key: const Key('onboarding-skip'),
                        onPressed: _finish,
                        child: Text(widget.review ? 'Fechar' : 'Pular'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) {
                      final page = _pages[i];
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Illustration(page: page),
                            const SizedBox(height: AppTheme.spaceLg),
                            Text(
                              page.eyebrow,
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              page.title,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.7,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              page.message,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 15,
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spaceMd),
                            for (final point in page.points)
                              _Point(text: point),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Column(
                    children: [
                      AppStepDots(count: _pages.length, index: _index),
                      const SizedBox(height: AppTheme.spaceMd),
                      Row(
                        children: [
                          if (_index > 0)
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: OutlinedButton(
                                onPressed: _back,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(52, 52),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppTheme.radiusMd),
                                  ),
                                ),
                                child: const Icon(Icons.arrow_back, size: 20),
                              ),
                            ),
                          Expanded(
                            child: FilledButton(
                              key: Key(
                                _isLast ? 'onboarding-finish' : 'onboarding-next',
                              ),
                              onPressed: _next,
                              child: Text(
                                _isLast
                                    ? (widget.review
                                        ? 'Entendi'
                                        : 'Começar agora')
                                    : 'Continuar',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Você pode pular e rever estas dicas depois em Perfil e ajustes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(AppTheme.radiusXs),
          ),
          child: const Text(
            'N',
            style: TextStyle(
              color: AppTheme.textOnPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Flexible(
          child: Text(
            'NutriCoach',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.primarySubtle,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'IA',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _IntroPage {
  const _IntroPage({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.message,
    required this.points,
    required this.preview,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String message;
  final List<String> points;
  final _PreviewKind preview;
}

enum _PreviewKind { overview, register, training, navigation }

class _Illustration extends StatelessWidget {
  const _Illustration({required this.page});

  final _IntroPage page;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.border, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primarySubtle,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(page.icon, color: AppTheme.primary, size: 24),
              ),
              const Spacer(),
              const AppBadge(
                label: 'Guia rápido',
                icon: Icons.auto_awesome,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _preview(page.preview),
        ],
      ),
    );
  }

  Widget _preview(_PreviewKind kind) {
    switch (kind) {
      case _PreviewKind.overview:
        return Column(
          children: const [
            _MockRow(
              icon: Icons.restaurant_menu,
              label: 'Alimentação',
              hint: 'Refeições e metas',
            ),
            SizedBox(height: 8),
            _MockRow(
              icon: Icons.fitness_center,
              label: 'Treino',
              hint: 'Sessão de hoje',
            ),
            SizedBox(height: 8),
            _MockRow(
              icon: Icons.trending_up,
              label: 'Evolução',
              hint: 'Peso e medidas',
            ),
          ],
        );
      case _PreviewKind.register:
        return Row(
          children: const [
            Expanded(
              child: _MockTile(
                icon: Icons.restaurant_outlined,
                label: 'Refeição',
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _MockTile(icon: Icons.water_drop_outlined, label: 'Água'),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _MockTile(
                icon: Icons.monitor_weight_outlined,
                label: 'Peso',
              ),
            ),
          ],
        );
      case _PreviewKind.training:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _MockRow(
              icon: Icons.play_circle_outline,
              label: 'Exercício atual',
              hint: 'Vídeo e orientações',
            ),
            SizedBox(height: 8),
            _MockRow(
              icon: Icons.format_list_numbered,
              label: 'Série atual',
              hint: 'Carga e repetições',
            ),
            SizedBox(height: 8),
            _MockRow(
              icon: Icons.timer_outlined,
              label: 'Descanso',
              hint: 'Começa sozinho',
            ),
          ],
        );
      case _PreviewKind.navigation:
        return Row(
          children: const [
            Expanded(
              child: _MockNav(icon: Icons.home_outlined, label: 'Hoje', active: true),
            ),
            Expanded(
              child: _MockNav(icon: Icons.restaurant_menu, label: 'Dieta'),
            ),
            Expanded(
              child: _MockNav(icon: Icons.fitness_center, label: 'Treino'),
            ),
            Expanded(
              child: _MockNav(icon: Icons.calendar_month, label: 'Histórico'),
            ),
            Expanded(
              child: _MockNav(icon: Icons.lightbulb_outline, label: 'Coach'),
            ),
          ],
        );
    }
  }
}

class _MockRow extends StatelessWidget {
  const _MockRow({
    required this.icon,
    required this.label,
    required this.hint,
  });

  final IconData icon;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MockTile extends StatelessWidget {
  const _MockTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primary, size: 22),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MockNav extends StatelessWidget {
  const _MockNav({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.primary : AppTheme.textSecondary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 32,
          decoration: BoxDecoration(
            color: active ? AppTheme.primarySubtle : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle, size: 17, color: AppTheme.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
