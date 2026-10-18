---
trigger: glob
globs: "lib/notification_service.dart"
description: "Gestion des alertes locales, initialisation Android 13+ et respect des fuseaux horaires."
---

# Directives pour les Notifications Locales et la Planification

## 1. Initialisation et Permissions Android
- Initialiser systématiquement `flutter_local_notifications` et `flutter_timezone` au démarrage (`main()`).
- Sur Android 13+ (API 33+), vérifier et demander explicitement la permission `POST_NOTIFICATIONS` avant de tenter une planification.
- Configurer les canaux de notification avec les importances requises (alerte de début de bloc vs alerte de fin de bloc).

## 2. Fuseaux Horaires et Récurrence
- Toutes les dates et heures de planification doivent être converties en `TZDateTime` via la bibliothèque `timezone`.
- Lors de la modification ou suppression d'un bloc de temps ou d'une routine, annuler impérativement les notifications associées via leurs identifiants uniques.
- Éviter la saturation de la file de notifications en limitant la planification anticipée aux 7 prochains jours.
