# 🥗 NutriCoach

Aplicativo mobile para **emagrecimento, nutrição e academia** 100% funcional sem IA generativa.
Foco em **não inventar valores nutricionais**: parser local identifica alimentos e quantidades,
OCR local lê rótulos/laudos, e o motor de insights entrega orientações determinísticas com base
no banco nutricional brasileiro e nos dados reais do usuário.

## 🧰 Stack

- **Flutter** (3.44.8)
- **Firebase** Auth + Firestore (opcional — o app roda 100% offline sem configurar)
- **Parser local** (`MealTextParser`) para descrições tipo "200g arroz, 100g feijão, 150g frango"
- **OCR local** (`google_mlkit_text_recognition`) + parsers determinísticos para rótulos e laudos InBody
- **Motor de insights** (`InsightRulesEngine`) — regras, cálculos e prioridades, sem LLM
- **Banco nutricional**: TACO 4ª ed. + TBCA (597 alimentos reais) + OpenFoodFacts (código de barras)
- Google Fit / Health Connect / Mi Fitness (hooks de sincronização prontos)

## 🚀 Como rodar

```bash
flutter run                  # device/emulador
flutter run -d chrome        # web (modo demo offline)
```

Sem chaves de IA necessárias. O app funciona 100% offline após `flutter pub get`.

### Firebase (auth + nuvem)

O app já tenta conectar o Firestore (`lib/data/repositories/cloud_sync.dart`) e
cai em modo offline se não estiver configurado.

```bash
flutterfire configure        # gera firebase_options.dart (Firebase CLI)
```

1. Crie o projeto no [Firebase Console](https://console.firebase.google.com)
2. Rode `dart pub global activate flutterfire_cli` e depois `flutterfire configure`
3. Ative Authentication (e-mail/senha) e Firestore

## 🧠 Fluxo de registro (regra de ouro)

```
descrição em texto  →  MealTextParser identifica {alimento, quantidade, unidade}
                           ↓
            app consulta banco TACO/TBCA + OpenFoodFacts
                           ↓
            app calcula kcal, proteínas, carbos, gorduras, fibras, sódio
                           ↓
                        refeição salva
```

- Nenhum nutriente é inventado; apenas alimentos presentes no banco geram valores.
- Itens sem correspondência exigem seleção manual no banco.
- OCR local lê tabelas nutricionais e laudos, mas a validação é humana antes de salvar.

## 📱 Funcionalidades

- **Dashboard**: calorias (meta/dia), macros 🥩🍞🥑, água 💧, gasto na academia 🏋️,
  peso ⚖️ e status 🟢 déficit / 🟡 manutenção / 🔴 superávit + gráfico 7 dias + refeições de hoje + insight principal
- **Registro de refeições**: descrição livre (parser local), pesquisa, código de barras, favoritos, OCR de rótulo
- **Academia**: manual (kcal, tempo, observações) ou sincronização (Health Connect/Google Fit/Mi Fitness)
- **Peso, medidas** (abdominal, peito, braço, coxa, panturrilha) e **fotos** de evolução
- **Metas**: TMB/TDEE/IMC automáticos (Mifflin-St Jeor), metas de kcal/proteína/água
- **Histórico**: calendário com status por dia e detalhe completo + orientações determinísticas
- **Check-in diário** com resumo textual determinístico (calorias, proteína, água, status)
- **Coach**: insights locais priorizados (proteína faltante, meta ultrapassada, aderência semanal) + ações rápidas — sem chat
- **Banco de alimentos**: busca rápida, categorias e detalhes nutricionais

## 📁 Estrutura

```
lib/
├── core/        tema escuro premium, constantes, calculadores
├── config/      configuração (sem chaves de IA)
├── data/
│   ├── models/        Food, Meal, UserProfile, DailySummary, tracking...
│   ├── food_db/       banco TACO/TBCA + OpenFoodFacts
│   └── repositories/  LocalStore (offline-first) + CloudSync (Firestore)
├── services/    MealTextParser, InsightRulesEngine, BioimpedanceTextParser, NutritionLabelTextParser, DeviceTextRecognizer
├── state/       AppState (ChangeNotifier + Provider)
├── shell/       navegação inferior
├── features/    dashboard, refeições, academia, peso, medidas, metas,
│                histórico, check-in, coach, banco de alimentos
└── widgets/     rings, cards, barras de progresso
```

## ✅ Qualidade

- `flutter analyze`: **4 infos** (prefer_initializing_formals)
- `flutter test`: testes determinísticos de parser, insights, calculadora e banco TACO
- `flutter build web`: compila em produção sem dependências de IA

## 🔜 Próximos passos

- Conectar Firebase Auth real (e-mail/Google/anon)
- Health Connect nativo (API Android) para leitura automática de treino
- Busca remota do banco TACO/TBCA com atualização automática
