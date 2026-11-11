# NutriCoach AI — Contexto completo do app (para LLM)

> **Como usar**: cole este arquivo inteiro como contexto inicial em uma conversa nova do GPT antes de pedir a geração de prompts, telas, copy ou regras. Tudo aqui é extraído do código-fonte real (Flutter) do projeto.
> Projeto: `nutricoach_ai` · Flutter 3.44.8 / Dart ^3.12.2 · idioma do app e das respostas: **português do Brasil**.

---

## 1. O que é o app

App multiplataforma (web, Android, iOS, desktop) focado em **emagrecimento, nutrição e academia**, para usuário brasileiro.

**Proposta central**: registrar comida de forma rápida (texto livre, pesquisa, código de barras, foto de rótulo), montar dieta e treino, e mostrar no dia a dia (aba "Hoje") calorias, macros, água, treino e insights acionáveis.

**Princípio de arquitetura (declarado no README e no código)**:

- **Nenhum valor nutricional é inventado.** Nutriente só vem de `FoodDatabase` (TACO 4ª ed. + TBCA 2023), OpenFoodFacts ou de um parser local.
- **Sem IA generativa / sem LLM / sem chat.** Insights são produzidos por `InsightRulesEngine` (regras determinísticas). Nenhum endpoint de LLM existe no app.
- **Offline-first**: SharedPreferences local é a fonte de verdade; Firebase/Firestore é espelho opcional e hoje está inerte (`_userId == null`).
- **Validação humana** antes de salvar tudo que vem de OCR/importação.

---

## 2. Regras inegociáveis para qualquer prompt gerado

1. Nunca pedir/sugerir que a IA calcule ou " chute" kcal/macros — só `FoodDatabase`, `OpenFoodFactsApi` ou valores já salvos no estado.
2. Nunca introduzir chat, geração de texto por LLM, "pergunte à IA" — o copy do Coach sempre termina com "Sem IA generativa".
3. Todo texto de UI em **pt-BR**, tom direto, curto, sem emoji decorativo (emojis só onde o app já usa como status: 🟢 🟡 🔴, 🏋️, 💧).
4. Mobile-first: alvos de toque ≥ 44px, listas roláveis com padding inferior 88px (o FAB flutua acima da bottom bar).
5. Design system escuro obrigatório (cores/fontes da seção 12) — nada de tema claro, nada de cores fora da paleta.
6. Tela nova precisa de: entrada por rota nomeada **ou** aba do `HomeShell`, acesso pelo bottom sheet "Registrar" quando for ação de registro, e estado via `AppState` (ChangeNotifier) + persistência no `LocalStore`.
7. Regras de negócio novas entram como teste unitário em `test/`.

---

## 3. Stack e estrutura

**Dependências principais** (`pubspec.yaml`): `provider` (estado), `fl_chart` (gráficos), `shared_preferences` (persistência), `uuid`, `intl`, `google_fonts`, `http`, `mobile_scanner` (código de barras), `google_mlkit_text_recognition` (OCR, só Android/iOS), `image_picker`, `file_picker`, `pdfrx` (PDF), `image` (compressão), `firebase_core/auth/cloud_firestore` (opcional), `crypto`.

**Layout de `lib/`**:

```
lib/
├── main.dart                  # pdfrxFlutterInitialize + runApp
├── app.dart                   # provider, rotas nomeadas, gate de onboarding
├── core/
│   ├── theme/app_theme.dart   # tema escuro, cores, raios, fontes
│   ├── constants.dart         # kcal/g, fonte do banco, enum DayStatus
│   └── utils/                 # nutrition_calculator, formatters, image_utils
├── config/                    # app_config.dart, secrets.dart (Firebase vazio)
├── data/
│   ├── models/                # food, meal, diet, training, tracking, body_track,
│   │                          # bioimpedance, user_profile, daily_summary
│   ├── food_db/               # taco_foods, food_database, open_food_facts_api,
│   │                          # food_data_updater
│   └── repositories/          # local_store (SP), cloud_sync (Firestore inerte)
├── services/                  # meal_text_parser, insight_rules_engine,
│   │                          # nutrition_label_text_parser, bioimpedance_text_parser,
│   │                          # device_text_recognizer, household_measure
├── state/app_state.dart       # ChangeNotifier único (866 linhas)
├── shell/home_shell.dart      # abas, header, bottom nav, FAB, sheet "Registrar"
├── features/                  # 17 telas
└── widgets/core_widgets.dart  # ProgressRing, MetricCard, GradientBar, SectionHeader,
                               # StatusBadge, GlassCard
```

