import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/nutrition_calculator.dart';
import '../../data/models/user_profile.dart';
import '../../state/app_state.dart';
import '../../widgets/core_widgets.dart';

/// Metas e objetivos do usuário com cálculos automáticos (TMB/TDEE/IMC).
class MetasScreen extends StatefulWidget {
  const MetasScreen({super.key});

  @override
  State<MetasScreen> createState() => _MetasScreenState();
}

class _MetasScreenState extends State<MetasScreen> {
  late final TextEditingController _nome;
  late final TextEditingController _peso;
  late final TextEditingController _pesoDesejado;
  late final TextEditingController _altura;
  late final TextEditingController _idade;
  late final TextEditingController _metaKcal;
  late final TextEditingController _metaProteina;
  late final TextEditingController _metaAgua;

  late Sexo _sexo;
  late Objetivo _objetivo;
  late NivelAtividade _atividade;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppState>().profile;
    final profile = p ?? const UserProfile(
      pesoAtualKg: 75,
      pesoDesejadoKg: 68,
      alturaCm: 175,
      idade: 30,
      sexo: Sexo.masculino,
      objetivo: Objetivo.emagrecer,
      nivelAtividade: NivelAtividade.moderado,
    );
    _nome = TextEditingController(text: profile.name ?? '');
    _peso = TextEditingController(text: profile.pesoAtualKg.toStringAsFixed(1));
    _pesoDesejado = TextEditingController(text: profile.pesoDesejadoKg.toStringAsFixed(1));
    _altura = TextEditingController(text: profile.alturaCm.toStringAsFixed(0));
    _idade = TextEditingController(text: '${profile.idade}');
    _metaKcal = TextEditingController(
      text: (profile.metaCalorica ?? 2000).toStringAsFixed(0),
    );
    _metaProteina = TextEditingController(
      text: (profile.metaProteina ?? 120).toStringAsFixed(0),
    );
    _metaAgua = TextEditingController(
      text: (profile.metaAguaMl ?? 2500).toStringAsFixed(0),
    );
    _sexo = profile.sexo;
    _objetivo = profile.objetivo;
    _atividade = profile.nivelAtividade;
  }

  @override
  void dispose() {
    _nome.dispose();
    _peso.dispose();
    _pesoDesejado.dispose();
    _altura.dispose();
    _idade.dispose();
    _metaKcal.dispose();
    _metaProteina.dispose();
    _metaAgua.dispose();
    super.dispose();
  }

  double? _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.'));

  Future<void> _save() async {
    final state = context.read<AppState>();
    final peso = _num(_peso);
    final altura = _num(_altura);
    final idade = _num(_idade)?.round();
    if (peso == null || altura == null || idade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha os campos corretamente.')),
      );
      return;
    }
    final profile = UserProfile(
      name: _nome.text.trim().isEmpty ? null : _nome.text.trim(),
      pesoAtualKg: peso,
      pesoDesejadoKg: _num(_pesoDesejado) ?? peso,
      alturaCm: altura,
      idade: idade,
      sexo: _sexo,
      objetivo: _objetivo,
      nivelAtividade: _atividade,
      metaCalorica: _num(_metaKcal),
      metaProteina: _num(_metaProteina),
      metaCarboidrato: state.profile?.metaCarboidrato,
      metaGordura: state.profile?.metaGordura,
      metaAguaMl: _num(_metaAgua),
    );
    await state.saveProfile(profile);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Metas atualizadas')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.profile;
    final tmb = state.tmbValue;
    final tdee = state.tdeeValue;

    return Scaffold(
      appBar: AppBar(title: const Text('🎯 Metas', style: TextStyle(fontSize: 18))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (profile != null) ...[
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _info('🧬 TMB', '${tmb.round()} kcal/dia'),
                  _info('⚡ TDEE', '${tdee.round()} kcal/dia'),
                  _info(
                    '📊 IMC atual',
                    '${NutritionCalculator.imc(pesoKg: profile.pesoAtualKg, alturaCm: profile.alturaCm).toStringAsFixed(1)} '
                    '(meta: ${NutritionCalculator.pesoIdeal(alturaCm: profile.alturaCm).toStringAsFixed(1)} kg)',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          TextField(
            controller: _nome,
            decoration: const InputDecoration(labelText: 'Nome', prefixIcon: Icon(Icons.person_outline, color: AppTheme.textMuted)),
          ),
          const SizedBox(height: 12),
          const Text('Sexo', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(children: [
            for (final s in Sexo.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: Text(s.label), selected: _sexo == s, onSelected: (_) => setState(() => _sexo = s)),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _idade, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Idade'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _altura, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Altura (cm)'))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _peso, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Peso atual (kg)'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _pesoDesejado, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Peso desejado (kg)'))),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in Objetivo.values)
              ChoiceChip(label: Text(o.label), selected: _objetivo == o, onSelected: (_) => setState(() => _objetivo = o)),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final n in NivelAtividade.values)
              ChoiceChip(label: Text(n.label), selected: _atividade == n, onSelected: (_) => setState(() => _atividade = n)),
          ]),
          const SizedBox(height: 20),
          const Text('⛳ Metas (ajustáveis)', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(controller: _metaKcal, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Meta calórica (kcal)', suffixText: 'kcal')),
          const SizedBox(height: 12),
          TextField(controller: _metaProteina, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Meta de proteínas (g)', suffixText: 'g')),
          const SizedBox(height: 12),
          TextField(controller: _metaAgua, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Meta de água (ml)', suffixText: 'ml')),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('Salvar metas')),
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}