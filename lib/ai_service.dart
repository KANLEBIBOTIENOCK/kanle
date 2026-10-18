import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'ai_config.dart';
import 'models.dart';

class AiService {
  static const _uuid = Uuid();

  /// Envoie un prompt à l'IA avec le contexte de l'application et retourne
  /// le texte de réponse ainsi qu'une liste d'actions structurées à appliquer.
  static Future<({String text, List<AiAction> actions})> processUserInput({
    required String prompt,
    String? apiKey,
    required DateTime currentDate,
    required List<TimeBlock> currentBlocks,
    required List<TaskItem> currentTasks,
  }) async {
    final cleanPrompt = prompt.trim();
    if (cleanPrompt.isEmpty) {
      return (
        text: 'Veuillez saisir une demande ou choisir une suggestion.',
        actions: <AiAction>[]
      );
    }

    final effectiveKey = (apiKey != null && apiKey.trim().isNotEmpty)
        ? apiKey.trim()
        : AiConfig.geminiApiKey.trim();

    // 1. Tenter l'appel à l'API Gemini si la clé est présente
    if (effectiveKey.isNotEmpty) {
      try {
        final result = await _callGeminiApi(
          prompt: cleanPrompt,
          apiKey: effectiveKey,
          currentDate: currentDate,
          currentBlocks: currentBlocks,
          currentTasks: currentTasks,
        );
        return result;
      } catch (e) {
        debugPrint('Erreur API Gemini: $e, bascule sur le moteur local intelligent.');
      }
    }

    // 2. Moteur d'analyse local intelligent (NLP / parsing en français)
    return _processWithLocalEngine(
      prompt: cleanPrompt,
      currentDate: currentDate,
      currentBlocks: currentBlocks,
      currentTasks: currentTasks,
    );
  }