---

## 4. Bootstrap, gate e navegação

**`lib/app.dart`**

- `NutriCoachApp` → `FutureBuilder<LocalStore>`; depois cria `ChangeNotifierProvider(create: AppState(store)..init())`.
- `_Gate`: `!initialized` → spinner; `!hasProfile` → `BioOnboardingScreen` (se não há bioimpedância) ou `GoalsScreen`; senão `HomeShell`.

**Rotas nomeadas** (10):

| Rota | Tela |
|---|---|
| `/add-meal` | `AddMealScreen` |
| `/workout` | `WorkoutScreen` (academia manual) |
| `/weight` | `WeightScreen` |
| `/measurements` | `MeasurementsScreen` |
| `/goals` | `MetasScreen` |
| `/food-db` | `FoodDbScreen` |
| `/coach` | `CoachScreen` |
| `/bioimpedance` | `ImportBioimpedanceScreen` |
| `/health` | `HealthScreen` |
| `/diet` | `DietScreen` |
| `/training` | `TrainingHomeScreen` |

O `/history` está registrado em `MaterialApp.routes` (`lib/app.dart`), junto com `/health` (tela de saúde do dispositivo). Também referenciado por insights e ações rápidas: `Navigator.pushNamed(context, '/history')` funciona e a aba 3 do shell continua abrindo a mesma tela.

**`lib/shell/home_shell.dart` — HomeShell**

- Abas (`IndexedStack`, índices 0–4): **Hoje** (`DashboardScreen`), **Dieta** (`DietScreen`), **Treino** (`TrainingHomeScreen`), **Histórico** (`HistoryScreen`), **Coach** (`CoachScreen`).
- Desktop (`width ≥ 900`): sem bottom bar e **sem FAB**; header com tabs + botão `FilledButton` **"Registrar"** + avatar (avatar → `/goals`).
- Mobile: `NavigationBar` (altura 62) + FAB "+" (`FloatingActionButtonLocation.endFloat`, acima da barra — nunca cobre a aba Treino) + atalho `Icons.restaurant_menu` → `/diet`.
- **Bottom sheet "Registrar"** (`_AddSheet`, `showModalBottomSheet(isScrollControlled: true)`), 6 ações:
  `Minha Dieta → /diet` · `Adicionar refeição → /add-meal` · `Academia → /workout` · `Peso → /weight` · `Água → state.addWater(250ml)` · `Medidas → /measurements`.

---

## 5. Telas (features)

