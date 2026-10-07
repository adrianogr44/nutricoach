import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/meal.dart';
import '../../state/app_state.dart';
import 'food_search_screen.dart';
import 'manual_meal_screen.dart';
import 'meal_text_entry.dart';
import 'nutrition_label_screen.dart';

/// Hub "Adicionar refeição": Texto livre, Pesquisa, OCR local, Favoritos.
class AddMealScreen extends StatelessWidget {
  const AddMealScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar refeição', style: TextStyle(fontSize: 18))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Option(
            icon: Icons.edit_note_outlined,
            iconColor: AppTheme.primary,
            title: 'Descrever refeição',
            subtitle: '"200g arroz, 100g feijão, 150g frango"',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MealTextEntryScreen()),
            ),
          ),
          const SizedBox(height: 14),
          _Option(
            icon: Icons.restaurant_outlined,
            iconColor: AppTheme.success,
            title: 'Montar refeição completa',
            subtitle: 'Vários alimentos · medidas caseiras · total calculado',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManualMealScreen()),
            ),
          ),
          const SizedBox(height: 14),
          _Option(
            icon: Icons.search,
            iconColor: AppTheme.accent,
            title: 'Pesquisar alimento',
            subtitle: 'Banco TACO/TBCA + busca rápida',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FoodSearchScreen()),
            ),
          ),
          const SizedBox(height: 14),
          _Option(
            icon: Icons.photo_camera_outlined,
            iconColor: AppTheme.warning,
            title: 'Foto da tabela nutricional',
            subtitle: 'OCR local — valores por 100 g',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NutritionLabelScreen()),
            ),
          ),
          const SizedBox(height: 14),
          _Option(
            icon: Icons.favorite,
            iconColor: AppTheme.danger,
            title: 'Favoritos',
            subtitle: 'Suas comidas mais usadas',
            onTap: () {
              final state = context.read<AppState>();
              if (state.favorites.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Você ainda não tem favoritos. Toque na estrela '
                        'em um alimento para salvar.'),
                  ),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FoodSearchScreen(onlyFavorites: true),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            'Como funciona',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary, fontSize: 15),
          ),
          const SizedBox(height: 8),
          const Text(
            'Descreva alimentos com quantidade (ex: "200g arroz") e o app '
            'identifica via parser local. Para produtos com rótulo, o OCR local '
            'lê a tabela nutricional. Em seguida, o app consulta o banco '
            'nutricional brasileiro (TACO/TBCA) para calcular kcal, proteínas, '
            'carboidratos, gorduras, fibras e sódio. Nenhum valor é inventado.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Seleciona a refeição (Café da manhã, Almoço...) e salva.
Future<MealType?> showMealTypePicker(BuildContext context, {MealType? initial}) {
  return showModalBottomSheet<MealType>(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Qual refeição?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          for (final t in MealType.values)
            ListTile(
              leading: Text(t.emoji, style: const TextStyle(fontSize: 20)),
              title: Text(t.label),
              selected: initial == t,
              selectedTileColor: AppTheme.primary.withValues(alpha: 0.08),
              onTap: () => Navigator.pop(context, t),
            ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}