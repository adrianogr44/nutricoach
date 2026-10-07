import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/nutrition_calculator.dart';
import '../../data/models/body_track.dart';
import '../../data/models/user_profile.dart';
import '../../state/app_state.dart';

/// Onboarding de metas: cálculo automático de TMB, TDEE e metas.
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  late final TextEditingController _peso;
  late final TextEditingController _pesoDesejado;
  late final TextEditingController _altura;
  late final TextEditingController _idade;
  late final TextEditingController _nome;

  late Sexo _sexo;
  late Objetivo _objetivo;
  late NivelAtividade _atividade;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AppState>().profile;
    _peso = TextEditingController(
        text: profile?.pesoAtualKg.toString() ?? '75');
    _pesoDesejado = TextEditingController(
        text: profile?.pesoDesejadoKg.toString() ?? '68');
    _altura = TextEditingController(text: profile?.alturaCm.toString() ?? '175');
    _idade = TextEditingController(text: profile?.idade.toString() ?? '30');
    _nome = TextEditingController(text: profile?.name ?? '');
    _sexo = profile?.sexo ?? Sexo.masculino;
    _objetivo = profile?.objetivo ?? Objetivo.emagrecer;
    _atividade = profile?.nivelAtividade ?? NivelAtividade.moderado;
  }

  @override
  void dispose() {
    _peso.dispose();
    _pesoDesejado.dispose();
    _altura.dispose();
    _idade.dispose();
    _nome.dispose();
    super.dispose();
  }

  double? get _pesoV => double.tryParse(_peso.text.replaceAll(',', '.'));
  double? get _pesoDV => double.tryParse(_pesoDesejado.text.replaceAll(',', '.'));
  double? get _alturaV => double.tryParse(_altura.text.replaceAll(',', '.'));
  int? get _idadeV => int.tryParse(_idade.text);

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();
    if (_pesoV == null || _pesoDV == null || _alturaV == null || _idadeV == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos corretamente.')),
      );
      return;
    }
    final state = context.read<AppState>();
    final current = state.profile;
    final base = current != null
        // Preserva as metas já calculadas (ex.: com a TMB medida na
        // bioimpedância) — computeGoals só preenche o que estiver null.
        ? state.computeGoals(current.copyWith(
            name: _nome.text.trim().isEmpty ? null : _nome.text.trim(),
            pesoAtualKg: _pesoV!,
            pesoDesejadoKg: _pesoDV!,
            alturaCm: _alturaV!,
            idade: _idadeV!,
            sexo: _sexo,
            objetivo: _objetivo,
            nivelAtividade: _atividade,
          ))
        : state.computeGoals(UserProfile(
            name: _nome.text.trim().isEmpty ? null : _nome.text.trim(),
            pesoAtualKg: _pesoV!,
            pesoDesejadoKg: _pesoDV!,
            alturaCm: _alturaV!,
            idade: _idadeV!,
            sexo: _sexo,
            objetivo: _objetivo,
            nivelAtividade: _atividade,
          ));
    await state.saveProfile(base);
    // Registro inicial de peso
    if (current == null) {
      await state.addWeight(WeightRecord(date: DateTime.now(), weightKg: _pesoV!));
    }
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (Navigator.of(context).canPop())
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back,
                          color: AppTheme.textPrimary),
                      tooltip: 'Voltar',
                    ),
                  const Icon(Icons.psychology, color: AppTheme.primary, size: 34),
                  const SizedBox(width: 12),
                  const Text(
                    'NutriCoach AI',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                'Suas metas',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Vamos calcular seu TMB, TDEE e metas personalizadas.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nome,
                decoration: const InputDecoration(
                  labelText: 'Nome (opcional)',
                  prefixIcon: Icon(Icons.person_outline, color: AppTheme.textMuted),
                ),
              ),
              const SizedBox(height: 14),
              const _GroupLabel('Sexo'),
              Row(children: [
                for (final s in Sexo.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(s.label),
                        selected: _sexo == s,
                        onSelected: (_) => setState(() => _sexo = s),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 14),
              const _GroupLabel('Idade e altura'),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _idade,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Idade'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _altura,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Altura (cm)'),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              const _GroupLabel('Peso'),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _peso,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Peso atual (kg)',
                      suffixText: 'kg',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _pesoDesejado,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Peso desejado (kg)',
                      suffixText: 'kg',
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              const _GroupLabel('Objetivo'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final o in Objetivo.values)
                  ChoiceChip(
                    label: Text(o.label),
                    selected: _objetivo == o,
                    onSelected: (_) => setState(() => _objetivo = o),
                  ),
              ]),
              const SizedBox(height: 14),
              const _GroupLabel('Nível de atividade'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final n in NivelAtividade.values)
                  ChoiceChip(
                    label: Text(n.label),
                    selected: _atividade == n,
                    onSelected: (_) => setState(() => _atividade = n),
                  ),
              ]),
              const SizedBox(height: 24),
              _Preview(
                peso: _pesoV ?? 0,
                altura: _alturaV ?? 0,
                idade: _idadeV ?? 0,
                sexo: _sexo,
                atividade: _atividade,
                objetivo: _objetivo,
              ),
              const SizedBox(height: 28),
              FilledButton(onPressed: _salvar, child: const Text('Continuar')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Prévia dos cálculos ao vivo.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.peso,
    required this.altura,
    required this.idade,
    required this.sexo,
    required this.atividade,
    required this.objetivo,
  });

  final double peso;
  final double altura;
  final int idade;
  final Sexo sexo;
  final NivelAtividade atividade;
  final Objetivo objetivo;

  @override
  Widget build(BuildContext context) {
    if (peso <= 0 || altura <= 0 || idade <= 0) {
      return const SizedBox.shrink();
    }
    final tmb = NutritionCalculator.tmb(
      pesoKg: peso,
      alturaCm: altura,
      idade: idade,
      sexo: sexo,
    );
    final tdee = NutritionCalculator.tdee(tmb: tmb, nivel: atividade);
    final meta = NutritionCalculator.metaCalorica(tdee: tdee, objetivo: objetivo);
    final prot = NutritionCalculator.metaProteina(pesoKg: peso, objetivo: objetivo);
    final agua = NutritionCalculator.metaAgua(pesoKg: peso);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary.withValues(alpha: 0.12), AppTheme.surface],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔮 Cálculos automáticos',
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _row('TMB (Mifflin-St Jeor)', '${tmb.round()} kcal'),
          _row('TDEE', '${tdee.round()} kcal'),
          _row('Meta calórica', '${meta.round()} kcal'),
          _row('Meta proteínas', '${prot.round()} g'),
          _row('Meta água', '${agua.round()} ml'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          Text(
            value,
            style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}