| Tela | Arquivo | O que o usuário faz |
|---|---|---|
| **Hoje (dashboard)** | `features/dashboard/dashboard_screen.dart` | Hero de kcal animado, insight inline, macros, água, stats secundários (academia/peso/IMC), gráfico 7 dias (`LineChart` + linha de meta tracejada), timeline de dieta do dia com botão "Registrar"/"Editar", timeline de treino com "Iniciar treino →", "Extras do dia", pull-to-refresh |
| **Adicionar refeição** | `features/meals/add_meal_screen.dart` | 5 caminhos: descrever em texto, montar manualmente, pesquisar alimento, foto da tabela nutricional (OCR), favoritos |
| **Texto livre** | `features/meals/meal_text_entry.dart` | digita "200g arroz, 100g frango" → `MealTextParser` → item sem match abre `FoodSearchScreen` como seletor |
| **Manual** | `features/meals/manual_meal_screen.dart` | `FoodSearchScreen(compactPicker)` + conversão de medida caseira |
| **Pesquisa** | `features/meals/food_search_screen.dart` | busca local + seção OpenFoodFacts |
| **Código de barras** | `features/meals/barcode_screen.dart` | `FoodDatabase.byBarcode` → fallback `OpenFoodFactsApi` |
| **OCR rótulo** | `features/meals/nutrition_label_screen.dart` | `DeviceTextRecognizer` → `NutritionLabelTextParser` → revisão humana → salvar |
| **Dieta** | `features/diet/diet_screen.dart` + `diet_meal_editor.dart` | cria planos, refeições, itens (unidade caseira→gramas), totais, status do dia |
| **Treino** | `features/training/{training_home,training_editor,active_training_screen}.dart` | planos semanais, dias, exercícios, sessão ativa (séries, descanso, progressão) |
| **Academia manual** | `features/workout/workout_screen.dart` | kcal + tempo + obs → `addWorkout` |
| **Peso / Medidas** | `weight_screen.dart`, `measurements_screen.dart` | `WeightRecord` (upsert por dia), `BodyMeasurement` |
| **Metas** | `features/metas/metas_screen.dart` | TMB/TDEE/IMC/metas e edição do perfil |
| **Histórico** | `features/history/history_screen.dart` | grade mensal com emoji do dia (🟢🟡🔴), detalhe do dia (macros + fibras 30 g + sódio 2000 mg + extras), resumo semanal com ações navegáveis |
| **Coach** | `features/coach/coach_screen.dart` | "Foco de hoje" (insight principal), insights diários/semanais ordenados por prioridade, "Ações rápidas" (6 chips), rodapé "Sem IA generativa" |
| **Banco de alimentos** | `features/food_db/food_db_screen.dart` | busca, filtro por categoria, detalhe, favoritos |
| **Bioimpedância** | `features/bioimpedance/import_bioimpedance_screen.dart` | câmera/galeria/texto/PDF/JSON → parser extensível → revisão editável (geral + segmentar) → salvar |
| **JSON de bio** | `features/bioimpedance/bioimpedance_json_dialog.dart` | diálogo "Preencher com JSON": colar da área de transferência, exemplo, erro amigável; usado na importação e no onboarding |
| **Revisão de bio** | `features/bioimpedance/bioimpedance_review.dart` | widget compartilhado: todos os campos editáveis, "não identificado", avisos e texto não reconhecido preservado |
| **Saúde** | `features/health/health_screen.dart` | conectar Health Connect/Apple Health, sincronizar passos/sono/FC/treinos/peso, aplicar peso ao histórico |
| **Onboarding bio** | `features/onboarding/bio_onboarding_screen.dart` | mesma UI da importação + "Preencher manualmente" |
| **Onboarding metas** | `features/onboarding/goals_screen.dart` | sexo/objetivo/atividade + preview ao vivo de TMB/TDEE/meta/proteína/água |
| **Check-in / Login** | `checkin/checkin_screen.dart`, `auth/login_screen.dart` | **órfãos** — não estão ligados a rota nem aba hoje |

---

## 6. Estado — `lib/state/app_state.dart` (API que os prompts podem invocar)

`AppState extends ChangeNotifier`, singleton no provider. Serviços embutidos: `mealParser`, `insights`, `bioimpedanceParser`, `labelParser`.

**Getters**: `initialized`, `profile`, `hasProfile`, `meals`, `workouts`, `weights`, `measurements`, `photos`, `water`, `bioimpedances`, `favorites`, `customFoods`, `dietPlans`, `activeDiet`, `hasDiet`, `trainingPlans`, `activeTrainingPlan`, `hasTrainingPlan`, `trainingSessions`, `activeTrainingSession`, `foodByIdMap`, `today` (DailySummary), `latestWeight`, `tmbValue`, `tdeeValue`, `pesoPerdidoKg`, `saving`, `statusMessage`, `userEmail`.

**Refeições/diário**
`buildMeal({date, type, items, rawText})` · `addMeal` · `removeMeal` · `mealsOn(date)` · `summaryFor(date, {profile})` · `dashboardMetrics()` (registro: kcal, protein, carbs, fat, water, burned, weight, status, balance) · `lastDays(n)` · `thisWeek()`.

**Dieta**
`createDiet(name)` · `updateDiet` · `deleteDiet` · `setActiveDiet` · `addDietMeal` · `updateDietMeal` · `removeDietMeal` · `reorderDietMeals` · `addDietMealItem` · `updateDietMealItem` · `removeDietMealItem` · `logDietMeal({dietMeal, date, selectedIndices, quantityOverrides, substitutions, typeOverride})` · `dietMealStatusFor(...)` → `planned | partially | consumed`.
`logDietMeal` grava um `Meal` com `rawText: 'Dieta:<id>:<nome>'` (é assim que o dashboard sabe o que já foi registrado).

**Treino**
`createTrainingPlan` · `updateTrainingPlan` · `deleteTrainingPlan` · `addTrainingDay` · `updateTrainingDay` · `removeTrainingDay` · `addExerciseToDay` · `startTrainingSession(planId, dayId)` (cria `TrainingSession` + `Workout(source:'training')` com `kcalBurned: 0`) · `addSetToSession` · `finishTrainingSession` · `sessionsForDay`.

