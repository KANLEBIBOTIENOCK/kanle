import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'ai_config.dart';
import 'ai_service.dart';
import 'models.dart';
import 'notification_service.dart';

class AppState extends ChangeNotifier {
  static const _kBlocks = 'blocks_v1';
  static const _kRoutines = 'routines_v1';
  static const _kDefaultReminder = 'default_reminder_v1';
  static const _kTasks = 'tasks_v1';
  static const _kChatHistory = 'chat_history_v1';
  static const _kGeminiApiKey = 'gemini_api_key_v1';
  static const _kCategories = 'categories_v1';
  static const _kChatSessions = 'chat_sessions_v1';
  static const _kCurrentSessionId = 'current_session_id_v1';
  final _uuid = const Uuid();

  List<TimeBlock> blocks = [];
  List<Routine> routines = [];
  List<TaskItem> tasks = [];
  List<CategoryInfo> categories = List.from(kCategories);
  List<ChatSession> chatSessions = [];
  String? currentSessionId;
  String geminiApiKey = '';
  bool isAiLoading = false;

  DateTime selectedDate = DateTime.now();
  int defaultReminder = 10;
  SharedPreferences? _prefs;
  static const _kApplied = 'applied_v1';
  Set<String> _applied = {}; // "routineId|date" déjà générés

  void _syncCategoryRegistry() {
    kCustomCategoriesRegistry.clear();
    for (final c in categories) {
      kCustomCategoriesRegistry[c.id] = c;
    }
  }

  CategoryInfo getCategory(String? id) => getCategoryById(id, categories);

  ChatSession get activeChatSession {
    if (chatSessions.isEmpty) {
      final s = ChatSession(
        id: newId(),
        title: 'Discussion générale',
        createdAt: DateTime.now(),
      );
      chatSessions.add(s);
      currentSessionId = s.id;
      return s;
    }
    return chatSessions.firstWhere(
      (s) => s.id == currentSessionId,
      orElse: () => chatSessions.first,
    );
  }