  /// Appel de l'API Gemini avec prompt système contextuel et format JSON structuré
  static Future<({String text, List<AiAction> actions})> _callGeminiApi({
    required String prompt,
    required String apiKey,
    required DateTime currentDate,
    required List<TimeBlock> currentBlocks,
    required List<TaskItem> currentTasks,
  }) async {
    final now = DateTime.now();
    final todayKey = dateKey(currentDate);

    // Contexte synthétique des blocs actuels
    final blocksContext = currentBlocks.map((b) => {
          'id': b.id,
          'title': b.title,
          'date': b.date,
          'startMin': b.startMin,
          'start': fmtMin(b.startMin),
          'endMin': b.endMin,
          'end': fmtMin(b.endMin),
          'category': b.categoryId,
        }).toList();

    // Contexte synthétique des tâches actuelles
    final tasksContext = currentTasks.map((t) => {
          'id': t.id,
          'title': t.title,
          'time': t.timeMin != null ? fmtMin(t.timeMin!) : 'sans heure',
          'isDaily': t.isDaily,
          'date': t.date,
          'weekdays': t.weekdays.toList(),
          'done': t.isDoneForDate(currentDate),
        }).toList();

    final systemInstruction = '''
Tu es l'assistant intelligent de l'application Kanlé (gestion de temps et de planning).
Tu es bienveillant, clair, dynamique et très précis.
Date d'aujourd'hui : ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} (Jour sélectionné : $todayKey).
Heure actuelle : ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}.

IMPORTANT - RÈGLES MÉTIER :
1. BLOC DE TEMPS (TimeBlock) : créneau horaire sur le planning pour un jour précis avec heure de début et heure de fin (ex: Travail de 09:00 à 11:00).
   - Catégories valides : prayer, work, study, sport, focus, rest, routine, social.
   - Les blocs apparaissent dans le Planning et alimentent immédiatement les Statistiques.
2. ROUTINE RÉCURRENTE (Routine) : habitude ou activité qui se répète sur plusieurs jours (ex: "Sport tous les matins de 7h à 8h", "Routine lecture du lundi au vendredi de 21h à 22h").
   - Utilise l'action "add_routine". Elle est visible dans la section Routines et génère automatiquement des blocs dans le Planning et les Statistiques.
3. TÂCHE (TaskItem) : action ponctuelle ou rappel avec une heure cible ou sans heure (ex: "Appeler maman à 20h" ou "Payer facture aujourd'hui").
4. GESTION DES CONFLITS : Si l'utilisateur demande de régler les conflits, propose de décaler les blocs qui se chevauchent ou d'ajuster leur durée.

BLOCS ACTUELS :
${jsonEncode(blocksContext)}

TÂCHES ACTUELLES :
${jsonEncode(tasksContext)}

FORMAT DE RÉPONSE OBLIGATOIRE :
Tu DOIS répondre STRICTEMENT au format JSON valide suivant, sans balises superflues :
{
  "response": "Explication claire et chaleureuse en français de ce que tu proposes ou as fait",
  "actions": [
    {
      "type": "add_routine", // ou "add_block", "update_block", "delete_block", "add_task", "update_task", "delete_task", "toggle_task", "resolve_conflicts"
      "description": "Description concise de l'action en français",
      "payload": {
        // Pour add_routine:
        // "title": "Sport du matin", "startMin": 420, "endMin": 480, "category": "sport", "weekdays": [1,2,3,4,5,6,7]
        // Pour add_block:
        // "title": "...", "date": "YYYY-MM-DD", "startMin": 540, "endMin": 660, "category": "work", "note": "..."
        // Pour add_task:
        // "title": "...", "timeMin": 1200, "isDaily": true/false, "date": "YYYY-MM-DD", "weekdays": [1,2,...]
        // Pour delete_block / delete_task / update_...:
        // "id": "..."
        // Pour resolve_conflicts:
        // "date": "YYYY-MM-DD"
      }
    }
  ]
}
''';

    String? rawText;

    // 1. Tenter l'appel REST direct avec header X-goog-api-key (conforme au curl)
    try {
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/${AiConfig.geminiModel}:generateContent');
      final reqBody = jsonEncode({
        'systemInstruction': {
          'parts': [
            {'text': systemInstruction}
          ]
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
          'temperature': 0.2,
        },
      });

      final resp = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-goog-api-key': apiKey,
        },
        body: reqBody,
      );

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        final candidates = decoded['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final parts = candidates[0]['content']?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            rawText = parts[0]['text'] as String?;
          }
        }
      }
    } catch (e) {
      debugPrint('Tentative REST direct échouée ($e), tentative SDK google_generative_ai...');
    }

    // 2. Si le REST direct n'a pas répondu, tenter le SDK officiel
    if (rawText == null || rawText.isEmpty) {
      final model = GenerativeModel(
        model: AiConfig.geminiModel,
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.2,
        ),
        systemInstruction: Content.system(systemInstruction),
      );
      final response = await model.generateContent([Content.text(prompt)]);
      rawText = response.text;
    }

    if (rawText == null || rawText.isEmpty) {
      throw Exception('Réponse vide de Gemini');
    }

    final parsed = jsonDecode(rawText);
    final text = parsed['response'] as String? ?? 'Voici mes propositions :';
    final actionsJson = parsed['actions'] as List? ?? [];

    final actions = <AiAction>[];
    for (final a in actionsJson) {
      if (a is Map<String, dynamic>) {
        actions.add(AiAction(
          id: _uuid.v4(),
          type: a['type']?.toString() ?? '',
          description: a['description']?.toString() ?? 'Action proposée',
          payload: Map<String, dynamic>.from(a['payload'] ?? {}),
          isApplied: false,
        ));
      }
    }

    return (text: text, actions: actions);
  }

  /// Moteur local de secours (analyse le texte en français pour détecter intentions et créations)
  static ({String text, List<AiAction> actions}) _processWithLocalEngine({
    required String prompt,
    required DateTime currentDate,
    required List<TimeBlock> currentBlocks,
    required List<TaskItem> currentTasks,
  }) {
    final lower = prompt.toLowerCase();
    final todayStr = dateKey(currentDate);
    final tomorrowStr = dateKey(currentDate.add(const Duration(days: 1)));
    final actions = <AiAction>[];

    // 1. Détection de gestion des conflits
    if (lower.contains('conflit') ||
        lower.contains('chevauche') ||
        lower.contains('résoudre') ||
        lower.contains('regle le planning') ||
        lower.contains('réparer planning')) {
      actions.add(AiAction(
        id: _uuid.v4(),
        type: 'resolve_conflicts',
        description: 'Résoudre automatiquement les conflits de planning pour le $todayStr',
        payload: {'date': todayStr},
      ));
      return (
        text: 'J\'ai détecté votre souhait de réorganiser les chevauchements. Je vous propose d\'ajuster et de décaler en cascade les créneaux en conflit.',
        actions: actions
      );
    }

    // 2. Détection de Routine récurrente (ex: "routine sport chaque matin de 7h à 8h", "créer une routine du lundi au vendredi")
    final isRoutineIntent = lower.contains('routine') ||
        lower.contains('habitude') ||
        (lower.contains('tous les') && (lower.contains('matin') || lower.contains('soir'))) ||
        (lower.contains('chaque') && (lower.contains('matin') || lower.contains('soir')));

    if (isRoutineIntent) {
      final blockRegex = RegExp(r'(\d{1,2})\s*(?:h|:)\s*(\d{2})?\s*(?:à|au|-)\s*(\d{1,2})\s*(?:h|:)\s*(\d{2})?');
      final matchBlock = blockRegex.firstMatch(lower);

      int startMin = 420; // 07:00 par défaut
      int endMin = 480;   // 08:00 par défaut

      if (matchBlock != null) {
        final h1 = int.tryParse(matchBlock.group(1) ?? '7') ?? 7;
        final m1 = int.tryParse(matchBlock.group(2) ?? '0') ?? 0;
        final h2 = int.tryParse(matchBlock.group(3) ?? '8') ?? 8;
        final m2 = int.tryParse(matchBlock.group(4) ?? '0') ?? 0;
        startMin = (h1 * 60 + m1).clamp(0, 1439);
        endMin = (h2 * 60 + m2).clamp(0, 1440);
        if (endMin <= startMin) endMin = (startMin + 60).clamp(0, 1440);
      } else {
        final singleTimeRegex = RegExp(r'(\d{1,2})\s*(?:h|:)\s*(\d{2})?');
        final singleMatch = singleTimeRegex.firstMatch(lower);
        if (singleMatch != null) {
          final h = int.tryParse(singleMatch.group(1) ?? '7') ?? 7;
          final m = int.tryParse(singleMatch.group(2) ?? '0') ?? 0;
          startMin = (h * 60 + m).clamp(0, 1439);
          endMin = (startMin + 60).clamp(0, 1440);
        }
      }

      // Jours concernés
      List<int> weekdays = [1, 2, 3, 4, 5, 6, 7];
      var daysDesc = 'Tous les jours';
      if (lower.contains('lundi au vendredi') || lower.contains('semaine')) {
        weekdays = [1, 2, 3, 4, 5];
        daysDesc = 'Lun - Ven';
      } else if (lower.contains('week-end') || lower.contains('weekend')) {
        weekdays = [6, 7];
        daysDesc = 'Week-end';
      }

      // Catégorie
      var cat = 'routine';
      if (lower.contains('sport') || lower.contains('gym') || lower.contains('courir')) cat = 'sport';
      if (lower.contains('prière') || lower.contains('priere') || lower.contains('méditer')) cat = 'prayer';
      if (lower.contains('étude') || lower.contains('etude') || lower.contains('lire') || lower.contains('lecture')) cat = 'study';
      if (lower.contains('travail') || lower.contains('boulot')) cat = 'work';
      if (lower.contains('repos') || lower.contains('détente')) cat = 'rest';

      // Titre
      var title = prompt;
      title = title.replaceAll(
          RegExp(r"créer une routine|ajoute une routine|crée une routine|nouvelle routine|routine|habitude|tous les matins|chaque matin|tous les soirs|chaque soir|tous les jours|chaque jour|du lundi au vendredi|le week-end",
              caseSensitive: false),
          '');
      if (matchBlock != null) {
        title = title.replaceAll(matchBlock.group(0)!, '');
      }
      title = title.replaceAll(RegExp(r'^\s*(?:de|à)\s*', caseSensitive: false), '').trim();
      if (title.isEmpty) title = 'Routine quotidienne';
      title = title[0].toUpperCase() + title.substring(1);

      actions.add(AiAction(
        id: _uuid.v4(),
        type: 'add_routine',
        description: 'Créer la routine récurrente : "$title" (${fmtMin(startMin)} - ${fmtMin(endMin)}, $daysDesc)',
        payload: {
          'title': title,
          'startMin': startMin,
          'endMin': endMin,
          'category': cat,
          'weekdays': weekdays,
        },
      ));

      return (
        text: 'Excellente idée ! J\'ai configuré votre routine récurrente. Dès que vous l\'appliquez, elle apparaîtra dans votre écran Routines et créera automatiquement vos blocs sur le planning et dans vos statistiques.',
        actions: actions
      );
    }

    // 3. Détection de création / gestion de tâche (ex: "appeler maman tous les jours a 20h", "prendre médicaments à 8h")
    final isTaskIntent = lower.contains('tâche') ||
        lower.contains('tache') ||
        lower.contains('appeler') ||
        lower.contains('rappelle') ||
        lower.contains('penser à') ||
        lower.contains('médicament') ||
        lower.contains('maman') ||
        lower.contains('tous les jours') ||
        lower.contains('chaque jour');

    if (isTaskIntent) {
      final isDaily = lower.contains('tous les jours') ||
          lower.contains('chaque jour') ||
          lower.contains('quotidien');

      // Détection de l'heure (ex: "à 20h", "20h30", "20:00", "21 h")
      int? targetMin;
      final timeRegex = RegExp(r'(\d{1,2})\s*(?:h|:)\s*(\d{2})?');
      final timeMatch = timeRegex.firstMatch(lower);
      if (timeMatch != null) {
        final h = int.tryParse(timeMatch.group(1) ?? '0') ?? 0;
        final m = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
        targetMin = (h * 60 + m).clamp(0, 1439);
      }

      // Extraction du titre de la tâche
      var title = prompt;
      title = title.replaceAll(
          RegExp(r"créer une tâche|ajoute une tâche|rappelle-?moi d[e']|penser à|il faut que je",
              caseSensitive: false),
          '');
      title = title.replaceAll(
          RegExp(r"tous les jours|chaque jour|aujourd'hui|demain",
              caseSensitive: false),
          '');
      if (timeMatch != null) {
        title = title.replaceAll(timeMatch.group(0)!, '');
      }
      title = title.replaceAll(RegExp(r'^\s*à\s*', caseSensitive: false), '').trim();
      if (title.isEmpty) title = prompt.trim();
      // Capitaliser première lettre
      if (title.isNotEmpty) {
        title = title[0].toUpperCase() + title.substring(1);
      }

      final dateTarget = lower.contains('demain') ? tomorrowStr : todayStr;

      actions.add(AiAction(
        id: _uuid.v4(),
        type: 'add_task',
        description: isDaily
            ? 'Créer la tâche récurrente : "$title" (Tous les jours à ${targetMin != null ? fmtMin(targetMin) : "l'heure indiquée"})'
            : 'Créer la tâche : "$title" (${dateTarget == todayStr ? "Aujourd'hui" : "Demain"} à ${targetMin != null ? fmtMin(targetMin) : "l'heure indiquée"})',
        payload: {
          'title': title,
          'timeMin': targetMin ?? 1200,
          'isDaily': isDaily,
          'date': isDaily ? null : dateTarget,
        },
      ));

      return (
        text: isDaily
            ? 'C\'est noté ! Je vous propose de programmer cette tâche quotidienne avec rappel automatique.'
            : 'Parfait ! Je vous propose d\'ajouter cette tâche ponctuelle avec son alarme.',
        actions: actions
      );
    }

    // 3. Détection de création de bloc de planning (ex: "ajouter travail de 14h à 16h")
    final blockRegex = RegExp(r'(\d{1,2})\s*(?:h|:)\s*(\d{2})?\s*(?:à|au|-)\s*(\d{1,2})\s*(?:h|:)\s*(\d{2})?');
    final matchBlock = blockRegex.firstMatch(lower);
    if (matchBlock != null || lower.contains('bloc') || lower.contains('planifie') || lower.contains('créneau')) {
      int startMin = 540; // 09:00 par défaut
      int endMin = 600;   // 10:00 par défaut
      if (matchBlock != null) {
        final h1 = int.tryParse(matchBlock.group(1) ?? '9') ?? 9;
        final m1 = int.tryParse(matchBlock.group(2) ?? '0') ?? 0;
        final h2 = int.tryParse(matchBlock.group(3) ?? '10') ?? 10;
        final m2 = int.tryParse(matchBlock.group(4) ?? '0') ?? 0;
        startMin = (h1 * 60 + m1).clamp(0, 1439);
        endMin = (h2 * 60 + m2).clamp(0, 1440);
        if (endMin <= startMin) endMin = (startMin + 60).clamp(0, 1440);
      }

      var title = prompt;
      title = title.replaceAll(
          RegExp(r'ajouter|ajoute|créer|planifie|un bloc|le bloc',
              caseSensitive: false),
          '');
      if (matchBlock != null) {
        title = title.replaceAll(matchBlock.group(0)!, '');
      }
      title = title.replaceAll(
          RegExp(r"aujourd'hui|demain|de|à", caseSensitive: false),
          '').trim();
      if (title.isEmpty) title = 'Nouveau créneau';
      title = title[0].toUpperCase() + title.substring(1);

      // Déduction de la catégorie
      var cat = 'work';
      if (lower.contains('sport') || lower.contains('gym') || lower.contains('courir')) cat = 'sport';
      if (lower.contains('prière') || lower.contains('priere') || lower.contains('méditer')) cat = 'prayer';
      if (lower.contains('étude') || lower.contains('etude') || lower.contains('lire')) cat = 'study';
      if (lower.contains('repos') || lower.contains('pause') || lower.contains('sieste')) cat = 'rest';

      final dateTarget = lower.contains('demain') ? tomorrowStr : todayStr;

      actions.add(AiAction(
        id: _uuid.v4(),
        type: 'add_block',
        description: 'Planifier le bloc "$title" de ${fmtMin(startMin)} à ${fmtMin(endMin)} le $dateTarget',
        payload: {
          'title': title,
          'date': dateTarget,
          'startMin': startMin,
          'endMin': endMin,
          'category': cat,
        },
      ));

      return (
        text: 'J\'ai préparé la planification de votre bloc de temps dans le planning.',
        actions: actions
      );
    }

    // 4. Détection de suppression
    if (lower.contains('supprime') || lower.contains('supprimer') || lower.contains('effacer') || lower.contains('annuler')) {
      // Chercher si un bloc ou une tâche correspond au nom
      final matchingBlock = currentBlocks.firstWhere(
        (b) => lower.contains(b.title.toLowerCase()),
        orElse: () => TimeBlock(id: '', title: '', colorValue: 0, startMin: 0, endMin: 0, date: ''),
      );
      if (matchingBlock.id.isNotEmpty) {
        actions.add(AiAction(
          id: _uuid.v4(),
          type: 'delete_block',
          description: 'Supprimer le bloc "${matchingBlock.title}" (${fmtMin(matchingBlock.startMin)} - ${fmtMin(matchingBlock.endMin)})',
          payload: {'id': matchingBlock.id},
        ));
        return (
          text: 'Je vous propose de supprimer le bloc "${matchingBlock.title}".',
          actions: actions
        );
      }

      final matchingTask = currentTasks.firstWhere(
        (t) => lower.contains(t.title.toLowerCase()),
        orElse: () => TaskItem(id: '', title: ''),
      );
      if (matchingTask.id.isNotEmpty) {
        actions.add(AiAction(
          id: _uuid.v4(),
          type: 'delete_task',
          description: 'Supprimer la tâche "${matchingTask.title}"',
          payload: {'id': matchingTask.id},
        ));
        return (
          text: 'Je vous propose de retirer la tâche "${matchingTask.title}".',
          actions: actions
        );
      }
    }

    // Réponse par défaut d'aide
    return (
      text: 'Je suis à votre disposition ! Vous pouvez me demander par exemple :\n'
          '• "Rappelle-moi d\'appeler maman tous les jours à 20h"\n'
          '• "Prendre mes vitamines aujourd\'hui à 21h"\n'
          '• "Planifie un bloc Focus de 14h à 16h demain"\n'
          '• "Résous les conflits d\'horaires d\'aujourd\'hui"',
      actions: <AiAction>[]
    );
  }
}