**Corpo/registo**
`saveProfile` · `updateProfilePhoto(base64)` · `computeGoals(base)` (só preenche metas nulas) · `addWeight` (upsert por dia) · `addMeasurement` · `addPhoto`/`removePhoto` · `addWorkout`/`removeWorkout` · `addWater(date, ml)`/`waterFor(date)` · `isFavorite`/`toggleFavorite` · `addCustomFood` · `allSearchableFoods(query, {limit: 40})` · `importBioimpedance(bio)` (dedup por data, salva peso, cria/atualiza perfil, usa `bio.tmbKcal` se > 0) · `setUserEmail` · `setStatus`.

---

## 7. Modelos de dados (`lib/data/models/`)

- **`food.dart`**: `Food(id, name, category, kcal, protein, carbs, fat, fiber?, sodium?, standardPortionGrams?, aliases?, source, barcode?, …)` + `toJson/fromJson`.
- **`meal.dart`**: `MealType {cafeDaManha, almoco, lanche, jantar, ceia, outro}` (extensão com `label` e `emoji`) · `MealItem(food, quantityGrams)` · `Meal(id, date, type, items, rawText?, createdAt)`.
- **`daily_summary.dart`**: `DailySummary(date, meals, workouts, waterRecords, weightKg?, profile)` com `kcalConsumed`, `protein/carbs/fat/fiber/sodium`, `waterMl`, `kcalBurned`, `netCalories`, `balanceKcal = metaKcal − netCalories`, `status (DayStatus)`, `WeeklySummary(days)`.
- **`user_profile.dart`**: `Sexo`, `Objetivo {emagrecer, manter, ganharMassa}`, `NivelAtividade` (fatores 1.2 / 1.375 / 1.55 / 1.725 / 1.9), peso/altura/idade/metas/`photoBase64`.
- **`tracking.dart`**: `Workout(id, date, kcalBurned, source)` · `WaterRecord(date, amountMl)`.
- **`body_track.dart`**: `WeightRecord(date, weightKg)` · `MeasureType` · `BodyMeasurement` · `ProgressPhoto`.
- **`diet.dart`**: `DietMealItem(foodId, quantity, unit, customGramsPerUnit?, foodSnapshot)` · `DietMeal(id, name, time?, order, items)` · `DietPlan(id, name, meals, createdAt, updatedAt, isActive)`.
- **`training.dart`**: `ExerciseDef`, `TrainingDay`, `TrainingPlan`, `TrainingSession`, `TrainingSet`, `ExerciseSession`, `TrainingStatus {active, completed}`.
- **`bioimpedance.dart`**: `Bioimpedance(data, pesoKg?, alturaCm?, idade?, imc?, gorduraPct?, gorduraKg?, massaMuscularKg?, massaMuscularEsqueleticaKg?, aguaL?, proteinaKg?, mineraisKg?, tmbKcal?, gorduraVisceral?, grauObesidade?, relacaoCinturaQuadril?, pesoIdealKg?, pontuacao?, massaMagraSegmentar?, gorduraSegmentar?, fonte, sexo?)` · `SegmentalValues(rightArm?, leftArm?, trunk?, rightLeg?, leftLeg? + sufixos Pct)` para massa magra e gordura por segmento.
- **`device_health.dart`**: `DailyStepsRecord`, `DeviceWorkoutSession`, `SleepSessionRecord`, `HeartRateRecord`, `HealthIntegrationConfig`, `HealthSyncHistory`, `HealthDataSource`.

---

## 8. Regras de negócio (fórmulas exatas)

**`core/constants.dart`**: proteína 4 kcal/g · carboidrato 4 · gordura 9 · álcool 7 · `foodDbSource = 'TACO 4ª ed. + TBCA 2023'` · OpenFoodFacts `https://world.openfoodfacts.org/api/v3` · `DayStatus {deficit, maintenance, surplus}` com emojis 🟢 🟡 🔴.

