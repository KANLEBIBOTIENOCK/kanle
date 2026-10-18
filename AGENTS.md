# Instructions Système & Invariants Techniques — Projet Kanlé

Ce fichier constitue le contexte permanent (`always_on`) pour tout agent intervenant sur le projet **Kanlé** (anciennement `timebloc_clone`). Il ne contient aucun en-tête YAML et s'applique comme socle de vérité technique.

---

## 1. Identité Technique & Stack Logicielle

- **Application** : Kanlé — Application mobile de planification par blocs de temps (Time-blocking), gestion de routines récurrentes et assistant de productivité assisté par IA.
- **Framework** : Flutter (Material 3 natif, support multi-plateforme avec cible prioritaire Android).
- **Langage** : Dart (SDK `^3.13.4`). Typage strict obligatoire, null-safety totale.
- **Gestion d'État** : `Provider` (`ChangeNotifier`) avec classe centrale [`AppState`](file:///c:/Users/HP/Desktop/Agence/lib/app_state.dart).
- **Persistance Locale** : `shared_preferences` (stockage JSON pour les blocs, routines, catégories personnalisées et préférences utilisateur).
- **Notifications Locales** : `flutter_local_notifications` + `timezone` pour les alertes de début et fin de bloc.
- **Visualisation & Graphiques** : `fl_chart` pour l'analyse statistique du temps passé par catégorie.
- **Intégration IA** : `google_generative_ai` (Google Gemini) pour l'analyse intelligente et la proposition de plannings.

---

## 2. Conventions de Code & Standards d'Architecture

- **Indentation & Formatage** : 2 espaces. Formatage systématique conforme à `dart format`.
- **Règles de Linter** : Conformité stricte avec `package:flutter_lints/flutter.yaml`. Aucun avertissement ou erreur de lint toléré.
- **Organisation Modulaire** :
  - [`lib/models.dart`](file:///c:/Users/HP/Desktop/Agence/lib/models.dart) : Entités pures et immuables (`TimeBlock`, `Routine`, `CategoryInfo`, etc.) avec méthodes `toJson()` / `fromJson()`.
  - [`lib/app_state.dart`](file:///c:/Users/HP/Desktop/Agence/lib/app_state.dart) : Logique métier centrale, gestionnaire d'état réactif et coordination de la persistance.
  - [`lib/ai_service.dart`](file:///c:/Users/HP/Desktop/Agence/lib/ai_service.dart) & [`lib/ai_config.dart`](file:///c:/Users/HP/Desktop/Agence/lib/ai_config.dart) : Services d'inférence IA, prompts structurés et extraction JSON déterministe.
  - [`lib/notification_service.dart`](file:///c:/Users/HP/Desktop/Agence/lib/notification_service.dart) : Planification et annulation des notifications Android / iOS.
  - [`lib/screens/`](file:///c:/Users/HP/Desktop/Agence/lib/screens/) : Vues de l'application (Planning, Routines, Statistiques, Assistant IA, Paramètres, Éditeur de bloc).

---

## 3. Invariants & Règles Métier Critiques

1. **Non-Régression de Persistance** : Ne jamais altérer la structure des clés JSON dans `SharedPreferences` sans prévoir de migration ascendante transparente.
2. **Gestion des Conflits Temporels** : Deux blocs de temps ne doivent pas se chevaucher de manière incohérente. La logique d'ajustement automatique dans [`AppState`](file:///c:/Users/HP/Desktop/Agence/lib/app_state.dart) doit être préservée.
3. **Sécurité des Données & Clés d'API** :
   - Les clés API Gemini doivent être configurables dynamiquement par l'utilisateur dans l'écran des paramètres ou via variables d'environnement.
   - Ne jamais forcer de dépendance distante bloquante : si l'IA ou le réseau échoue, l'application doit continuer à fonctionner à 100 % en mode local hors-ligne.
4. **Fluidité UI & Micro-interactions** :
   - Éviter les reconstructions de widgets inutiles (`Consumer` ciblés plutôt que de reconstruire l'arbre complet).
   - Maintenir les interactions tactiles (Pinch-to-zoom pour l'échelle temporelle, glisser-déposer / drag-to-resize).

---

## 4. Commandes de Validation & Cycle Opérationnel

- **Analyse Statique** :
  ```bash
  flutter analyze
  ```
- **Tests Automatisés** :
  ```bash
  flutter test
  ```
- **Compilation Android** :
  ```bash
  flutter build apk --release
  ```
