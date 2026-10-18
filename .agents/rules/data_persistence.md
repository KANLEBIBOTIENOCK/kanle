---
trigger: glob
globs: "lib/models.dart, lib/app_state.dart"
description: "Règles d'intégrité des données, sérialisation JSON SharedPreferences et export/import de sauvegardes."
---

# Règles d'Intégrité des Données & Persistance

## 1. Sérialisation et Schémas JSON
- Les modèles (`TimeBlock`, `Routine`, `CategoryInfo`) doivent posséder des méthodes `toJson()` et des factories `fromJson(Map<String, dynamic> json)` déterministes.
- Toujours fournir des valeurs par défaut lors du décodage de champs optionnels afin de garantir la rétrocompatibilité avec les versions antérieures.

## 2. Persistance SharedPreferences
- La sauvegarde des modifications dans `SharedPreferences` doit être asynchrone et non bloquante pour l'interface graphique.
- Utiliser des clés de stockage explicites et préfixées :
  - `kanle_blocks_v1` : liste des blocs de temps
  - `kanle_routines_v1` : liste des routines
  - `kanle_categories_v1` : liste des catégories utilisateur
  - `kanle_settings_v1` : préférences d'interface et configuration

## 3. Mécanisme de Sauvegarde & Restauration (.txt / JSON)
- La fonctionnalité d'export doit produire un fichier texte formaté contenant l'état complet (timestamp, version du format, catégories, routines et blocs).
- Lors de l'import, valider la structure globale avant d'écraser ou de fusionner l'état en mémoire. En cas de fichier corrompu, déclencher un rollback et alerter l'utilisateur.