**`core/utils/nutrition_calculator.dart`**
- TMB (Mifflin-St Jeor): `(10*peso) + (6.25*altura) − (5*idade) + 5` (M) ou `− 161` (F).
- TDEE = TMB × fator de atividade.
- Meta calórica: emagrecer `TDEE − 500` · ganharMassa `TDEE + 300` · manter `TDEE`.
- Proteína: `2,0 g/kg` (emagrecer/ganhar) · `1,6 g/kg` (manter).
- Split de macros: emagrecer 30/35/35 · ganharMassa 25/50/25 · manter 25/45/30 (P/C/G).
- Água: `35 ml/kg`. IMC e peso ideal (IMC 18,5–24,9). Peso estimado: `deficitKcal × dias / 7700`.

**Status do dia**: `balanceKcal > +50` → superávit 🔴 · `< −50` → déficit 🟢 · senão manutenção 🟡.

**Metas auxiliares exibidas**: fibras **30 g/dia**, sódio **2000 mg/dia** (Histórico).

**`services/insight_rules_engine.dart`**: `Insight(title, message, severity, priority, action?, route?)`, `severity {warning, success, info}`, `priority {high, medium, low}`; métodos `daily(DailySummary)`, `weekly(WeeklySummary)`, `checkIn(DailySummary)`. Limiares: excesso ≥ 5% da meta → warning/high; proteína restante ≥ 30 g → warning/high; rotas usadas `'/history'` e `'/add-meal'`.

---

## 9. Serviços

- **`meal_text_parser.dart`**: `ParsedFoodItem(name, quantity, unit, quantityInGrams?)` — regex + normalização de unidades por extenso ("xicara", "colher", "fatia"…). Não calcula nutriente.
- **`household_measure.dart`**: `MeasureUnit` (13 unidades: g, kg, ml, l, concha, xicara, colher, fatia, unidade…) e `toGrams(food, qty, unit, {customGramsPerUnit})` usando `standardPortionGrams`.
- **`nutrition_label_text_parser.dart`**: texto de rótulo → `ParsedNutritionLabel` → `toFood()` (valores por 100 g, kJ→kcal, sódio g→mg).
- **`device_text_recognizer.dart`**: ML Kit, **só Android/iOS** (`isSupported = false` em web/desktop).
- **`bioimpedance_text_parser.dart`**: fachada `BioimpedanceTextParser` (`parse`, `parseDetailed`, `parsePdf`, `parsePdfDetailed`) sobre `services/bioimpedance/`:
  - `bioimpedance_text_normalizer.dart` — minúsculas, sem acento/parênteses, espaços simples e leitura de números `1.234,5` / `1,234.5` / `35,4` / `35.4` (o ponto ambíguo é decidido pela faixa do campo).
  - `bioimpedance_aliases.dart` — `BioField`, `bioFieldSpecs` (aliases por campo, unidade esperada, limites de sanidade), seções segmentares e marcadores de histórico.
  - `bioimpedance_manufacturer.dart` — perfis InBody/Tanita/Omron/seca/Maltron/Biodynamics/Renpho/Withings/Xiaomi, detecção de modelo e aliases extras por fabricante (para adicionar um fabricante, basta um novo perfil).
  - `bioimpedance_extractor.dart` — corta o histórico, lê blocos segmentares antes dos campos gerais, evita faixas de referência/escalas, valida coerência e devolve `BioimpedanceParseResult` (valores, trecho de origem, avisos, linhas não reconhecidas).
  - `bioimpedance_validator.dart` — avisos de coerência (gordura > peso, % fora do esperado, soma segmentar alta, idade improvável), compartilhados por texto e JSON.
  - Lança `LocalParseException` (pt-BR) quando o texto está vazio ou não tem nenhum campo conhecido.
- **`bioimpedance/bioimpedance_json_parser.dart`**: `BioimpedanceJsonParser.parse(String)` — entrada por JSON ao lado de foto/PDF/texto.
  - Aceita o `Bioimpedance.toJson()` do próprio app, nomes canônicos do extrator (`weight`, `bmi`, `bodyFatPercentage`…), português com/sem acento e camelCase/snake_case (`massa_muscular_esquelética_kg`, `gordura_visceral`), números como texto (`"121,2"`, `"1.930"`), datas ISO/`dd/mm/aaaa`/epoch e `sexo`/`gender`/`fonte`.
  - Segmentar aninhado (`massaMagraSegmentar: {rightArm: …}`, `gorduraSegmentar: {braço direito: …}`) ou plano (`massaMagraSegmentar.trunk`), com sufixos `pct`/`percentual` para percentuais.
  - Chaves desconhecidas **não são descartadas**: vão para "texto não reconhecido" na revisão. Objeto pode vir dentro de um wrapper (`bioimpedance`, `bioimpedancia`, `resultado`, `laudo`).
