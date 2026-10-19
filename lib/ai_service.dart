import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'ai_config.dart';
import 'models.dart';

class AiService {
  static const _uuid = Uuid();

  /// Envoie un prompt à l'IA autonome avec le contexte de l'application et retourne
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
        text: 'Veuillez saisir une demande ou coller votre planning/routine.',
        actions: <AiAction>[]
      );
    }

    final effectiveKey = (apiKey != null && apiKey.trim().isNotEmpty)
        ? apiKey.trim()
        : AiConfig.geminiApiKey.trim();

    if (effectiveKey.isEmpty) {
      return (
        text: 'La clé API Gemini n\'est pas encore configurée dans le code (AiConfig.geminiApiKey).',
        actions: <AiAction>[]
      );
    }

    try {
      return await _callGeminiApi(
        prompt: cleanPrompt,
        apiKey: effectiveKey,
        currentDate: currentDate,
        currentBlocks: currentBlocks,
        currentTasks: currentTasks,
      );
    } catch (e) {
      debugPrint('Erreur API Gemini: $e');
      return (
        text: 'Une erreur est survenue lors de la communication avec l\'assistant IA Gemini :\n$e\n\nVeuillez vérifier votre connexion internet et réessayer.',
        actions: <AiAction>[]
      );
    }
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
Tu es l'assistant IA autonome et exclusif de l'application mobile Kanlé (Time-blocking, Gestion de routines et d'habitudes, Tâches et Productivité).
Tu es bienveillant, dynamique, méthodique, très précis et tu as une maîtrise parfaite du temps.
Date actuelle : ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} (Jour affiché dans l'app : $todayKey).
Heure actuelle : ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}.

=======================================================
LES CAPACITÉS RÉELLES DE L'APPLICATION (ACTIONS POSSIBLES)
=======================================================
Tu peux exécuter les actions suivantes dans le tableau "actions" :

1. "add_routine" : CRÉER UNE ROUTINE RÉCURRENTE
   - Pour les habitudes quotidiennes, matinales, du soir, ou récurrentes certains jours de la semaine.
   - Les routines créées apparaissent dans l'écran Routines et sont automatiquement synchronisées sur le Planning.
   - Champs de payload :
     * "title": Titre court, propre et soigné (ex: "Laver le visage", "Bible audio", "Prière Aline", "Marche")
     * "startMin": Minute de début depuis minuit (ex: 05h10 = 5*60 + 10 = 310)
     * "endMin": Minute de fin (ex: 05h12 = 312, 06h00 = 360). STRICTEMENT supérieur à startMin.
     * "category": Une catégorie parmi: "prayer" (prière, foi, bible, psaume), "study" (étude, révision, lecture, exercice), "routine" (toilette, habillage, rangement, ménage, repas), "work" (projet, biblio, objectifs), "sport" (marche, course, fitness), "focus" (priorité haute), "rest" (détente, musique, repos), "social" (famille, amis).
     * "weekdays": Tableau des entiers des jours de la semaine (1 = Lundi, 2 = Mardi, 3 = Mercredi, 4 = Jeudi, 5 = Vendredi, 6 = Samedi, 7 = Dimanche). Si tous les jours: [1,2,3,4,5,6,7]. Si du lundi au vendredi: [1,2,3,4,5]. Si un seul jour (ex: Lundi): [1].

2. "add_block" : PLANIFIER UN BLOC DE TEMPS PONCTUEL (TimeBlock)
   - Pour un créneau spécifique sur un jour précis (ex: "Demain de 14h à 16h réunion", "Aujourd'hui 20h séance code").
   - Champs de payload :
     * "title": Titre du créneau
     * "date": Date au format "YYYY-MM-DD"
     * "startMin": Minute de début (ex: 840 pour 14:00)
     * "endMin": Minute de fin (ex: 960 pour 16:00)
     * "category": Une des catégories valides ("work", "study", "sport", "focus", "rest", "routine", "prayer", "social")
     * "note": Note optionnelle

3. "add_task" : PROGRAMMER UN RAPPEL OU UNE TÂCHE (TaskItem)
   - Pour les actions ou rappels sans plage de début-fin continue (ex: "Appeler maman à 18h", "Prendre vitamines à 08h", "Laver habit à 19h").
   - Champs de payload :
     * "title": Intitulé propre (ex: "Appeler Papa", "Appeler Aline")
     * "timeMin": Minute cible dans la journée (ex: 7h25 = 445, 18h00 = 1080, 20h00 = 1200)
     * "isDaily": true si c'est chaque jour, false sinon
     * "weekdays": Tableau des jours si récurrent certains jours (ex: [1, 3, 5, 7] pour lun, mer, ven, dim)
     * "date": "YYYY-MM-DD" si c'est une tâche ponctuelle à un jour donné

