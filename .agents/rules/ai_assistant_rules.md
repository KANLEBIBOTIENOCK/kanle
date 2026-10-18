---
trigger: model_decision
description: "Directives d'intégration de l'assistant IA Gemini, gestion des clés d'API et génération déterministe de blocs JSON."
---

# Directives d'Intégration de l'Assistant IA (Gemini)

## 1. Confinement & Gestion des Clés
- Ne jamais coder en dur des clés d'API sensibles dans des commits publics.
- Fournir une méthode de remplacement prioritaire : la clé configurée par l'utilisateur dans l'interface (`SettingsScreen`) surcharge toujours la clé par défaut (`AiConfig.geminiApiKey`).
- Valider la présence et le format de la clé avant de déclencher des requêtes réseau.

## 2. Déterminisme du Format de Sortie
- Pour les requêtes de suggestion d'emploi du temps ou de blocs de temps, forcer le modèle à renvoyer un format JSON strict et encapsulé dans des balises claires (ex. `[BLOCS]...[/BLOCS]` ou bloc de code json).
- Prévoir un parser résilient capable d'extraire le JSON même en présence de texte explicatif conversationnel accompagnateur.
- Chaque bloc suggéré doit obligatoirement spécifier : `title`, `start_time` (format HH:mm), `end_time` (format HH:mm), et `category_id`.

## 3. Rétroaction et Résilience Réseau
- Tout appel vers Gemini doit gérer les exceptions réseau (timeout, quota dépassé, 403/401) et afficher un message d'aide compréhensible à l'utilisateur.
- En cas d'échec du service distant, l'application ne doit en aucun cas planter ni interrompre le flux de planification manuelle.