- **`food_database.dart`**: estático, "REGRA CRÍTICA: a IA NUNCA calcula nutrientes"; `all`, `byId`, `byBarcode`, `search` (scoring 1000/600/500/300/250, normalização sem acento), `categories`, `installOverlay()` (merge A/B).
- **`open_food_facts_api.dart`**: API v3, `User-Agent: NutriCoach/1.0`, timeout 20 s, `byBarcode` e busca com `fields=code,product_name,brands,categories_tags,nutriments,image_front_url`.
- **`food_data_updater.dart`**: slots A/B (`food_db.slot_a|b.payload`, `revision`) — hoje só exercitado por teste; **não está plugado no app**.

---

## 10. Banco de alimentos

- **597 alimentos TACO** em `data/food_db/taco_foods.dart` (`id: 'taco-N'`, `source: 'TACO 4ª ed. (NEPA/UNICAMP)'`, valores por 100 g) + **131 itens curados** em `food_database.dart` ≈ 728 itens no baseline.
- IDs OFF: `off-<barcode>`. Busca ignora acentos e casa com aliases.

---

## 11. Persistência e nuvem

**`data/repositories/local_store.dart`** — SharedPreferences, JSON por chave: `profile`, `meals`, `workouts`, `weights`, `measurements`, `photos`, `water`, `favorites`, `custom_foods`, `user_email`, `bioimpedances`, `diet_plans`, `active_diet_id`, `training_plans`, `active_training_plan_id`, `training_sessions`, `health_config`, `health_steps`, `health_workouts`, `health_sleep`, `health_heartrate`, `health_sync_history`, `health_resting_hr`, `health_weight`. Toda mutação chama `_persist*`.

**`data/repositories/cloud_sync.dart`** — espelho Firestore (`users/{uid}/…`): `initialize()`, `syncMeal`, `deleteMeal`, `syncUser`, `syncWorkout`, `syncWeight`; `_userId => null` ⇒ tudo no-op hoje. `config/secrets.dart` tem strings vazias (sem credencial commitada).

---

## 12. Design system (`core/theme/app_theme.dart` + `widgets/core_widgets.dart`)

Tema **escuro único** `AppTheme.dark()`:

| Papel | Hex |
|---|---|
| background | `0xFF070A0F` (subtle `0xFF0A0F14`, elevated `0xFF0F141B`) |
| surface | `0xFF121821` (light `0xFF1A2330`, hover `0xFF1E2A3A`, pressed `0xFF243247`) |
| border | `0xFF1E2A38` (strong `0xFF243247`) |
| textPrimary / Secondary / Muted / Faint | `0xFFF1F5F9` / `0xFF8DA0B8` / `0xFF5F7288` / `0xFF3D4E62` |
| textOnPrimary | `0xFF06251A` |
| primary (verde) | `0xFF00E6A0` (soft `0xFF00B87A`, muted `0xFF0A2E22`) |
| accent (azul) | `0xFF3B82F6` |
| warning / danger | `0xFFF59E0B` / `0xFFEF4444` |
| macroProtein / macroCarbs / macroFat / macroWater | `0xFFA78BFA` / `0xFFFBBF24` / `0xFF60A5FA` / `0xFF22D3EE` |

Raios: 8 / 12 / 16 / 20 / 28 / 999. Fontes Google: **Space Grotesk** (títulos/UI) e **JetBrains Mono** (números, check-in). Componentes reutilizáveis: `GlassCard`, `SectionHeader`, `GradientBar`, `StatusBadge`, `MetricCard`, `ProgressRing`.

---

## 13. Fluxos críticos

