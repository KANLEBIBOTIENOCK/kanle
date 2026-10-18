---
trigger: glob
globs: "lib/**/*.dart"
description: "Conventions d'architecture des widgets, séparation UI/métier et gestion d'état Provider dans Flutter."
---

# Architecture des Composants & Gestion d'État Flutter

## 1. Principes de Découplage
- Séparer strictement la vue (présentation) de la logique métier.
- Toute mutation d'état globale doit transiter exclusivement par les méthodes publiques de `AppState` (`lib/app_state.dart`).
- Utiliser `Consumer<AppState>` ou `context.select(...)` aux feuilles de l'arbre pour minimiser le coût de reconstruction des widgets (`rebuild`).

## 2. Standards d'Interface & Design System
- Respecter le thème Material 3 centré sur la couleur primaire `#6C5CE7` (Indigo électrique) et le fond `#F7F8FC`.
- Utiliser la palette de catégories standardisée définie dans `lib/models.dart` (`kPalette` et `kCategories`).
- Prendre en charge les interactions tactiles avec retour haptique approprié et micro-animations fluides.
- Assurer le bon fonctionnement du Pinch-to-zoom sur la vue temporelle (`PlanningScreen`).

## 3. Gestion des Erreurs et Null-Safety
- Ne jamais utiliser l'opérateur d'assertion `!` à l'aveugle sans vérification préalable.
- Afficher les erreurs via des `SnackBar` ou modales non bloquantes pour l'utilisateur.
