import 'package:flutter_test/flutter_test.dart';
import 'package:nutricoach_ai/data/models/daily_summary.dart';
import 'package:nutricoach_ai/data/models/food.dart';
import 'package:nutricoach_ai/data/models/meal.dart';
import 'package:nutricoach_ai/data/models/user_profile.dart';
import 'package:nutricoach_ai/services/insight_rules_engine.dart';

void main() {
  test('informa a quantidade de proteína restante sem gerar texto', () {
    const profile = UserProfile(
      pesoAtualKg: 80,
      pesoDesejadoKg: 75,
      alturaCm: 180,
      idade: 30,
      sexo: Sexo.masculino,
      objetivo: Objetivo.emagrecer,
      nivelAtividade: NivelAtividade.moderado,
      metaCalorica: 2000,
      metaProteina: 120,
      metaAguaMl: 2500,
    );
    const food = Food(
      id: 'frango',
      name: 'Frango',
      category: 'Carnes',
      kcal: 100,
      protein: 20,
      carbs: 0,
      fat: 0,
    );
    final day = DailySummary(
      date: DateTime(2026, 9, 3),
      meals: [
        Meal(
          id: 'm1',
          date: DateTime(2026, 9, 3),
          type: MealType.almoco,
          items: const [MealItem(food: food, quantityGrams: 300)],
        ),
      ],
      workouts: const [],
      waterRecords: const [],
      profile: profile,
    );

    const engine = InsightRulesEngine();
    final insights = engine.daily(day);

    expect(insights.map((e) => e.message), contains('Ainda faltam 60 g de proteína para sua meta de hoje.'));
  });

  test('gera check-in determinístico com calorias e água restantes', () {
    const profile = UserProfile(
      pesoAtualKg: 80,
      pesoDesejadoKg: 75,
      alturaCm: 180,
      idade: 30,
      sexo: Sexo.masculino,
      objetivo: Objetivo.emagrecer,
      nivelAtividade: NivelAtividade.moderado,
      metaCalorica: 2000,
      metaProteina: 120,
      metaAguaMl: 2500,
    );
    final day = DailySummary(
      date: DateTime(2026, 9, 3),
      meals: const [],
      workouts: const [],
      waterRecords: const [],
      profile: profile,
    );

    const engine = InsightRulesEngine();
    final text = engine.checkIn(day);

    expect(text, contains('Calorias: 0 / 2000 kcal'));
    expect(text, contains('Faltam 2500 ml de água'));
    expect(text, isNot(contains('IA')));
  });

  test('resume a semana usando métricas calculadas', () {
    final days = List.generate(
      7,
      (index) => DailySummary(
        date: DateTime(2026, 9, index + 1),
        meals: const [],
        workouts: const [],
        waterRecords: const [],
        profile: null,
      ),
    );

    const engine = InsightRulesEngine();
    final messages = engine.weekly(WeeklySummary(days: days));

    expect(messages.map((e) => e.message), contains('Aderência calórica da semana: 100%.'));
    expect(messages.map((e) => e.message), contains('Dias em déficit: 7 de 7.'));
  });

  test('prioriza meta calórica significativamente ultrapassada', () {
    const profile = UserProfile(
      pesoAtualKg: 80,
      pesoDesejadoKg: 75,
      alturaCm: 180,
      idade: 30,
      sexo: Sexo.masculino,
      objetivo: Objetivo.emagrecer,
      nivelAtividade: NivelAtividade.moderado,
      metaCalorica: 2000,
      metaProteina: 120,
    );
    const food = Food(
      id: 'alta-caloria',
      name: 'Alimento',
      category: 'Outros',
      kcal: 2200,
      protein: 100,
      carbs: 200,
      fat: 100,
    );
    final day = DailySummary(
      date: DateTime(2026, 9, 3),
      meals: [
        Meal(
          id: 'm',
          date: DateTime(2026, 9, 3),
          type: MealType.almoco,
          items: const [MealItem(food: food, quantityGrams: 100)],
        ),
      ],
      workouts: const [],
      waterRecords: const [],
      profile: profile,
    );

    final primary = const InsightRulesEngine().daily(day).first;

    expect(primary.priority, InsightPriority.high);
    expect(primary.title, 'Meta diária ultrapassada');
    expect(primary.message, 'Meta diária ultrapassada em 200 kcal.');
  });
}
