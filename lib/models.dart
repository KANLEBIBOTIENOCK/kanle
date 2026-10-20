import 'package:flutter/material.dart';

const List<Color> kPalette = [
  Color(0xFFE2B93B), // Or doré / Prière
  Color(0xFF6C5CE7), // Indigo électrique
  Color(0xFF00B894), // Émeraude
  Color(0xFFFF7675), // Corail
  Color(0xFF0984E3), // Bleu cobalt
  Color(0xFFE17055), // Ambre chaud
  Color(0xFFE84393), // Rose vibrant
  Color(0xFF00CEC9), // Turquoise
];

class CategoryInfo {
  final String id;
  final String name;
  final IconData icon;
  final Color defaultColor;
  final bool isCustom;

  const CategoryInfo({
    required this.id,
    required this.name,
    required this.icon,
    required this.defaultColor,
    this.isCustom = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconCode': icon.codePoint,
        'iconFontFamily': icon.fontFamily,
        'color': defaultColor.value,
        'isCustom': isCustom,
      };

  factory CategoryInfo.fromJson(Map<String, dynamic> j) {
    final code = j['iconCode'] as int?;
    return CategoryInfo(
      id: j['id'] ?? '',
      name: j['name'] ?? 'Catégorie',
      icon: resolveCategoryIcon(code),
      defaultColor: Color(j['color'] as int? ?? 0xFF6C5CE7),
      isCustom: j['isCustom'] ?? true,
    );
  }
}

const List<IconData> kAvailableCategoryIcons = [
  Icons.auto_awesome_rounded,
  Icons.work_outline_rounded,
  Icons.menu_book_rounded,
  Icons.fitness_center_rounded,
  Icons.track_changes_rounded,
  Icons.spa_rounded,
  Icons.coffee_rounded,
  Icons.favorite_border_rounded,
  Icons.code_rounded,
  Icons.music_note_rounded,
  Icons.local_dining_rounded,
  Icons.directions_run_rounded,
  Icons.shopping_bag_outlined,
  Icons.home_outlined,
  Icons.flight_takeoff_rounded,
  Icons.pets_rounded,
  Icons.palette_outlined,
  Icons.science_rounded,
  Icons.school_rounded,
  Icons.laptop_chromebook_rounded,
  Icons.category_rounded,
];

IconData resolveCategoryIcon(int? codePoint) {
  if (codePoint == null) return Icons.category_rounded;
  for (final icon in kAvailableCategoryIcons) {
    if (icon.codePoint == codePoint) return icon;
  }
  return Icons.category_rounded;
}

const List<CategoryInfo> kCategories = [
  CategoryInfo(
    id: 'prayer',
    name: 'Prière & Foi',
    icon: Icons.auto_awesome_rounded,
    defaultColor: Color(0xFFE2B93B),
  ),
  CategoryInfo(
    id: 'work',
    name: 'Travail & Projet',
    icon: Icons.work_outline_rounded,
    defaultColor: Color(0xFF6C5CE7),
  ),
  CategoryInfo(
    id: 'study',
    name: 'Étude & Lecture',
    icon: Icons.menu_book_rounded,
    defaultColor: Color(0xFF0984E3),
  ),
  CategoryInfo(
    id: 'sport',
    name: 'Sport & Santé',
    icon: Icons.fitness_center_rounded,
    defaultColor: Color(0xFF00B894),
  ),
  CategoryInfo(
    id: 'focus',
    name: 'Focus & Priorité',
    icon: Icons.track_changes_rounded,
    defaultColor: Color(0xFFFF7675),
  ),
  CategoryInfo(
    id: 'rest',
    name: 'Repos & Détente',
    icon: Icons.spa_rounded,
    defaultColor: Color(0xFF00CEC9),
  ),
  CategoryInfo(
    id: 'routine',
    name: 'Routine & Vie',
    icon: Icons.coffee_rounded,
    defaultColor: Color(0xFFE17055),
  ),
  CategoryInfo(
    id: 'social',
    name: 'Famille & Social',
    icon: Icons.favorite_border_rounded,
    defaultColor: Color(0xFFE84393),
  ),
];

final Map<String, CategoryInfo> kCustomCategoriesRegistry = {};

CategoryInfo getCategoryById(String? id, [List<CategoryInfo>? customList]) {
  if (customList != null && customList.isNotEmpty) {
    final found = customList.cast<CategoryInfo?>().firstWhere(
          (c) => c?.id == id,
          orElse: () => null,
        );
    if (found != null) return found;
  }
  if (id != null && kCustomCategoriesRegistry.containsKey(id)) {
    return kCustomCategoriesRegistry[id]!;
  }
  return kCategories.firstWhere(
    (c) => c.id == id,
    orElse: () => kCategories[0],
  );
}

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String fmtMin(int m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

int generateStableNotifId(String id) {
  var hash = 5381;
  for (var i = 0; i < id.length; i++) {
    hash = ((hash << 5) + hash) + id.codeUnitAt(i);
    hash &= 0x7fffffff;
  }
  return hash;
}

class TimeBlock {
  String id;
  int notifId;
  String title;
  String note;
  int colorValue;
  int startMin;
  int endMin;
  String date; // yyyy-MM-dd
  bool done;
  String? routineId;
  int reminderMin; // -1 = aucun rappel
  String categoryId;

  TimeBlock({
    required this.id,
    int? notifId,
    required this.title,
    this.note = '',
    required this.colorValue,
    required this.startMin,
    required this.endMin,
    required this.date,
    this.done = false,
    this.routineId,
    this.reminderMin = 10,
    this.categoryId = 'focus',
  }) : notifId = notifId ?? generateStableNotifId(id);

  Color get color => Color(colorValue);
  int get duration => endMin - startMin;
  CategoryInfo get category => getCategoryById(categoryId);

  Map<String, dynamic> toJson() => {
        'id': id,
        'notifId': notifId,
        'title': title,
        'note': note,
        'color': colorValue,
        'start': startMin,
        'end': endMin,
        'date': date,
        'done': done,
        'routineId': routineId,
        'reminder': reminderMin,
        'category': categoryId,
      };

  factory TimeBlock.fromJson(Map<String, dynamic> j) => TimeBlock(
        id: j['id'],
        notifId: j['notifId'] ?? generateStableNotifId(j['id']),
        title: j['title'],
        note: j['note'] ?? '',
        colorValue: j['color'],
        startMin: j['start'],
        endMin: j['end'],
        date: j['date'],
        done: j['done'] ?? false,
        routineId: j['routineId'],
        reminderMin: j['reminder'] ?? 10,
        categoryId: j['category'] ?? 'focus',
      );
}

class Routine {
  String id;
  String title;
  int colorValue;
  int startMin;
  int endMin;
  Set<int> weekdays; // DateTime.monday..sunday
  int reminderMin; // -1 = aucun rappel
  String categoryId;

  Routine({
    required this.id,
    required this.title,
    required this.colorValue,
    required this.startMin,
    required this.endMin,
    required this.weekdays,
    this.reminderMin = 0,
    this.categoryId = 'routine',
  });

  Color get color => Color(colorValue);
  CategoryInfo get category => getCategoryById(categoryId);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'color': colorValue,
        'start': startMin,
        'end': endMin,
        'weekdays': weekdays.toList(),
        'reminder': reminderMin,
        'category': categoryId,
      };

  factory Routine.fromJson(Map<String, dynamic> j) => Routine(
        id: j['id'],
        title: j['title'],
        colorValue: j['color'],
        startMin: j['start'],
        endMin: j['end'],
        weekdays: Set<int>.from(j['weekdays'] as List),
        reminderMin: j['reminder'] ?? 0,
        categoryId: j['category'] ?? 'routine',
      );
}

class TaskItem {
  String id;
  int notifId;
  String title;
  String note;
  int? timeMin; // minutes depuis minuit (ex: 1200 = 20:00)
  String? date; // yyyy-MM-dd si tâche ponctuelle
  bool isDaily; // récurrent tous les jours
  Set<int> weekdays; // jours spécifiques (1 = lundi ... 7 = dimanche)
  bool done; // pour les tâches ponctuelles
  Set<String> completedDates; // pour les récurrentes, liste des dateKey() où elle a été faite
  DateTime createdAt;

