import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/repositories/local_store.dart';
import 'features/bioimpedance/import_bioimpedance_screen.dart';
import 'features/coach/coach_screen.dart';
import 'features/diet/diet_screen.dart';
import 'features/food_db/food_db_screen.dart';
import 'features/measurements/measurements_screen.dart';
import 'features/meals/add_meal_screen.dart';
import 'features/metas/metas_screen.dart';
import 'features/onboarding/bio_onboarding_screen.dart';
import 'features/onboarding/goals_screen.dart';
import 'features/training/training_home.dart';
import 'features/weight/weight_screen.dart';
import 'features/workout/workout_screen.dart';
import 'shell/home_shell.dart';
import 'state/app_state.dart';

class NutriCoachApp extends StatelessWidget {
  const NutriCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LocalStore>(
      future: LocalStore.open(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return MaterialApp(
            title: 'NutriCoach',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark(),
            home: const Scaffold(
              backgroundColor: AppTheme.background,
              body: Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            ),
          );
        }
        final store = snapshot.data!;
        return ChangeNotifierProvider(
          create: (_) {
            final state = AppState(store);
            unawaited(state.init());
            return state;
          },
          child: const _Root(),
        );
      },
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriCoach',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routes: {
        '/add-meal': (_) => const AddMealScreen(),
        '/workout': (_) => const WorkoutScreen(),
        '/weight': (_) => const WeightScreen(),
        '/measurements': (_) => const MeasurementsScreen(),
        '/goals': (_) => const MetasScreen(),
        '/food-db': (_) => const FoodDbScreen(),
        '/coach': (_) => const CoachScreen(),
        '/bioimpedance': (_) => const ImportBioimpedanceScreen(),
        '/diet': (_) => const DietScreen(),
        '/training': (_) => const TrainingHomeScreen(),
      },
      home: const _Gate(),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.initialized) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }
    if (!state.hasProfile) {
      if (state.bioimpedances.isEmpty) {
        return const BioOnboardingScreen();
      }
      return const GoalsScreen();
    }
    return const HomeShell();
  }
}