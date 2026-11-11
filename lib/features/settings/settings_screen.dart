import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/nutrition_calculator.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/cloud_sync.dart';
import '../../state/app_state.dart';
import '../../widgets/app_components.dart';
import '../onboarding/onboarding_intro_screen.dart';

/// Perfil e ajustes — organiza dados pessoais, corpo, alimentação, treino,
/// integrações e ajuda. Cada item leva a uma função real do app.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.profile;
    final latestWeight = state.latestWeight;
    final weight = latestWeight?.weightKg ?? profile?.pesoAtualKg;
    final bio = state.bioimpedances.isNotEmpty ? state.bioimpedances.last : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil e ajustes'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        children: [
          _ProfileHeader(
            name: profile?.name,
            photoBase64: profile?.photoBase64,
            objetivo: profile?.objetivo.label,
            meta: profile == null
                ? null
                : '${profile.pesoDesejadoKg.toStringAsFixed(1)} kg',
            onEdit: () => Navigator.pushNamed(context, '/goals'),
          ),
          const SizedBox(height: AppTheme.spaceLg),
          if (profile != null) ...[
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _Stat(
                      label: 'Peso atual',
                      value: weight == null
                          ? '—'
                          : '${weight.toStringAsFixed(1)} kg',
                    ),
                  ),
                  const _DividerVertical(),
                  Expanded(
                    child: _Stat(
                      label: 'Meta',
                      value: '${profile.pesoDesejadoKg.toStringAsFixed(1)} kg',
                    ),
                  ),
                  const _DividerVertical(),
                  Expanded(
                    child: _Stat(
                      label: 'IMC',
                      value: NutritionCalculator.imc(
                        pesoKg: weight ?? profile.pesoAtualKg,
                        alturaCm: profile.alturaCm,
                      ).toStringAsFixed(1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
          ],
          const AppSectionHeader(
            title: 'Seu corpo',
            subtitle: 'Acompanhe peso, medidas e composição corporal.',
          ),
          const SizedBox(height: AppTheme.spaceSm),
          _Group(
            children: [
              AppListTile(
                icon: Icons.monitor_weight_outlined,
                title: 'Peso',
                subtitle: latestWeight == null
                    ? 'Registre seu peso para acompanhar a tendência'
                    : 'Último: ${Formatters.shortDay(latestWeight.date)} · ${latestWeight.weightKg.toStringAsFixed(1)} kg',
                onTap: () => Navigator.pushNamed(context, '/weight'),
              ),
              AppListTile(
                icon: Icons.straighten_outlined,
                title: 'Medidas e fotos',
                subtitle: state.measurements.isEmpty
                    ? 'Registre circunferências e fotos da evolução'
                    : '${state.measurements.length} medidas registradas',
                onTap: () => Navigator.pushNamed(context, '/measurements'),
              ),
              AppListTile(
                icon: Icons.biotech_outlined,
                title: 'Bioimpedância',
                subtitle: bio == null
                    ? 'Importe um laudo InBody ou equivalente'
                    : 'Último laudo: ${Formatters.shortDay(bio.data)}',
                onTap: () => Navigator.pushNamed(context, '/bioimpedance'),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLg),
          const AppSectionHeader(
            title: 'Alimentação',
            subtitle: 'Plano, alimentos e histórico do que você comeu.',
          ),
          const SizedBox(height: AppTheme.spaceSm),
          _Group(
            children: [
              AppListTile(
                icon: Icons.restaurant_menu,
                title: 'Minha dieta',
                subtitle: 'Refeições do plano e registro do dia',
                onTap: () => Navigator.pushNamed(context, '/diet'),
              ),
              AppListTile(
                icon: Icons.menu_book_outlined,
                title: 'Banco de alimentos',
                subtitle: 'Busque alimentos e confira valores nutricionais',
                onTap: () => Navigator.pushNamed(context, '/food-db'),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLg),
          const AppSectionHeader(
            title: 'Treino e evolução',
            subtitle: 'Sua ficha, execução e histórico de treinos.',
          ),
          const SizedBox(height: AppTheme.spaceSm),
          _Group(
            children: [
              AppListTile(
                icon: Icons.fitness_center,
                title: 'Minha ficha de treino',
                subtitle: state.hasTrainingPlan
                    ? '${state.activeTrainingPlan!.days.length} divisões na ficha ativa'
                    : 'Monte ou importe sua ficha',
                onTap: () => Navigator.pushNamed(context, '/training'),
              ),
              AppListTile(
                icon: Icons.calendar_month_outlined,
                title: 'Histórico e evolução',
                subtitle: 'Dias registrados, peso e comparativos',
                onTap: () => Navigator.pushNamed(context, '/history'),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLg),
          const AppSectionHeader(
            title: 'Integrações',
            subtitle: 'Conecte dispositivos e entenda onde seus dados ficam.',
          ),
          const SizedBox(height: AppTheme.spaceSm),
          _Group(
            children: [
              AppListTile(
                icon: Icons.watch_outlined,
                title: 'Saúde e dispositivos',
                subtitle: state.healthConfig.connected
                    ? 'Conectado — passos, sono e frequência cardíaca'
                    : 'Conecte relógio, balança ou app de saúde',
                onTap: () => Navigator.pushNamed(context, '/health'),
              ),
              AppListTile(
                icon: Icons.cloud_outlined,
                title: 'Armazenamento e sincronização',
                subtitle: CloudSync.available
                    ? 'Nuvem conectada'
                    : 'Dados salvos no dispositivo (offline)',
                onTap: () => _showStorage(context),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLg),
          const AppSectionHeader(
            title: 'Ajuda e preferências',
            subtitle: 'Reveja orientações ou entenda como o app funciona.',
          ),
          const SizedBox(height: AppTheme.spaceSm),
          _Group(
            children: [
              AppListTile(
                icon: Icons.school_outlined,
                title: 'Rever introdução',
                subtitle: 'Tour curto pelas áreas do NutriCoach',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OnboardingIntroScreen(review: true),
                  ),
                ),
              ),
              AppListTile(
                icon: Icons.auto_awesome_outlined,
                title: 'Rever dicas contextuais',
                subtitle: 'Mostrar novamente as dicas de primeiro uso',
                onTap: () async {
                  await context.read<AppState>().resetOnboardingHints();
                  if (!context.mounted) return;
                  showAppSnack(
                    context,
                    'Dicas reativadas. Elas aparecem na primeira vez que você abrir cada área.',
                    icon: Icons.lightbulb_outline,
                  );
                },
              ),
              AppListTile(
                icon: Icons.lightbulb_outline,
                title: 'Como o Coach funciona',
                subtitle: 'Orientações calculadas a partir dos seus dados',
                onTap: () => Navigator.pushNamed(context, '/coach'),
              ),
              AppListTile(
                icon: Icons.info_outline,
                title: 'Sobre o NutriCoach IA',
                subtitle: 'Versão, privacidade e limitações',
                onTap: () => _showAbout(context),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLg),
          const Text(
            'NutriCoach IA · seus dados são seus.\nNada é enviado para a nuvem sem configuração.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showStorage(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Onde seus dados ficam'),
        content: Text(
          CloudSync.available
              ? 'O app está conectado à nuvem e mantém uma cópia local. '
                  'Você continua podendo usar tudo offline.'
              : 'Neste momento o app funciona 100% offline: perfil, refeições, '
                  'treinos, pesos e medidas ficam salvos apenas no seu dispositivo. '
                  'A sincronização em nuvem não está configurada.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('NutriCoach IA'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Versão 1.0.0'),
            SizedBox(height: 10),
            Text(
              'O NutriCoach organiza alimentação, treino e evolução em uma '
              'experiência simples. Os cálculos e orientações usam os dados '
              'que você registra — não substituem acompanhamento médico ou '
              'nutricional profissional.',
            ),
            SizedBox(height: 10),
            Text(
              'Privacidade: por padrão, tudo fica no seu dispositivo. '
              'A nuvem só é usada quando configurada.',
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.photoBase64,
    required this.objetivo,
    required this.meta,
    required this.onEdit,
  });

  final String? name;
  final String? photoBase64;
  final String? objetivo;
  final String? meta;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(name: name, photoBase64: photoBase64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (name == null || name!.trim().isEmpty)
                          ? 'Seu perfil'
                          : name!.trim(),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        ?objetivo,
                        if (meta != null) 'meta $meta',
                      ].join(' · '),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('Editar perfil e metas'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.photoBase64});

  final String? name;
  final String? photoBase64;

  @override
  Widget build(BuildContext context) {
    if (photoBase64 != null && photoBase64!.isNotEmpty) {
      try {
        final b64 = photoBase64!.contains(',')
            ? photoBase64!.split(',').last
            : photoBase64!;
        return CircleAvatar(
          radius: 30,
          backgroundColor: AppTheme.surfaceLight,
          backgroundImage: MemoryImage(base64Decode(b64)),
        );
      } catch (_) {
        // cai no avatar com inicial
      }
    }
    final initial = (name ?? '?').trim().isEmpty
        ? '?'
        : (name ?? '?').trim()[0].toUpperCase();
    return CircleAvatar(
      radius: 30,
      backgroundColor: AppTheme.primarySubtle,
      child: Text(
        initial,
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _DividerVertical extends StatelessWidget {
  const _DividerVertical();

  @override
  Widget build(BuildContext context) {
    return Container(width: 0.8, height: 32, color: AppTheme.border);
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border, width: 0.8),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Divider(height: 1, indent: 66, endIndent: 14),
          ],
        ],
      ),
    );
  }
}