  TaskItem({
    required this.id,
    int? notifId,
    required this.title,
    this.note = '',
    this.timeMin,
    this.date,
    this.isDaily = false,
    Set<int>? weekdays,
    this.done = false,
    Set<String>? completedDates,
    DateTime? createdAt,
  })  : notifId = notifId ?? generateStableNotifId('task_$id'),
        weekdays = weekdays ?? {},
        completedDates = completedDates ?? {},
        createdAt = createdAt ?? DateTime.now();

  bool get isRecurring => isDaily || weekdays.isNotEmpty;

  bool isApplicableForDate(DateTime d) {
    final k = dateKey(d);
    if (isDaily) return true;
    if (weekdays.isNotEmpty) return weekdays.contains(d.weekday);
    if (date != null) return date == k;
    return false;
  }

  bool isDoneForDate(DateTime d) {
    if (isRecurring) {
      return completedDates.contains(dateKey(d));
    }
    return done;
  }

  void toggleDoneForDate(DateTime d) {
    if (isRecurring) {
      final k = dateKey(d);
      if (completedDates.contains(k)) {
        completedDates.remove(k);
      } else {
        completedDates.add(k);
      }
    } else {
      done = !done;
    }
  }

  String get timeFormatted {
    if (timeMin == null) return 'Sans heure';
    return fmtMin(timeMin!);
  }