  List<ChatMessage> get chatHistory => activeChatSession.messages;
  set chatHistory(List<ChatMessage> list) {
    activeChatSession.messages = list;
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    defaultReminder = _prefs!.getInt(_kDefaultReminder) ?? 10;
    geminiApiKey = _prefs!.getString(_kGeminiApiKey) ?? '';
    final b = _prefs!.getString(_kBlocks);
    final r = _prefs!.getString(_kRoutines);
    final t = _prefs!.getString(_kTasks);
    final ch = _prefs!.getString(_kChatHistory);
    final cats = _prefs!.getString(_kCategories);
    final cs = _prefs!.getString(_kChatSessions);
    currentSessionId = _prefs!.getString(_kCurrentSessionId);

    if (cats != null) {
      try {
        final decoded = (jsonDecode(cats) as List)
            .map((e) => CategoryInfo.fromJson(e as Map<String, dynamic>))
            .toList();
        if (decoded.isNotEmpty) {
          categories = decoded;
        }
      } catch (_) {}
    }
    _syncCategoryRegistry();

    if (b != null) {
      blocks = (jsonDecode(b) as List)
          .map((e) => TimeBlock.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (r != null) {
      routines = (jsonDecode(r) as List)
          .map((e) => Routine.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (t != null) {
      tasks = (jsonDecode(t) as List)
          .map((e) => TaskItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // Gestion des sessions de chat et migration de l'ancien historique
    List<ChatMessage> legacyChat = [];
    if (ch != null) {
      try {
        legacyChat = (jsonDecode(ch) as List)
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    if (cs != null) {
      try {
        chatSessions = (jsonDecode(cs) as List)
            .map((e) => ChatSession.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    if (chatSessions.isEmpty) {
      final initialSession = ChatSession(
        id: newId(),
        title: legacyChat.isNotEmpty ? _summaryFromText(legacyChat.first.text) : 'Discussion générale',
        createdAt: DateTime.now(),
        messages: legacyChat,
      );
      chatSessions.add(initialSession);
      currentSessionId = initialSession.id;
    } else {
      if (currentSessionId == null || !chatSessions.any((s) => s.id == currentSessionId)) {
        currentSessionId = chatSessions.first.id;
      }
    }

    _applied = (_prefs!.getStringList(_kApplied) ?? []).toSet();

    // Audit et déduplication immédiate globale
    runFullDeduplicationAudit();

    // Initialisation ou synchronisation de la semaine en cours
    applyWeek(DateTime.now());

    _save();
    // Re-planifier uniquement les rappels imminents de la semaine courante en arrière-plan
    final now = DateTime.now();
    final nextWeek = now.add(const Duration(days: 7));
    NotificationService.rescheduleAll(
      blocks.where((x) {
        final p = x.date.split('-').map(int.parse).toList();
        final dt = DateTime(p[0], p[1], p[2]);
        return dt.isAfter(now.subtract(const Duration(days: 1))) && dt.isBefore(nextWeek);
      }).toList(),
    );
    NotificationService.rescheduleAllTasks(tasks);
    notifyListeners();
  }

  static String _summaryFromText(String text) {
    final clean = text.replaceAll('\n', ' ').trim();
    return clean.length > 32 ? '${clean.substring(0, 32)}...' : clean;
  }

  /// Détecte et élimine automatiquement tous les doublons de blocs
  int _deduplicateBlocks() {
    final seen = <String>{};
    final seenIds = <String>{};
    final uniqueBlocks = <TimeBlock>[];
    var removed = 0;
    for (final b in blocks) {
      final sig = '${b.date}|${b.startMin}|${b.endMin}|${b.title.trim().toLowerCase()}';
      if (seen.add(sig) && seenIds.add(b.id)) {
        uniqueBlocks.add(b);
      } else {
        NotificationService.cancel(b.notifId);
        removed++;
      }
    }
    if (removed > 0) {
      blocks = uniqueBlocks;
    }
    return removed;
  }

  /// Détecte et élimine tous les doublons de routines
  int _deduplicateRoutines() {
    final seen = <String>{};
    final seenIds = <String>{};
    final unique = <Routine>[];
    var removed = 0;
    for (final r in routines) {
      final daysKey = (r.weekdays.toList()..sort()).join(',');
      final sig = '${r.title.trim().toLowerCase()}|${r.startMin}|${r.endMin}|$daysKey';
      if (seen.add(sig) && seenIds.add(r.id)) {
        unique.add(r);
      } else {
        removed++;
      }
    }
    if (removed > 0) {
      routines = unique;
    }
    return removed;
  }

  /// Détecte et élimine tous les doublons de tâches IA
  int _deduplicateTasks() {
    final seen = <String>{};
    final seenIds = <String>{};
    final unique = <TaskItem>[];
    var removed = 0;
    for (final t in tasks) {
      final daysKey = (t.weekdays.toList()..sort()).join(',');
      final sig = '${t.title.trim().toLowerCase()}|${t.timeMin}|${t.date}|$daysKey';
      if (seen.add(sig) && seenIds.add(t.id)) {
        unique.add(t);
      } else {
        NotificationService.cancelTask(t);
        removed++;
      }
    }
    if (removed > 0) {
      tasks = unique;
    }
    return removed;
  }

  /// Détecte et élimine les doublons de catégories
  int _deduplicateCategories() {
    final seen = <String>{};
    final unique = <CategoryInfo>[];
    var removed = 0;
    for (final c in categories) {
      final sig = c.name.trim().toLowerCase();
      if (seen.add(sig)) {
        unique.add(c);
      } else {
        removed++;
      }
    }
    if (removed > 0) {
      categories = unique;
      _syncCategoryRegistry();
    }
    return removed;
  }

  /// Audit complet et nettoyage de tous les doublons du système
  Map<String, int> runFullDeduplicationAudit() {
    final b = _deduplicateBlocks();
    final r = _deduplicateRoutines();
    final t = _deduplicateTasks();
    final c = _deduplicateCategories();
    return {
      'blocks': b,
      'routines': r,
      'tasks': t,
      'categories': c,
      'total': b + r + t + c,
    };
  }

  /// Nettoie tous les doublons et persiste
  int cleanDuplicates() {
    final audit = runFullDeduplicationAudit();
    final total = audit['total'] ?? 0;
    if (total > 0) {
      _save();
      notifyListeners();
    }
    return total;
  }

  void setDefaultReminder(int val) {
    defaultReminder = val;
    _prefs?.setInt(_kDefaultReminder, val);
    notifyListeners();
  }

  /// Génère une sauvegarde complète sous forme de texte lisible
  String exportToText() {
    final buffer = StringBuffer();
    final now = DateTime.now();
    buffer.writeln('==================================================');
    buffer.writeln('          KANLÉ - SAUVEGARDE DU PLANNING          ');
    buffer.writeln('  Date: ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} à ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}');
    buffer.writeln('==================================================\n');

    buffer.writeln('--- ROUTINES ET HABITUDES (${routines.length}) ---');
    if (routines.isEmpty) {
      buffer.writeln('Aucune routine configurée.\n');
    } else {
      const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
      for (final r in routines) {
        final daysStr = r.weekdays.map((d) => days[(d - 1).clamp(0, 6)]).join(', ');
        buffer.writeln('• ${r.title}');
        buffer.writeln('  Horaires: ${fmtMin(r.startMin)} - ${fmtMin(r.endMin)}');
        buffer.writeln('  Répétition: $daysStr');
        buffer.writeln('  Catégorie: ${r.category.name}');
        final reminderStr = r.reminderMin == 0 ? "À l'heure" : "${r.reminderMin} min avant";
        buffer.writeln('  Rappel: $reminderStr');
        buffer.writeln('');
      }
    }

    // Regrouper les blocs par date
    final sortedBlocks = List<TimeBlock>.from(blocks)
      ..sort((a, b) {
        final c = a.date.compareTo(b.date);
        return c != 0 ? c : a.startMin.compareTo(b.startMin);
      });

    final grouped = <String, List<TimeBlock>>{};
    for (final b in sortedBlocks) {
      grouped.putIfAbsent(b.date, () => []).add(b);
    }

    buffer.writeln('--- PLANNING ET CRÉNEAUX (${blocks.length} blocs) ---');
    if (grouped.isEmpty) {
      buffer.writeln('Aucun bloc planifié.\n');
    } else {
      grouped.forEach((date, dayBlocks) {
        buffer.writeln('[$date] (${dayBlocks.length} blocs) :');
        for (final b in dayBlocks) {
          final status = b.done ? '✓ Fait' : '○ En attente';
          buffer.writeln('  • ${fmtMin(b.startMin)} - ${fmtMin(b.endMin)} : ${b.title} [${b.category.name}] ($status)');
          if (b.note.isNotEmpty) {
            buffer.writeln('    Note: ${b.note}');
          }
        }
        buffer.writeln('');
      });
    }

    buffer.writeln('--- TÂCHES GÉRÉES PAR L\'IA (${tasks.length}) ---');
    if (tasks.isEmpty) {
      buffer.writeln('Aucune tâche enregistrée.\n');
    } else {
      for (final t in tasks) {
        final timeStr = t.timeMin != null ? fmtMin(t.timeMin!) : 'sans heure';
        buffer.writeln('• ${t.title} ($timeStr - ${t.recurrenceLabel})');
      }
      buffer.writeln('');
    }

    buffer.writeln('==================================================');
    buffer.writeln('FICHIER DE DONNÉES JSON (POUR RESTAURATION) :');
    final backupData = {
      'version': 1,
      'exportedAt': now.toIso8601String(),
      'defaultReminder': defaultReminder,
      'routines': routines.map((e) => e.toJson()).toList(),
      'blocks': blocks.map((e) => e.toJson()).toList(),
      'tasks': tasks.map((e) => e.toJson()).toList(),
    };
    buffer.writeln(const JsonEncoder.withIndent('  ').convert(backupData));
    buffer.writeln('==================================================');

    return buffer.toString();
  }

  /// Importe et restaure les données à partir d'un texte de sauvegarde ou JSON
  Future<(int, int)> importFromText(String rawText) async {
    Map<String, dynamic>? data;

    // 1. Tenter un parsing JSON direct
    try {
      final decoded = jsonDecode(rawText.trim());
      if (decoded is Map<String, dynamic>) {
        data = decoded;
      }
    } catch (_) {}

    // 2. Si non direct, chercher le bloc JSON délimité dans le texte de sauvegarde
    if (data == null) {
      final startIdx = rawText.indexOf('{');
      final endIdx = rawText.lastIndexOf('}');
      if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
        try {
          final jsonSub = rawText.substring(startIdx, endIdx + 1);
          final decoded = jsonDecode(jsonSub);
          if (decoded is Map<String, dynamic>) {
            data = decoded;
          }
        } catch (_) {}
      }
    }

    if (data == null) {
      throw const FormatException('Aucun format de données valide détecté.');
    }

    var routinesAdded = 0;
    var blocksAdded = 0;

    // Restaurer le rappel par défaut si présent
    if (data['defaultReminder'] is int) {
      defaultReminder = data['defaultReminder'] as int;
      _prefs?.setInt(_kDefaultReminder, defaultReminder);
    }

    // Restaurer les routines
    if (data['routines'] is List) {
      for (final item in data['routines']) {
        if (item is Map<String, dynamic>) {
          try {
            final r = Routine.fromJson(item);
            final exists = routines.any((x) =>
                x.title.trim().toLowerCase() == r.title.trim().toLowerCase() &&
                setEquals(x.weekdays, r.weekdays));
            if (!exists) {
              routines.add(r);
              routinesAdded++;
            }
          } catch (_) {}
        }
      }
    }

    // Restaurer les blocs
    if (data['blocks'] is List) {
      for (final item in data['blocks']) {
        if (item is Map<String, dynamic>) {
          try {
            final b = TimeBlock.fromJson(item);
            final exists = blocks.any((x) =>
                x.date == b.date &&
                x.startMin == b.startMin &&
                x.endMin == b.endMin &&
                x.title.trim().toLowerCase() == b.title.trim().toLowerCase());
            if (!exists) {
              blocks.add(b);
              blocksAdded++;
              if (!b.done && b.reminderMin >= 0) {
                NotificationService.schedule(b);
              }
            }
          } catch (_) {}
        }
      }
    }

    // Restaurer les tâches IA
    if (data['tasks'] is List) {
      for (final item in data['tasks']) {
        if (item is Map<String, dynamic>) {
          try {
            final t = TaskItem.fromJson(item);
            final exists = tasks.any((x) =>
                x.title.trim().toLowerCase() == t.title.trim().toLowerCase() &&
                x.timeMin == t.timeMin &&
                x.date == t.date);
            if (!exists) {
              tasks.add(t);
              NotificationService.scheduleTask(t);
            }
          } catch (_) {}
        }
      }
    }

    _deduplicateBlocks();
    _save();
    notifyListeners();
    return (routinesAdded, blocksAdded);
  }

  void _save() {
    _prefs?.setString(
        _kBlocks, jsonEncode(blocks.map((e) => e.toJson()).toList()));
    _prefs?.setString(
        _kRoutines, jsonEncode(routines.map((e) => e.toJson()).toList()));
    _prefs?.setString(
        _kTasks, jsonEncode(tasks.map((e) => e.toJson()).toList()));
    _prefs?.setString(
        _kCategories, jsonEncode(categories.map((e) => e.toJson()).toList()));
    _prefs?.setString(
        _kChatSessions, jsonEncode(chatSessions.map((e) => e.toJson()).toList()));
    if (currentSessionId != null) {
      _prefs?.setString(_kCurrentSessionId, currentSessionId!);
    }
    _prefs?.setString(
        _kChatHistory, jsonEncode(chatHistory.map((e) => e.toJson()).toList()));
    _prefs?.setString(_kGeminiApiKey, geminiApiKey);
    _prefs?.setStringList(_kApplied, _applied.toList());
    _prefs?.setInt(_kDefaultReminder, defaultReminder);
  }

  // ==========================================
  // GESTION DES CATÉGORIES DYNAMIQUES
  // ==========================================

  void addCategory(CategoryInfo cat) {
    final existingIdx = categories.indexWhere(
      (c) => c.name.trim().toLowerCase() == cat.name.trim().toLowerCase(),
    );
    if (existingIdx >= 0) {
      categories[existingIdx] = cat;
    } else {
      categories.add(cat);
    }
    _syncCategoryRegistry();
    _save();
    notifyListeners();
  }

  bool deleteCategory(String catId) {
    final fallbackCat = categories.isNotEmpty ? categories.first.id : 'prayer';
    for (final b in blocks.where((b) => b.categoryId == catId)) {
      b.categoryId = fallbackCat;
    }
    for (final r in routines.where((r) => r.categoryId == catId)) {
      r.categoryId = fallbackCat;
    }
    categories.removeWhere((c) => c.id == catId);
    _syncCategoryRegistry();
    _save();
    notifyListeners();
    return true;
  }

  void updateCategory(CategoryInfo cat) {
    final idx = categories.indexWhere((c) => c.id == cat.id);
    if (idx >= 0) {
      categories[idx] = cat;
      _syncCategoryRegistry();
      _save();
      notifyListeners();
    }
  }

  // ==========================================
  // GESTION DES SESSIONS DU CHAT IA
  // ==========================================

  ChatSession startNewChatSession([String? title]) {
    final s = ChatSession(
      id: newId(),
      title: title ?? 'Nouvelle discussion',
      createdAt: DateTime.now(),
    );
    chatSessions.insert(0, s);
    currentSessionId = s.id;
    _save();
    notifyListeners();
    return s;
  }

  void switchChatSession(String sessionId) {
    if (chatSessions.any((s) => s.id == sessionId)) {
      currentSessionId = sessionId;
      _save();
      notifyListeners();
    }
  }

  void deleteChatSession(String sessionId) {
    chatSessions.removeWhere((s) => s.id == sessionId);
    if (chatSessions.isEmpty) {
      startNewChatSession();
    } else if (currentSessionId == sessionId) {
      currentSessionId = chatSessions.first.id;
    }
    _save();
    notifyListeners();
  }

  String newId() => _uuid.v4();

  /// Sélection de date sans recalcul lourd ni écriture disque pour garantir 60 FPS
  void selectDate(DateTime d) {
    selectedDate = DateTime(d.year, d.month, d.day);
    notifyListeners();
  }

  List<TimeBlock> blocksFor(DateTime d) {
    final k = dateKey(d);
    final list = blocks.where((b) => b.date == k).toList()
      ..sort((a, b) => a.startMin.compareTo(b.startMin));
    return list;
  }

  /// Détecte tous les IDs de blocs en conflit (chevauchement d'heures) sur une date
  Set<String> getConflictingBlockIds(DateTime d) {
    final list = blocksFor(d);
    final conflicts = <String>{};
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        final a = list[i];
        final b = list[j];
        if (a.startMin < b.endMin && a.endMin > b.startMin) {
          conflicts.add(a.id);
          conflicts.add(b.id);
        }
      }
    }
    return conflicts;
  }

  /// Trouve les blocs qui chevauchent l'intervalle [startMin, endMin] pour une date
  List<TimeBlock> findConflicts(String dateStr, int startMin, int endMin,
      {String? ignoreBlockId}) {
    return blocks.where((b) {
      if (b.date != dateStr) return false;
      if (ignoreBlockId != null && b.id == ignoreBlockId) return false;
      return startMin < b.endMin && endMin > b.startMin;
    }).toList()
      ..sort((a, b) => a.startMin.compareTo(b.startMin));
  }

  /// Résout un conflit en décalant [blockIdToShift] pour qu'il commence dès la fin de [refBlockId]
  bool resolveConflictShiftAfter(String blockIdToShift, String refBlockId) {
    final toShiftIndex = blocks.indexWhere((b) => b.id == blockIdToShift);
    final refIndex = blocks.indexWhere((b) => b.id == refBlockId);
    if (toShiftIndex < 0 || refIndex < 0) return false;

    final toShift = blocks[toShiftIndex];
    final ref = blocks[refIndex];
    final duration = (toShift.endMin - toShift.startMin).clamp(15, 24 * 60);
    toShift.startMin = ref.endMin;
    toShift.endMin = (toShift.startMin + duration).clamp(0, 24 * 60);

    NotificationService.schedule(toShift);
    _save();
    notifyListeners();
    return true;
  }

  /// Résout un conflit en raccourcissant [blockIdToShorten] pour qu'il s'arrête au début de [refBlockId]
  bool resolveConflictAdjustDuration(String blockIdToShorten, String refBlockId) {
    final toShortenIndex = blocks.indexWhere((b) => b.id == blockIdToShorten);
    final refIndex = blocks.indexWhere((b) => b.id == refBlockId);
    if (toShortenIndex < 0 || refIndex < 0) return false;

    final toShorten = blocks[toShortenIndex];
    final ref = blocks[refIndex];
    if (ref.startMin > toShorten.startMin) {
      toShorten.endMin = ref.startMin;
      NotificationService.schedule(toShorten);
      _save();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Calcule et retourne le premier créneau horaire libre (startMin, endMin) pour une date donnée
  (int startMin, int endMin) findNextAvailableSlot(
    String dateStr,
    int durationMin, {
    int preferredStart = 0,
    String? ignoreBlockId,
  }) {
    final dur = durationMin.clamp(15, 24 * 60);
    final dayBlocks = blocks.where((b) {
      if (b.date != dateStr) return false;
      if (ignoreBlockId != null && b.id == ignoreBlockId) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.startMin.compareTo(b.startMin));

    // Si aucun bloc n'existe sur la journée, début au créneau préféré
    if (dayBlocks.isEmpty) {
      final s = preferredStart.clamp(0, (24 * 60 - dur).clamp(0, 24 * 60));
      return (s, (s + dur).clamp(0, 24 * 60));
    }

    // 1. Tester directement le créneau préféré
    final prefEnd = (preferredStart + dur).clamp(0, 24 * 60);
    final hasConflictAtPref = dayBlocks.any((b) => preferredStart < b.endMin && prefEnd > b.startMin);
    if (!hasConflictAtPref && prefEnd <= 24 * 60) {
      return (preferredStart, prefEnd);
    }

    // 2. Chercher le premier créneau libre >= preferredStart
    var candidateStart = preferredStart;
    for (final b in dayBlocks) {
      if (candidateStart < b.startMin) {
        if (b.startMin - candidateStart >= dur) {
          return (candidateStart, candidateStart + dur);
        }
      }
      if (b.endMin > candidateStart) {
        candidateStart = b.endMin;
      }
    }

    // 3. Après le dernier bloc
    if (candidateStart + dur <= 24 * 60) {
      return (candidateStart, candidateStart + dur);
    }

    // 4. Fallback : chercher depuis 00:00 s'il y a un créneau plus tôt dans la journée
    var fallbackStart = 0;
    for (final b in dayBlocks) {
      if (b.startMin > fallbackStart && b.startMin - fallbackStart >= dur) {
        return (fallbackStart, fallbackStart + dur);
      }
      if (b.endMin > fallbackStart) {
        fallbackStart = b.endMin;
      }
    }

    // Dernier recours : fin de journée clampée
    final lastEnd = dayBlocks.last.endMin;
    final s = (lastEnd + dur <= 24 * 60) ? lastEnd : (24 * 60 - dur).clamp(0, 24 * 60);
    return (s, (s + dur).clamp(0, 24 * 60));
  }

  /// Résout automatiquement TOUS les conflits d'une date en décalant en cascade jusqu'à élimination totale des chevauchements
  int resolveAllConflicts(DateTime d) {
    final k = dateKey(d);
    var totalResolved = 0;
    var iterations = 0;

    // Boucle de convergence pour garantir mathématiquement 0 conflit subsistant
    while (iterations < 50) {
      final dayBlocks = blocks.where((b) => b.date == k).toList()
        ..sort((a, b) => a.startMin.compareTo(b.startMin));

      var changedInThisPass = false;
      for (var i = 0; i < dayBlocks.length - 1; i++) {
        final current = dayBlocks[i];
        final next = dayBlocks[i + 1];

        if (next.startMin < current.endMin) {
          final nextDur = (next.endMin - next.startMin).clamp(15, 24 * 60);
          next.startMin = current.endMin;
          next.endMin = (next.startMin + nextDur).clamp(0, 24 * 60);
          NotificationService.schedule(next);
          totalResolved++;
          changedInThisPass = true;
          break; // Réordonner pour cascader parfaitement
        }
      }

      if (!changedInThisPass) break;
      iterations++;
    }

    if (totalResolved > 0) {
      _save();
      notifyListeners();
    }
    return totalResolved;
  }

  void upsertBlock(TimeBlock b) {
    final i = blocks.indexWhere((e) => e.id == b.id);
    if (i >= 0) {
      blocks[i] = b;
    } else {
      // Détection anti-doublon immédiate (même jour, même créneau, même titre)
      final dupIndex = blocks.indexWhere((e) =>
          e.date == b.date &&
          e.startMin == b.startMin &&
          e.endMin == b.endMin &&
          e.title.trim().toLowerCase() == b.title.trim().toLowerCase());
      if (dupIndex >= 0) {
        b.id = blocks[dupIndex].id;
        b.notifId = blocks[dupIndex].notifId;
        blocks[dupIndex] = b;
      } else {
        blocks.add(b);
      }
    }
    NotificationService.schedule(b);
    _save();
    notifyListeners();
  }

  void deleteBlock(String id) {
    final i = blocks.indexWhere((e) => e.id == id);
    if (i >= 0) {
      final b = blocks[i];
      NotificationService.cancel(b.notifId);
      if (b.routineId != null) {
        _applied.remove('${b.routineId}|${b.date}');
      }
      blocks.removeAt(i);
      _save();
      notifyListeners();
    }
  }

  void toggleDone(TimeBlock b) {
    b.done = !b.done;
    NotificationService.schedule(b);
    _save();
    notifyListeners();
  }

  DateTime _startOfWeek(DateTime d) {
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
  }

  void _applyRoutineToWeek(DateTime targetDate, Routine r) {
    final monday = _startOfWeek(targetDate);
    for (var i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      final k = dateKey(day);
      final key = '${r.id}|$k';

      if (r.weekdays.contains(day.weekday)) {
        // La routine est active ce jour
        final existingIndex = blocks.indexWhere((b) => b.date == k && b.routineId == r.id);
        if (existingIndex >= 0) {
          final b = blocks[existingIndex];
          if (!b.done) {
            b.title = r.title;
            b.colorValue = r.colorValue;
            b.startMin = r.startMin;
            b.endMin = r.endMin;
            b.categoryId = r.categoryId;
            b.reminderMin = r.reminderMin;
            NotificationService.schedule(b);
          }
          _applied.add(key);
        } else {
          // Création directe du bloc
          final nb = TimeBlock(
            id: newId(),
            title: r.title,
            colorValue: r.colorValue,
            startMin: r.startMin,
            endMin: r.endMin,
            date: k,
            routineId: r.id,
            reminderMin: r.reminderMin,
            categoryId: r.categoryId,
          );
          blocks.add(nb);
          _applied.add(key);
          NotificationService.schedule(nb);
        }
        // Garantie Zéro-Conflit : résoudre immédiatement tout conflit avec le planning du jour
        resolveAllConflicts(day);
      } else {
        // Ce jour a été décoché dans la routine : retirer les blocs non terminés
        blocks.removeWhere((b) {
          if (b.date == k && b.routineId == r.id && !b.done) {
            NotificationService.cancel(b.notifId);
            _applied.remove(key);
            return true;
          }
          return false;
        });
      }
    }
  }

  void upsertRoutine(Routine r) {
    final i = routines.indexWhere((e) => e.id == r.id);
    if (i >= 0) {
      routines[i] = r;
    } else {
      // Détection anti-doublon (même titre et jours actifs)
      final dupIdx = routines.indexWhere((e) =>
          e.title.trim().toLowerCase() == r.title.trim().toLowerCase() &&
          e.startMin == r.startMin &&
          e.endMin == r.endMin &&
          setEquals(e.weekdays, r.weekdays));
      if (dupIdx >= 0) {
        routines[dupIdx] = r;
      } else {
        routines.add(r);
      }
    }

    // 1. Appliquer immédiatement à la semaine courante
    final now = DateTime.now();
    _applyRoutineToWeek(now, r);

    // 2. Et appliquer à la semaine active dans le planning si différente
    if (_startOfWeek(selectedDate) != _startOfWeek(now)) {
      _applyRoutineToWeek(selectedDate, r);
    }

    _deduplicateBlocks();
    _save();
    notifyListeners();
  }

  /// Supprime une routine et supprime également ses blocs générés dans le planning
  int deleteRoutine(String id, {bool deletePlanningBlocks = true}) {
    routines.removeWhere((e) => e.id == id);
    var deletedBlocksCount = 0;
    if (deletePlanningBlocks) {
      final toRemove = blocks.where((b) => b.routineId == id).toList();
      deletedBlocksCount = toRemove.length;
      for (final b in toRemove) {
        NotificationService.cancel(b.notifId);
      }
      blocks.removeWhere((b) => b.routineId == id);
      _applied.removeWhere((k) => k.startsWith('$id|'));
    }
    _save();
    notifyListeners();
    return deletedBlocksCount;
  }

  /// Applique toutes les routines à la semaine de [targetDate] (du Lundi au Dimanche)
  int applyWeek(DateTime targetDate) {
    final monday = _startOfWeek(targetDate);
    var added = 0;
    for (final r in routines) {
      for (var i = 0; i < 7; i++) {
        final day = monday.add(Duration(days: i));
        if (!r.weekdays.contains(day.weekday)) continue;

        final k = dateKey(day);
        final key = '${r.id}|$k';

        final existing = blocks.any((b) => b.date == k && b.routineId == r.id);
        if (!existing) {
          final nb = TimeBlock(
            id: newId(),
            title: r.title,
            colorValue: r.colorValue,
            startMin: r.startMin,
            endMin: r.endMin,
            date: k,
            routineId: r.id,
            reminderMin: r.reminderMin,
            categoryId: r.categoryId,
          );
          blocks.add(nb);
          _applied.add(key);
          NotificationService.schedule(nb);
          added++;
        }
      }
    }
    _deduplicateBlocks();
    _save();
    notifyListeners();
    return added;
  }

  /// Réinitialise UNIQUEMENT le planning (efface tous les blocs et alarmes, garde les routines)
  Future<void> resetPlanningOnly() async {
    for (final b in blocks) {
      await NotificationService.cancel(b.notifId);
    }
    blocks.clear();
    _applied.clear();
    _save();
    notifyListeners();
  }

  /// Réinitialisation totale (planning + routines + alarmes)
  Future<void> resetAll() async {
    await NotificationService.cancelAll();
    blocks.clear();
    routines.clear();
    tasks.clear();
    chatHistory.clear();
    _applied.clear();
    _save();
    notifyListeners();
  }

  /// Minutes planifiées par titre sur [days] jours.
  Map<String, int> minutesByTitle(DateTime end, {int days = 7}) {
    final keys = {
      for (var i = 0; i < days; i++) dateKey(end.subtract(Duration(days: i)))
    };
    final map = <String, int>{};
    for (final b in blocks.where((b) => keys.contains(b.date))) {
      map[b.title] = (map[b.title] ?? 0) + b.duration;
    }
    return map;
  }

  /// Minutes planifiées par catégorie pour une période ([days] jours ou semaine courante si days == 7).
  Map<String, int> minutesByCategory(DateTime anchor, {int days = 7}) {
    final Set<String> keys;
    if (days == 7) {
      final monday = _startOfWeek(anchor);
      keys = {for (var i = 0; i < 7; i++) dateKey(monday.add(Duration(days: i)))};
    } else if (days == 1) {
      keys = {dateKey(anchor)};
    } else {
      keys = {
        for (var i = 0; i < days; i++) dateKey(anchor.subtract(Duration(days: i)))
      };
    }
    final map = <String, int>{};
    for (final b in blocks.where((b) => keys.contains(b.date))) {
      map[b.categoryId] = (map[b.categoryId] ?? 0) + b.duration;
    }
    return map;
  }

  /// (date, planifié, terminé) en minutes par jour pour la période.
  List<(DateTime, int, int)> dailyStats(DateTime anchor, {int days = 7}) {
    final List<DateTime> dateList;
    if (days == 7) {
      final monday = _startOfWeek(anchor);
      dateList = [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];
    } else if (days == 1) {
      dateList = [DateTime(anchor.year, anchor.month, anchor.day)];
    } else {
      dateList = [
        for (var i = days - 1; i >= 0; i--)
          DateTime(anchor.year, anchor.month, anchor.day).subtract(Duration(days: i))
      ];
    }

    return [
      for (final d in dateList)
        () {
          final list = blocksFor(d);
          final planned = list.fold<int>(0, (s, b) => s + b.duration);
          final done =
              list.where((b) => b.done).fold<int>(0, (s, b) => s + b.duration);
          return (d, planned, done);
        }()
    ];
  }

  // ==========================================
  // SECTION GESTION DES TÂCHES (UNIQUEMENT IA)
  // ==========================================

  /// Récupère toutes les tâches applicables à une date donnée
  List<TaskItem> tasksFor(DateTime d) {
    return tasks.where((t) => t.isApplicableForDate(d)).toList()
      ..sort((a, b) {
        if (a.timeMin == null && b.timeMin == null) return 0;
        if (a.timeMin == null) return 1;
        if (b.timeMin == null) return -1;
        return a.timeMin!.compareTo(b.timeMin!);
      });
  }

  /// Ajoute une nouvelle tâche et programme son alarme avec protection anti-doublon
  void addTask(TaskItem task) {
    final existingIdx = tasks.indexWhere((t) =>
        t.id == task.id ||
        (t.title.trim().toLowerCase() == task.title.trim().toLowerCase() &&
            t.timeMin == task.timeMin &&
            t.date == task.date &&
            setEquals(t.weekdays, task.weekdays)));
    if (existingIdx >= 0) {
      tasks[existingIdx] = task;
    } else {
      tasks.add(task);
    }
    NotificationService.scheduleTask(task);
    _save();
    notifyListeners();
  }

  /// Met à jour une tâche existante
  void updateTask(TaskItem task) {
    final idx = tasks.indexWhere((t) => t.id == task.id);
    if (idx >= 0) {
      tasks[idx] = task;
      NotificationService.scheduleTask(task);
      _save();
      notifyListeners();
    }
  }

  /// Supprime une tâche et annule ses notifications
  void deleteTask(String id) {
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx >= 0) {
      final task = tasks[idx];
      NotificationService.cancelTask(task);
      tasks.removeAt(idx);
      _save();
      notifyListeners();
    }
  }

  /// Coche ou décoche une tâche pour une date donnée
  void toggleTaskDone(String id, DateTime date) {
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx >= 0) {
      final task = tasks[idx];
      task.toggleDoneForDate(date);
      _save();
      notifyListeners();
    }
  }

  /// Définit la clé API Gemini
  void setGeminiApiKey(String key) {
    geminiApiKey = key.trim();
    _prefs?.setString(_kGeminiApiKey, geminiApiKey);
    notifyListeners();
  }

  /// Vide l'historique de la discussion active
  void clearChatHistory() {
    activeChatSession.messages.clear();
    _save();
    notifyListeners();
  }

  // ==========================================
  // SECTION ASSISTANT IA & ACTIONS
  // ==========================================

  /// Envoie un prompt à l'assistant IA
  Future<ChatMessage> askAi(String prompt) async {
    final session = activeChatSession;
    if (session.messages.isEmpty ||
        session.title == 'Discussion générale' ||
        session.title == 'Nouvelle discussion') {
      session.title = _summaryFromText(prompt);
    }

    final userMsg = ChatMessage(
      id: newId(),
      sender: 'user',
      text: prompt.trim(),
      timestamp: DateTime.now(),
    );
    session.messages.add(userMsg);
    isAiLoading = true;
    notifyListeners();

    try {
      final result = await AiService.processUserInput(
        prompt: prompt,
        apiKey: AiConfig.geminiApiKey.isNotEmpty ? AiConfig.geminiApiKey : geminiApiKey,
        currentDate: selectedDate,
        currentBlocks: blocks,
        currentTasks: tasks,
      );

      final assistantMsg = ChatMessage(
        id: newId(),
        sender: 'assistant',
        text: result.text,
        timestamp: DateTime.now(),
        actions: result.actions,
      );

      session.messages.add(assistantMsg);
      _save();
      return assistantMsg;
    } finally {
      isAiLoading = false;
      notifyListeners();
    }
  }

  /// Applique toutes les actions fournies en une seule passe optimisée
  int applyAllAiActions(List<AiAction> actions) {
    var count = 0;
    for (final act in actions) {
      if (!act.isApplied) {
        final ok = applyAiAction(act);
        if (ok) count++;
      }
    }
    return count;
  }

  /// Applique une action générée par l'IA
  bool applyAiAction(AiAction action) {
    if (action.isApplied) return false;
    final payload = action.payload;

    try {
      switch (action.type) {
        case 'add_task':
          final title = payload['title'] as String? ?? 'Nouvelle tâche';
          final timeMin = payload['timeMin'] as int?;
          final isDaily = payload['isDaily'] as bool? ?? false;
          final dateStr = payload['date'] as String?;
          final weekdaysList = payload['weekdays'] as List?;
          final weekdays = weekdaysList != null
              ? Set<int>.from(weekdaysList.map((e) => (e as num).toInt()))
              : <int>{};

          final task = TaskItem(
            id: newId(),
            title: title,
            timeMin: timeMin,
            isDaily: isDaily,
            date: dateStr,
            weekdays: weekdays,
          );
          addTask(task);
          break;

        case 'add_routine':
          final title = payload['title'] as String? ?? 'Nouvelle routine';
          final startMin = payload['startMin'] as int? ?? 480;
          final endMin = payload['endMin'] as int? ?? 540;
          final categoryId = payload['category'] as String? ?? 'routine';
          final weekdaysList = payload['weekdays'] as List?;
          final weekdays = weekdaysList != null && weekdaysList.isNotEmpty
              ? Set<int>.from(weekdaysList.map((e) => (e as num).toInt()))
              : <int>{1, 2, 3, 4, 5, 6, 7};
          final cat = getCategoryById(categoryId, categories);

          final routine = Routine(
            id: newId(),
            title: title,
            colorValue: cat.defaultColor.value,
            startMin: startMin,
            endMin: endMin,
            weekdays: weekdays,
            categoryId: categoryId,
            reminderMin: defaultReminder,
          );
          upsertRoutine(routine);
          break;

        case 'delete_task':
          final id = payload['id'] as String?;
          if (id != null) {
            deleteTask(id);
          }
          break;

        case 'toggle_task':
          final id = payload['id'] as String?;
          if (id != null) {
            toggleTaskDone(id, selectedDate);
          }
          break;

        case 'add_block':
          final title = payload['title'] as String? ?? 'Nouveau créneau';
          final dateStr = payload['date'] as String? ?? dateKey(selectedDate);
          final startMin = payload['startMin'] as int? ?? 540;
          final endMin = payload['endMin'] as int? ?? 600;
          final categoryId = payload['category'] as String? ?? 'focus';
          final note = payload['note'] as String? ?? '';
          final category = getCategoryById(categoryId, categories);
          final isRoutine = payload['isRoutine'] as bool? ??
              (categoryId == 'routine' ||
                  title.toLowerCase().contains('routine') ||
                  title.toLowerCase().contains('habitude'));

          String? routineId;

          // Si le bloc est une routine ou une habitude, créer également la Routine dans s.routines
          if (isRoutine) {
            final routine = Routine(
              id: newId(),
              title: title,
              colorValue: category.defaultColor.value,
              startMin: startMin,
              endMin: endMin,
              weekdays: payload['weekdays'] != null
                  ? Set<int>.from((payload['weekdays'] as List).map((e) => (e as num).toInt()))
                  : {1, 2, 3, 4, 5, 6, 7},
              categoryId: categoryId,
              reminderMin: defaultReminder,
            );
            upsertRoutine(routine);
            routineId = routine.id;
          }

          final block = TimeBlock(
            id: newId(),
            title: title,
            note: note,
            colorValue: category.defaultColor.value,
            startMin: startMin,
            endMin: endMin,
            date: dateStr,
            categoryId: categoryId,
            reminderMin: defaultReminder,
            routineId: routineId,
          );
          upsertBlock(block);
          final parts = dateStr.split('-').map(int.parse).toList();
          final target = DateTime(parts[0], parts[1], parts[2]);
          resolveAllConflicts(target);
          break;

        case 'update_block':
          final id = payload['id'] as String?;
          if (id != null) {
            final idx = blocks.indexWhere((b) => b.id == id);
            if (idx >= 0) {
              final b = blocks[idx];
              if (payload['title'] != null) b.title = payload['title'];
              if (payload['startMin'] != null) b.startMin = payload['startMin'];
              if (payload['endMin'] != null) b.endMin = payload['endMin'];
              if (payload['category'] != null) {
                b.categoryId = payload['category'];
                b.colorValue = getCategoryById(b.categoryId, categories).defaultColor.value;
              }
              upsertBlock(b);
              final parts = b.date.split('-').map(int.parse).toList();
              final target = DateTime(parts[0], parts[1], parts[2]);
              resolveAllConflicts(target);
            }
          }
          break;

        case 'delete_block':
          final id = payload['id'] as String?;
          if (id != null) {
            deleteBlock(id);
          }
          break;

        case 'resolve_conflicts':
          final dateStr = payload['date'] as String? ?? dateKey(selectedDate);
          final parts = dateStr.split('-').map(int.parse).toList();
          final target = DateTime(parts[0], parts[1], parts[2]);
          resolveAllConflicts(target);
          break;

        default:
          return false;
      }

      action.isApplied = true;
      _save();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Erreur lors de l\'application de l\'action IA: $e');
      return false;
    }
  }
}
