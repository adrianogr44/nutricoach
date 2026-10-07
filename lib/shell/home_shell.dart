import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../features/checkin/checkin_screen.dart';
import '../features/coach/coach_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/diet/diet_screen.dart';
import '../features/history/history_screen.dart';
import '../features/training/training_home.dart';
import '../state/app_state.dart';

/// Shell principal — responsivo, premium, minimalista.
/// Desktop: header com navegação + container central max-width.
/// Mobile: header simples + bottom nav com blur.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [
    DashboardScreen(),
    DietScreen(),
    TrainingHomeScreen(),
    HistoryScreen(),
    CoachScreen(),
  ];



  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth >= 900;
      final state = context.watch<AppState>();

      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppTheme.backgroundSubtle, AppTheme.background]),
          ),
          child: Column(
            children: [
              _Header(
                isDesktop: isDesktop,
                currentIndex: _index,
                onNav: (i) => setState(() => _index = i),
                onAdd: () => _onAdd(context, state),
              ),
              Expanded(
                child: AppTheme.centeredContainer(
                  child: IndexedStack(index: _index, children: _pages),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: isDesktop ? null : _BottomNav(currentIndex: _index, onTap: (i) => setState(() => _index = i)),
        floatingActionButton: isDesktop ? null : _FabAdd(onTap: () => _onAdd(context, state)),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      );
    });
  }

  void _onAdd(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl))),
      builder: (ctx) => _AddSheet(state: state),
    );
  }
}

/// Header — desktop: logo + nav tabs + +Registrar + avatar. Mobile: logo + avatar minimal.
class _Header extends StatelessWidget {
  const _Header({required this.isDesktop, required this.currentIndex, required this.onNav, required this.onAdd});
  final bool isDesktop;
  final int currentIndex;
  final ValueChanged<int> onNav;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.profile;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background.withValues(alpha: 0.72),
        border: const Border(bottom: BorderSide(color: AppTheme.border, width: 0.8)),
      ),
      child: SafeArea(
        bottom: false,
        child: AppTheme.centeredContainer(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 20, vertical: isDesktop ? 14 : 12),
            child: Row(
              children: [
                // Logo — tipografia forte, tracking, sem glow exagerado
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(8)),
                      child: const Center(child: Text('N', style: TextStyle(color: AppTheme.textOnPrimary, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.5))),
                    ),
                    const SizedBox(width: 10),
                    const Text('NutriCoach', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.5)),
                  ],
                ),
                if (isDesktop) ...[
                  const SizedBox(width: 32),
                  for (var i = 0; i < 5; i++)
                    _NavTab(
                      label: ['Hoje', 'Dieta', 'Treino', 'Histórico', 'Coach'][i],
                      selected: currentIndex == i,
                      onTap: () => onNav(i),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Registrar'),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusFull))),
                  ),
                  const SizedBox(width: 12),
                  _AvatarButton(name: profile?.name, photoBase64: profile?.photoBase64),
                ] else ...[
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.restaurant_menu, size: 20),
                    onPressed: () => Navigator.pushNamed(context, '/diet'),
                    tooltip: 'Minha Dieta',
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  _AvatarButton(name: profile?.name, photoBase64: profile?.photoBase64, small: true),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
          backgroundColor: selected ? AppTheme.surfaceLight : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusFull)),
          textStyle: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
        ),
        child: Text(label),
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({this.name, this.photoBase64, this.small = false});
  final String? name;
  final String? photoBase64;
  final bool small;
  @override
  Widget build(BuildContext context) {
    final radius = small ? 16.0 : 18.0;
    Widget content;
    if (photoBase64 != null && photoBase64!.isNotEmpty) {
      try {
        final b64 = photoBase64!.contains(',') ? photoBase64!.split(',').last : photoBase64!;
        final bytes = base64Decode(b64);
        content = CircleAvatar(radius: radius, backgroundColor: AppTheme.surfaceLight, backgroundImage: MemoryImage(bytes));
      } catch (_) {
        content = _initialAvatar(name, radius);
      }
    } else {
      content = _initialAvatar(name, radius);
    }
    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/goals'),
      customBorder: const CircleBorder(),
      child: content,
    );
  }

  Widget _initialAvatar(String? name, double radius) {
    final initial = (name ?? '?').trim().isEmpty ? '?' : (name ?? '?').trim()[0].toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.primary.withValues(alpha: 0.14),
      child: Text(initial, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 13)),
    );
  }
}

/// Bottom nav premium — 5 itens, sem + central (agora é FAB)
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.onTap});
  final int currentIndex;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.96),
        border: const Border(top: BorderSide(color: AppTheme.border, width: 0.8)),
        boxShadow: AppTheme.shadowSubtle,
      ),
      child: SafeArea(
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          height: 62,
          selectedIndex: currentIndex,
          onDestinationSelected: onTap,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined, size: 20), selectedIcon: Icon(Icons.home, size: 20), label: 'Hoje'),
            NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined, size: 20), selectedIcon: Icon(Icons.restaurant_menu, size: 20), label: 'Dieta'),
            NavigationDestination(icon: Icon(Icons.fitness_center_outlined, size: 20), selectedIcon: Icon(Icons.fitness_center, size: 20), label: 'Treino'),
            NavigationDestination(icon: Icon(Icons.calendar_month_outlined, size: 20), selectedIcon: Icon(Icons.calendar_month, size: 20), label: 'Histórico'),
            NavigationDestination(icon: Icon(Icons.lightbulb_outline, size: 20), selectedIcon: Icon(Icons.lightbulb, size: 20), label: 'Coach'),
          ],
        ),
      ),
    );
  }
}

class _FabAdd extends StatelessWidget {
  const _FabAdd({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onTap,
      backgroundColor: AppTheme.primary,
      foregroundColor: AppTheme.textOnPrimary,
      elevation: 0,
      shape: const CircleBorder(),
      child: const Icon(Icons.add, size: 26),
    );
  }
}

class _AddSheet extends StatelessWidget {
  const _AddSheet({required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.restaurant_menu, 'Minha Dieta', AppTheme.primary, () => _navigate(context, '/diet')),
      (Icons.restaurant_outlined, 'Adicionar refeição', AppTheme.primary, () => _navigate(context, '/add-meal')),
      (Icons.fitness_center_outlined, 'Academia', AppTheme.accent, () => _navigate(context, '/workout')),
      (Icons.monitor_weight_outlined, 'Peso', AppTheme.warning, () => _navigate(context, '/weight')),
      (Icons.water_drop_outlined, 'Água', AppTheme.macroWater, () => _quickWater(context)),
      (Icons.straighten_outlined, 'Medidas', AppTheme.textMuted, () => _navigate(context, '/measurements')),
    ];
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.borderStrong, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerLeft, child: Text('Registrar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.3))),
              const SizedBox(height: 12),
              for (final (icon, label, color, onTap) in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
                    title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.textMuted),
                    onTap: onTap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, String route) {
    Navigator.pop(context);
    Navigator.pushNamed(context, route);
  }

  void _quickWater(BuildContext context) {
    Navigator.pop(context);
    state.addWater(DateTime.now(), 250);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('💧 +250 ml de água registrados')));
  }
}