1. **Onboarding**: gate → `BioOnboardingScreen` (câmera/galeria/texto/PDF → OCR → parser) → revisão → `importBioimpedance` (peso + metas com TMB medida) → `GoalsScreen` → `computeGoals` + `saveProfile` + `addWeight` → `HomeShell`. Sem bio, vai direto ao `GoalsScreen`.
2. **Refeição por texto**: `AddMealScreen` → `MealTextEntryScreen` → `mealParser.parse` → resolve cada item no banco/OFF (ou abre `FoodSearchScreen`) → `buildMeal` → `addMeal` → persiste → `DailySummary` recalcula.
3. **Rótulo OCR**: `NutritionLabelScreen` → ML Kit → `NutritionLabelTextParser` → `toFood` → revisão → salvar.
4. **Código de barras**: `BarcodeScreen` → `FoodDatabase.byBarcode` → fallback `OpenFoodFactsApi`.
5. **Dieta → dia**: `logDietMeal` converte itens p/ gramas, aplica seleção/override/substituição do dia, infere `MealType` pelo nome e grava `Meal` com `rawText: 'Dieta:<id>:<nome>'`.
6. **Treino**: `startTrainingSession` cria sessão + `Workout(source:'training')` → `addSetToSession` → `finishTrainingSession`.
7. **Insights**: `summaryFor` → `daily/weekly/checkIn` → dashboard (`_InsightInline`), histórico, coach (com rota de ação) e check-in.

---

## 14. Testes, qualidade e deploy

- **Testes** (`test/`, 25 arquivos, 309 casos passando): banco TACO/cálculos/`DailySummary.status`, `MealTextParser`, `InsightRulesEngine`, `HouseholdMeasureConverter`/`DietPlan`, parser de bioimpedância (aliases, números, segmentar, histórico × atual, faixas de referência, data, modelo/JSON, entrada por JSON e diálogo), revisão editável, integração com a saúde (serviço falso), parsers de rótulo/OFF, `FoodDataUpdater`, copy das telas ("sem chat", "Sem IA generativa"), regressões de UI (`dashboard_hoje_regression_test`, `home_shell_fab_test`).
- **Qualidade**: `flutter analyze` (só infos/warnings pré-existentes) · `flutter test` determinístico (SharedPreferences mockado).
- **Deploy site**: `flutter build web --release` → `npx vercel build --prod` → `npx vercel deploy --prebuilt --prod --yes`. Produção: `https://nutricoachai-wheat.vercel.app`. O push ao GitHub **não** dispara build na Vercel (`Ignored Build Step = exit 0`), de propósito — a Vercel não compila Flutter.
- **Local**: `flutter run` / `flutter run -d chrome` / `serve.py` (porta 8080).

---

## 15. Gaps conhecidos (não prometer nos prompts)

- `CheckinScreen` e `LoginScreen` existem mas não estão acessíveis (órfãs).
- Saúde do dispositivo: Health Connect exige Android 9+ em uso real (o `minSdk` do app é 26); no iOS o `Runner.entitlements` (HealthKit) precisa estar habilitado na conta de desenvolvedor/App ID — sem isso o build assina, mas a leitura não funciona.
- Saúde: `syncHealthData` busca 90 dias de passos/sono/treinos e só 7 dias de frequência cardíaca (limite para não pesar no aparelho).
- Parser de bioimpedância: não há PDFs reais versionados no repo; os testes usam laudos textuais sintéticos no layout InBody. Relatórios muito diferentes podem cair em "texto não reconhecido", que fica preservado para revisão manual.
- Parser de bioimpedância: OCR de laudo fotografado depende da qualidade da foto; o parser lê apenas texto (não interpreta gráficos).
- Espelhamento Firestore desligado (`_userId == null`); `secrets.dart` vazio.
- Atualização remota do banco (`FoodDataUpdater`) não plugada no app.
- OCR indisponível em web/desktop (só Android/iOS).
- `Workout` criado por sessão de treino entra com `kcalBurned: 0` (kcal vem do registro manual).
- Sem CI/CD (`.github/` inexistente).

---

## 16. Checklist para o GPT ao gerar prompts

Quando gerar prompt para nova tela/fluxo/copi, garanta:

1. **Contexto obrigatório no prompt**: nome da tela, rota/aba de entrada, quais getters e métodos do `AppState` serão usados, quais modelos da seção 7 envolvidos, formato de dados persistido.
2. **Guardrails**: "não inventar valores nutricionais", "não usar LLM/chat", "pt-BR", "seguir paleta e fontes da seção 12", "funcionar offline".
3. **UX**: bottom sheet para registrar, FAB acima da bottom bar, padding inferior 88 em listas, alvos de toque grandes, estados vazios com ação (ex.: "Registre sua primeira refeição…").
4. **Saída esperada**: o prompt deve pedir widget Flutter conciso com `context.watch<AppState>()`, persistência via método existente, e teste em `test/`.
5. **Nunca** propor: tema claro, valores de nutriente hardcoded, dependência de rede obrigatória, textos em inglês.