  String get recurrenceLabel {
    if (isDaily) return 'Tous les jours';
    if (weekdays.isNotEmpty) {
      const dayNames = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
      final sorted = weekdays.toList()..sort();
      return 'Chaque ${sorted.map((w) => dayNames[(w - 1).clamp(0, 6)]).join(', ')}';
    }
    if (date != null) {
      final parts = date!.split('-').map(int.parse).toList();
      final dt = DateTime(parts[0], parts[1], parts[2]);
      final now = DateTime.now();
      if (date == dateKey(now)) return "Aujourd'hui";
      if (date == dateKey(now.add(const Duration(days: 1)))) return 'Demain';
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    }
    return 'Ponctuelle';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'notifId': notifId,
        'title': title,
        'note': note,
        'timeMin': timeMin,
        'date': date,
        'isDaily': isDaily,
        'weekdays': weekdays.toList(),
        'done': done,
        'completedDates': completedDates.toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        id: j['id'],
        notifId: j['notifId'] ?? generateStableNotifId('task_${j['id']}'),
        title: j['title'] ?? '',
        note: j['note'] ?? '',
        timeMin: j['timeMin'] as int?,
        date: j['date'] as String?,
        isDaily: j['isDaily'] ?? false,
        weekdays: j['weekdays'] != null
            ? Set<int>.from(j['weekdays'] as List)
            : {},
        done: j['done'] ?? false,
        completedDates: j['completedDates'] != null
            ? Set<String>.from(j['completedDates'] as List)
            : {},
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt']) ?? DateTime.now()
            : DateTime.now(),
      );
}

class AiAction {
  final String id;
  final String type; // add_block, update_block, delete_block, resolve_conflicts, add_task, update_task, delete_task, toggle_task
  final String description;
  final Map<String, dynamic> payload;
  bool isApplied;

  AiAction({
    required this.id,
    required this.type,
    required this.description,
    required this.payload,
    this.isApplied = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'description': description,
        'payload': payload,
        'isApplied': isApplied,
      };

  factory AiAction.fromJson(Map<String, dynamic> j) => AiAction(
        id: j['id'] ?? '',
        type: j['type'] ?? '',
        description: j['description'] ?? '',
        payload: Map<String, dynamic>.from(j['payload'] ?? {}),
        isApplied: j['isApplied'] ?? false,
      );
}

class ChatMessage {
  final String id;
  final String sender; // 'user' ou 'assistant'
  final String text;
  final DateTime timestamp;
  final List<AiAction> actions;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.actions = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender': sender,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        'actions': actions.map((a) => a.toJson()).toList(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] ?? '',
        sender: j['sender'] ?? 'assistant',
        text: j['text'] ?? '',
        timestamp: j['timestamp'] != null
            ? DateTime.tryParse(j['timestamp']) ?? DateTime.now()
            : DateTime.now(),
        actions: (j['actions'] as List? ?? [])
            .map((a) => AiAction.fromJson(a as Map<String, dynamic>))
            .toList(),
      );
}

class ChatSession {
  final String id;
  String title;
  final DateTime createdAt;
  List<ChatMessage> messages;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    List<ChatMessage>? messages,
  }) : messages = messages ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> j) => ChatSession(
        id: j['id'] ?? '',
        title: j['title'] ?? 'Discussion',
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt']) ?? DateTime.now()
            : DateTime.now(),
        messages: (j['messages'] as List? ?? [])
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
      );
}

/// Modèle pour un élément de template de routine
class RoutineTemplateItem {
  final String title;
  final int startMin;
  final int endMin;
  final String categoryId;
  final List<int> weekdays;

  const RoutineTemplateItem({
    required this.title,
    required this.startMin,
    required this.endMin,
    required this.categoryId,
    this.weekdays = const [1, 2, 3, 4, 5, 6, 7],
  });
}

/// Modèle pour un pack de routines prédéfinies ou générées par l'IA
class RoutinePack {
  final String id;
  final String title;
  final String description;
  final String badge;
  final List<RoutineTemplateItem> items;

  const RoutinePack({
    required this.id,
    required this.title,
    required this.description,
    required this.badge,
    required this.items,
  });
}