4. "delete_block" / "delete_task" / "update_block" / "update_task" / "toggle_task"
   - Champs : "id": ID de l'élément cible

5. "resolve_conflicts" : RÉSOUDRE LES CONFLITS D'HORAIRES
   - "date": "YYYY-MM-DD"

=======================================================
RÈGLE CRITIQUE ABSOLUE : DÉCOMPOSITION SYSTÉMATIQUE (BATCH PARSING)
=======================================================
Quand l'utilisateur te colle ou te dicte un emploi du temps, une liste de journée, une routine complète ou plusieurs activités (ex: 10 créneaux avec heures, ou une liste d'appels à faire) :
- TU NE DOIS JAMAIS, SOUS AUCUN PRÉTEXTE, fusionner ou concaténer plusieurs activités dans un seul titre ou une seule action !
- Tu DOIS IMPÉRATIVEMENT générer AUTANT D'ACTIONS DISTINCTES dans le tableau "actions" qu'il y a d'activités individuelles !
- Exemple : Si l'utilisateur donne 15 créneaux et 5 rappels d'appels, ton tableau "actions" DOIT contenir exactement 20 objets distincts.
- Chaque objet doit avoir son propre titre propre, ses propres minutes calculées de début et de fin, ses bons jours `weekdays`, et sa catégorie appropriée.
- Zéro conflit : Assure-toi que les heures début/fin de créneaux successifs ne se chevauchent pas de manière incohérente (ex: 05h10-05h12 puis 05h14-05h24).

BLOCS ACTUELS DE L'UTILISATEUR :
${jsonEncode(blocksContext)}

TÂCHES ACTUELLES DE L'UTILISATEUR :
${jsonEncode(tasksContext)}

FORMAT DE SORTIE OBLIGATOIRE (STRICTEMENT EN JSON SANS TEXTE AVANT OU APRÈS) :
{
  "response": "Explication claire, chaleureuse et structurée en français récapitulant exactement tout ce qui a été découpé et préparé pour l'utilisateur.",
  "actions": [
    {
      "type": "add_routine", // ou "add_block", "add_task", etc.
      "description": "Description humaine concise (ex: Créer la routine : Laver le visage (05:10 - 05:12, Lun))",
      "payload": {
        "title": "Laver le visage",
        "startMin": 310,
        "endMin": 312,
        "category": "routine",
        "weekdays": [1]
      }
    }
  ]
}
''';

    String? rawText;

    // 1. Tenter l'appel REST direct avec header X-goog-api-key (rapide, sans wrapper)
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
          'temperature': 0.1,
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
      } else {
        debugPrint('REST Gemini a répondu avec code ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      debugPrint('Tentative REST échouée ($e), tentative via le SDK official google_generative_ai...');
    }

    // 2. Si le REST n'a pas répondu, tenter le SDK officiel google_generative_ai
    if (rawText == null || rawText.isEmpty) {
      final model = GenerativeModel(
        model: AiConfig.geminiModel,
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.1,
        ),
        systemInstruction: Content.system(systemInstruction),
      );
      final response = await model.generateContent([Content.text(prompt)]);
      rawText = response.text;
    }

    if (rawText == null || rawText.isEmpty) {
      throw Exception('Aucune réponse reçue de l\'API Gemini.');
    }

    // Nettoyer les balises éventuelles de markdown (ex: ```json ... ```)
    var cleanedJson = rawText.trim();
    if (cleanedJson.startsWith('```')) {
      final firstLineEnd = cleanedJson.indexOf('\n');
      if (firstLineEnd != -1) {
        cleanedJson = cleanedJson.substring(firstLineEnd + 1);
      }
      if (cleanedJson.endsWith('```')) {
        cleanedJson = cleanedJson.substring(0, cleanedJson.length - 3);
      }
      cleanedJson = cleanedJson.trim();
    }

    final parsed = jsonDecode(cleanedJson);
    final text = parsed['response'] as String? ?? 'Voici les actions préparées pour vous :';
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
}
