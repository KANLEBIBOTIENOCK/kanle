# Spécification Fonctionnelle et Technique (SSOT) — Application Kanlé

> **Statut** : Verrouillé / Document de référence (Single Source of Truth)  
> **Application** : Kanlé (TimeBloc Clone augmenté)  
> **Version** : 1.1.0  
> **Cible** : Android & Multi-plateforme (Flutter / Dart)

---

## 1. Vision et Objectifs du Système

Kanlé est une application mobile de haute productivité combinant la rigueur du **Time-blocking**, la souplesse de **routines quotidiennes/hebdomadaires**, et la puissance d'un **assistant IA conversationnel** propulsé par Google Gemini.

### Piliers de l'application
1. **Intuitivité Visuelle** : Visualisation claire de la journée par blocs horaires colorés avec interaction tactile réactive (Pinch-to-zoom) et ligne rouge du temps présent ultra-précise avec rafraîchissement continu.
2. **Robustesse Temporelle & Zéro-Doublon** : Prévention automatique des doublons (blocs, routines, tâches, catégories) et résolution intelligente des conflits.
3. **Autonomie Hors-Ligne (Offline-First)** : Fonctionnement autonome et persistance locale via `SharedPreferences`.
4. **Assistance Cognitive & Historique Dédié** : Chat IA complet avec sessions multiples, historique persistant et copie instantanée des messages dans le presse-papier.
5. **Gestion Dynamique des Catégories** : Création, modification et suppression des catégories directement depuis l'écran Statistiques.

---

## 2. Architecture Système

```
lib/
├── main.dart                    # Point d'entrée, initialisation Intl, Notifications, Provider
├── models.dart                  # Entités (TimeBlock, Routine, CategoryInfo, TaskItem, ChatMessage, ChatSession)
├── app_state.dart               # ChangeNotifier central (État, mutations, calculs, persistance & déduplication)
├── ai_config.dart               # Configuration du modèle Gemini et clé API de secours
├── ai_service.dart              # Client Google Generative AI & analyseur syntaxique JSON
├── notification_service.dart    # Moteur de planification et alertes locales
└── screens/
    ├── planning_screen.dart     # Vue principale Timeline 24h, zoom tactile, ligne rouge temps réel avec Ticker
    ├── routines_screen.dart     # Bibliothèque de routines récurrentes et activation par jour
    ├── stats_screen.dart        # Graphiques fl_chart, analyse par catégorie & gestionnaire de catégories
    ├── ai_assistant_screen.dart # Chat interactif, copie de messages, panneau d'historique des conversations
    ├── settings_screen.dart     # Configuration API, sauvegardes .txt, rappels par défaut
    └── block_editor.dart        # Modal/écran d'édition granulaire d'un bloc de temps
```

---

## 3. Spécifications des Modèles de Données

### 3.1. `TimeBlock`
- `id` : UUID v4 unique (`String`)
- `title` : Titre de l'activité (`String`)
- `categoryId` : Identifiant de la catégorie rattachée (`String`)
- `startMin` / `endMin` : Heures en minutes depuis minuit (0 à 1440)
- `date` : Date assignée (`yyyy-MM-dd`)
- `note` : Note ou mémo optionnel (`String`)
- `done` : Statut d'achèvement (`bool`)
- `routineId` : Lien optionnel vers la routine source (`String?`)
- `notifId` : Identifiant stable pour l'alarme locale (`int`)

### 3.2. `Routine`
- `id` : UUID unique (`String`)
- `title` : Libellé de la routine (`String`)
- `categoryId` : Identifiant de catégorie (`String`)
- `startMin` / `endMin` : Heures en minutes (`int`)
- `weekdays` : Ensemble des jours actifs (`Set<int>` de 1=Lundi à 7=Dimanche)
- `colorValue` : Couleur d'affichage (`int`)

### 3.3. `CategoryInfo` (Dynamique)
- `id` : Identifiant unique (`String`)
- `name` : Nom lisible (`String`)
- `icon` : Référence d'icône Material (`IconData`)
- `defaultColor` : Code couleur hexadécimal / `Color`
- `isCustom` : Booléen marquant les catégories ajoutées par l'utilisateur (`bool`)

### 3.4. `ChatSession` & `ChatMessage`
- `ChatSession` :
  - `id` : UUID unique de la session
  - `title` : Titre de la session dérivé du premier message utilisateur
  - `createdAt` : Horodatage de création
  - `messages` : Liste ordonnée de `ChatMessage`
- `ChatMessage` :
  - `id` : Identifiant unique
  - `sender` : `'user'` ou `'assistant'`
  - `text` : Contenu du message
  - `timestamp` : Date et heure d'envoi
  - `actions` : Actions IA applicables (ajout de tâche, ajout de bloc, etc.)

---

## 4. Spécifications Fonctionnelles Détaillées

### 4.1. Vue Chronologique (Planning) & Ligne Rouge Temps Réel
- Grille 24 heures dynamique avec support du **Pinch-to-zoom**.
- **Ligne rouge ultra-précise** :
  - Actualisation continue via un `Timer.periodic` (toutes les 15 à 30 secondes).
  - Positionnement exact : `top = (hour * 60 + minute + second / 60.0) / 60.0 * hourHeight - 5.0`.
  - Pastille rouge lumineuse et ligne horizontale avec dégradé subtil.
  - Badge textuel stylisé affichant l'heure exacte courante (HH:mm) à la minute près.
  - Condition stricte d'affichage : affichée exclusivement si la date sélectionnée est la date du jour (`isToday`).

### 4.2. Assistant IA, Copie de Messages & Historique
- **Copie de messages** :
  - Icône de copie accessible d'un toucher sur chaque message (utilisateur ou assistant).
  - Support de l'appui long (`onLongPress`) sur la bulle de message.
  - Notification visuelle `SnackBar` : « Message copié dans le presse-papier ».
- **Gestionnaire d'Historique de conversation** :
  - Bouton « Historique » dans l'AppBar ouvrant un tiroir (`Drawer`) ou panneau latéral élégant.
  - Bouton « Nouvelle discussion » (`+`) pour ouvrir une session vierge.
  - Liste chronologique de toutes les sessions antérieures avec date et résumé.
  - Possibilité de reprendre une discussion passée ou de la supprimer individuellement.

### 4.3. Gestionnaire de Catégories (Intégré aux Statistiques)
- Dans l'écran `StatsScreen`, ajout d'un bouton d'action et d'une section dédiée à la gestion des catégories.
- Modal interactif :
  - Liste de toutes les catégories actives avec leur durée cumulée.
  - Ajout d'une nouvelle catégorie : sélection du nom, choix d'une couleur dans la palette et d'une icône représentative.
  - Suppression sécurisée d'une catégorie : confirmation et réassignation automatique des blocs orphelins vers la catégorie générale.

### 4.4. Paramètres Épurés
- Suppression de l'option « Nettoyer les doublons » / « Nettoyer les données » devenue obsolète.
- La déduplication est opérée de manière automatique et transparente en mémoire et à chaque sauvegarde.

### 4.5. Matrice et Audit Anti-Doublons
- Déduplication systématique sur 4 niveaux :
  1. **Blocs** : Clé composite `date|startMin|endMin|title.toLowerCase()`.
  2. **Routines** : Clé composite `title.toLowerCase()|startMin|endMin|weekdays`.
  3. **Tâches IA** : Clé composite `title.toLowerCase()|timeMin|date|weekdays`.
  4. **Catégories** : Clé composite `name.toLowerCase()`.
- Nettoyage préventif à l'insertion et au chargement des données.