/// Packs de routines intégrés à l'application
const List<RoutinePack> kBuiltinRoutinePacks = [
  RoutinePack(
    id: 'miracle_morning',
    title: 'Miracle Morning & Foi',
    description: 'Réveil dynamique, prière, lecture biblique et exercice physique pour démarrer fort.',
    badge: 'Populaire',
    items: [
      RoutineTemplateItem(
        title: 'Prière matinale & Méditation',
        startMin: 330, // 05:30
        endMin: 370,   // 06:10
        categoryId: 'prayer',
      ),
      RoutineTemplateItem(
        title: 'Toilette & Verre d\'eau',
        startMin: 370, // 06:10
        endMin: 385,   // 06:25
        categoryId: 'routine',
      ),
      RoutineTemplateItem(
        title: 'Bible audio / Lecture sainte',
        startMin: 385, // 06:25
        endMin: 415,   // 06:55
        categoryId: 'prayer',
      ),
      RoutineTemplateItem(
        title: 'Sport & Étirements matinaux',
        startMin: 415, // 06:55
        endMin: 450,   // 07:30
        categoryId: 'sport',
      ),
      RoutineTemplateItem(
        title: 'Petit-déjeuner & Organisation',
        startMin: 450, // 07:30
        endMin: 480,   // 08:00
        categoryId: 'routine',
      ),
    ],
  ),
  RoutinePack(
    id: 'student_prep',
    title: 'Étudiant & Concours',
    description: 'Structure éprouvée pour réviser efficacement avec sessions espacées et pauses actives.',
    badge: 'Productivité',
    items: [
      RoutineTemplateItem(
        title: 'Session Focus 1 (Flashcards / Synthèse)',
        startMin: 510, // 08:30
        endMin: 600,   // 10:00
        categoryId: 'study',
        weekdays: [1, 2, 3, 4, 5, 6],
      ),
      RoutineTemplateItem(
        title: 'Pause oxygénation & Hydratation',
        startMin: 600, // 10:00
        endMin: 615,   // 10:15
        categoryId: 'rest',
        weekdays: [1, 2, 3, 4, 5, 6],
      ),
      RoutineTemplateItem(
        title: 'Session Focus 2 (Exercices & Problèmes)',
        startMin: 615, // 10:15
        endMin: 720,   // 12:00
        categoryId: 'study',
        weekdays: [1, 2, 3, 4, 5, 6],
      ),
      RoutineTemplateItem(
        title: 'Revue des points clés de la journée',
        startMin: 1170, // 19:30
        endMin: 1230,   // 20:30
        categoryId: 'study',
        weekdays: [1, 2, 3, 4, 5],
      ),
    ],
  ),
  RoutinePack(
    id: 'deep_work',
    title: 'Développeur & Deep Work',
    description: 'Protection maximale de l\'attention avec blocs de travail sans distraction.',
    badge: 'Pro',
    items: [
      RoutineTemplateItem(
        title: 'Daily Planning & Priorités du jour',
        startMin: 540, // 09:00
        endMin: 570,   // 09:30
        categoryId: 'focus',
        weekdays: [1, 2, 3, 4, 5],
      ),
      RoutineTemplateItem(
        title: 'Deep Work Session (Code & Architecture)',
        startMin: 570, // 09:30
        endMin: 720,   // 12:00
        categoryId: 'work',
        weekdays: [1, 2, 3, 4, 5],
      ),
      RoutineTemplateItem(
        title: 'Pause déjeuner & Marche dehors',
        startMin: 720, // 12:00
        endMin: 780,   // 13:00
        categoryId: 'rest',
        weekdays: [1, 2, 3, 4, 5],
      ),
      RoutineTemplateItem(
        title: 'Revue de PR, Tests & Debugging',
        startMin: 840, // 14:00
        endMin: 990,   // 16:30
        categoryId: 'work',
        weekdays: [1, 2, 3, 4, 5],
      ),
      RoutineTemplateItem(
        title: 'Clôture de journée & Bilan Git',
        startMin: 1050, // 17:30
        endMin: 1080,   // 18:00
        categoryId: 'focus',
        weekdays: [1, 2, 3, 4, 5],
      ),
    ],
  ),
  RoutinePack(
    id: 'evening_peace',
    title: 'Sérénité & Clôture du Soir',
    description: 'Déconnexion progressive des écrans, calme, prière et préparation au sommeil.',
    badge: 'Bien-être',
    items: [
      RoutineTemplateItem(
        title: 'Rangement express & Préparation lendemain',
        startMin: 1260, // 21:00
        endMin: 1280,   // 21:20
        categoryId: 'routine',
      ),
      RoutineTemplateItem(
        title: 'Lecture inspirante ou psaume',
        startMin: 1280, // 21:20
        endMin: 1310,   // 21:50
        categoryId: 'prayer',
      ),
      RoutineTemplateItem(
        title: 'Prière du soir & Gratitude',
        startMin: 1310, // 21:50
        endMin: 1340,   // 22:20
        categoryId: 'prayer',
      ),
      RoutineTemplateItem(
        title: 'Sommeil réparateur (Coucher)',
        startMin: 1350, // 22:30
        endMin: 1440,   // 24:00
        categoryId: 'rest',
      ),
    ],
  ),
];

