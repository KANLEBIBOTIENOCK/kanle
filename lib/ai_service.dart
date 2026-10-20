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
    String chronotype = 'morning',
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
        chronotype: chronotype,
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
    String chronotype = 'morning',
  }) async {
    final now = DateTime.now();
    final todayKey = dateKey(currentDate);

    // Contexte synthétique et allégé (pour minimiser la latence réseau et le traitement des tokens)
    final relevantBlocks = currentBlocks.where((b) => b.date == todayKey).take(30);
    final blocksContext = relevantBlocks.map((b) => {
          'title': b.title,
          'start': fmtMin(b.startMin),
          'end': fmtMin(b.endMin),
          'cat': b.categoryId,
        }).toList();

    final tasksContext = currentTasks.take(25).map((t) => {
          'title': t.title,
          'time': t.timeMin != null ? fmtMin(t.timeMin!) : null,
          'daily': t.isDaily,
        }).toList();

    final blocksSnippet = blocksContext.isNotEmpty
        ? '\nBLOCS ACTUELS DU JOUR : ${jsonEncode(blocksContext)}'
        : '';
    final tasksSnippet = tasksContext.isNotEmpty
        ? '\nTÂCHES ACTUELLES : ${jsonEncode(tasksContext)}'
        : '';

    final chronoDesc = switch (chronotype) {
      'evening' => 'L\'utilisateur a un chronotype DU SOIR (pic d\'énergie 16h-22h). Privilégie les blocs intellectuels intenses (study, work, focus) l\'après-midi et en soirée.',
      'balanced' => 'L\'utilisateur a un chronotype ÉQUILIBRÉ (pic d\'énergie 10h-16h).',
      _ => 'L\'utilisateur a un chronotype MATINAL (pic d\'énergie 06h-12h). Privilégie les blocs intellectuels intenses (study, work, focus) tôt le matin.',
    };

    final systemInstruction = '''
Tu es l'assistant IA autonome et ultra-rapide de l'application mobile Kanlé (Time-blocking, Routines, Tâches, Coaching).
Date actuelle : ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} (Jour affiché : $todayKey).
Heure actuelle : ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}.
Profil d'énergie : $chronoDesc$blocksSnippet$tasksSnippet

ACTIONS DISPONIBLES :
1. "add_routine": Créer une habitude récurrente (payload: "title", "startMin", "endMin", "category", "weekdays").
   Catégories valides: "prayer", "study", "routine", "work", "sport", "focus", "rest", "social".
   weekdays: [1..7] (1=Lundi, 7=Dimanche).
2. "add_block": Créer un créneau ponctuel (payload: "title", "date" [YYYY-MM-DD], "startMin", "endMin", "category", "note").
3. "add_task": Créer une tâche ou rappel (payload: "title", "timeMin", "isDaily", "weekdays", "date").
4. "resolve_conflicts": Résoudre les chevauchements (payload: "date" [YYYY-MM-DD]).

FONCTIONNALITÉS SPÉCIFIQUES :
- RETARD DÉCLARÉ ("J'ai 30 min de retard") : Décale les créneaux futurs de la journée en compressant légèrement les pauses pour sauver la journée.
- PLANIFICATION D'OBJECTIF ("Examen dans 7 jours, 10h de révision") : Découpe en modules d'étude de 45-60 min répartis intelligemment sur les créneaux libres des jours à venir en respectant le chronotype.
- DÉCOMPOSITION SYSTÉMATIQUE : Pour tout emploi du temps collé, génère une action distincte par activité sans jamais tronquer ni fusionner.

FORMAT STRICT EN JSON :
{
  "response": "Court résumé chaleureux, clair et motivant en français.",
  "actions": [
    {
      "type": "add_routine",
      "description": "Créer la routine : Laver le visage (05:10 - 05:12, Lun)",
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

    String? rawText;
    final client = http.Client();
    final modelsToTry = [
      AiConfig.geminiModel,
      ...AiConfig.fallbackModels,
    ];

    // 1. Tenter les modèles REST optimisés en cascade avec timeout de 10s par tentative
    try {
      for (final modelName in modelsToTry) {
        try {
          final url = Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent');
          final resp = await client
              .post(
                url,
                headers: {
                  'Content-Type': 'application/json',
                  'X-goog-api-key': apiKey,
                },
                body: reqBody,
              )
              .timeout(const Duration(seconds: 10));

          if (resp.statusCode == 200) {
            final decoded = jsonDecode(resp.body);
            final candidates = decoded['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final parts = candidates[0]['content']?['parts'] as List?;
              if (parts != null && parts.isNotEmpty) {
                rawText = parts[0]['text'] as String?;
                if (rawText != null && rawText.isNotEmpty) {
                  debugPrint('IA Gemini: Réponse reçue avec succès via [$modelName]');
                  break;
                }
              }
            }
          } else {
            debugPrint('Modèle [$modelName] indisponible (code ${resp.statusCode}), basculement...');
          }
        } catch (e) {
          debugPrint('Modèle [$modelName] en timeout ou erreur ($e), basculement...');
        }
      }
    } finally {
      client.close();
    }

    // 2. Dernier recours : SDK officiel si tous les appels directs REST ont échoué
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
      final response = await model
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 12));
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

  /// Analyse intelligente de la répartition du temps (pour l'écran Statistiques)
  static Future<String> analyzeProductivityStats({
    required Map<String, double> categoryHours,
    required double totalHours,
    required String periodName,
    String chronotype = 'morning',
    String? apiKey,
  }) async {
    final effectiveKey = (apiKey != null && apiKey.trim().isNotEmpty)
        ? apiKey.trim()
        : AiConfig.geminiApiKey.trim();

    if (effectiveKey.isEmpty) {
      return 'Clé API non configurée.';
    }

    final catSummary = categoryHours.entries
        .map((e) => '${e.key}: ${e.value.toStringAsFixed(1)}h (${(e.value / (totalHours > 0 ? totalHours : 1) * 100).toStringAsFixed(0)}%)')
        .join(', ');

    final prompt = '''
Tu es le coach de productivité et de bien-être de l'application Kanlé.
Voici la répartition du temps de l'utilisateur pour la période "$periodName" (Total: ${totalHours.toStringAsFixed(1)}h) :
$catSummary
Profil chronotype de l'utilisateur : $chronotype.

Rédige une analyse synthétique, percutante, bienveillante et motivante en français :
1. Un constat clair sur l'équilibre (points forts et déséquilibres éventuels travail/études/repos/foi/santé).
2. Deux ou trois conseils très concrets pour réajuster le planning la semaine prochaine.
Garde un ton encourageant, professionnel et concis (environ 150 mots maximum, avec des puces claires).
''';

    return await _callSimpleTextPrompt(prompt: prompt, apiKey: effectiveKey);
  }

  /// Génère un bilan de productivité personnalisé (Bilan Quotidien / Hebdomadaire)
  static Future<String> generateProductivityReview({
    required String periodName,
    required List<TimeBlock> blocks,
    required List<TaskItem> tasks,
    required bool isWeekly,
    String chronotype = 'morning',
    String? apiKey,
  }) async {
    final effectiveKey = (apiKey != null && apiKey.trim().isNotEmpty)
        ? apiKey.trim()
        : AiConfig.geminiApiKey.trim();

    if (effectiveKey.isEmpty) {
      return 'Clé API non configurée.';
    }

    final blockCount = blocks.length;
    final taskCount = tasks.length;
    final totalMin = blocks.fold<int>(0, (sum, b) => sum + (b.endMin - b.startMin));
    final hours = (totalMin / 60).toStringAsFixed(1);

    final prompt = '''
Tu es le coach de productivité de Kanlé.
Voici le récapitulatif de l'activité pour la période "$periodName" :
- Nombre de blocs de temps planifiés : $blockCount (représentant $hours heures).
- Nombre de tâches/rappels enregistrés : $taskCount.
- Type de bilan : ${isWeekly ? 'Hebdomadaire' : 'Quotidien'}.
- Chronotype utilisateur : $chronotype.

Rédige un Bilan Coach structuré en 3 parties :
1. 👏 **Félicitations & Réalisations** (souligne l'effort fourni).
2. 💡 **Points d'Optimisation** (ce qui peut être amélioré pour éviter la fatigue ou le déséquilibre).
3. 🎯 **L'Action Clé pour Demain / la Semaine Prochaine** (une recommandation prioritaire).
Sois chaleureux, inspirant et concis (moins de 180 mots).
''';

    return await _callSimpleTextPrompt(prompt: prompt, apiKey: effectiveKey);
  }

  /// Appel générique ultra-rapide pour des réponses textuelles avec cascade de modèles
  static Future<String> _callSimpleTextPrompt({
    required String prompt,
    required String apiKey,
  }) async {
    final client = http.Client();
    final modelsToTry = [
      AiConfig.geminiModel,
      ...AiConfig.fallbackModels,
    ];

    final reqBody = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.4,
      },
    });

    try {
      for (final modelName in modelsToTry) {
        try {
          final url = Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent');
          final resp = await client
              .post(
                url,
                headers: {
                  'Content-Type': 'application/json',
                  'X-goog-api-key': apiKey,
                },
                body: reqBody,
              )
              .timeout(const Duration(seconds: 10));

          if (resp.statusCode == 200) {
            final decoded = jsonDecode(resp.body);
            final text = decoded['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
            if (text != null && text.isNotEmpty) {
              return text.trim();
            }
          }
        } catch (_) {}
      }
    } finally {
      client.close();
    }

    // Fallback SDK
    try {
      final model = GenerativeModel(
        model: AiConfig.geminiModel,
        apiKey: apiKey,
      );
      final resp = await model
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 12));
      return resp.text?.trim() ?? 'Impossible de générer l\'analyse pour le moment.';
    } catch (e) {
      return 'Erreur de connexion au coach IA : $e';
    }
  }
}
