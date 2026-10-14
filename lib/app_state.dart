import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'models.dart';
import 'notification_service.dart';

class AppState extends ChangeNotifier {
  static const _kBlocks = 'blocks_v1';
  static const _kRoutines = 'routines_v1';
  static const _kDefaultReminder = 'default_reminder_v1';
  final _uuid = const Uuid();

  List<TimeBlock> blocks = [];
  List<Routine> routines = [];
  DateTime selectedDate = DateTime.now();
  int defaultReminder = 10;
  SharedPreferences? _prefs;
  static const _kApplied = 'applied_v1';
  Set<String> _applied = {}; // "routineId|date" déjà générés

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    defaultReminder = _prefs!.getInt(_kDefaultReminder) ?? 10;
    final b = _prefs!.getString(_kBlocks);
    final r = _prefs!.getString(_kRoutines);
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
    _applied = (_prefs!.getStringList(_kApplied) ?? []).toSet();

    // Déduplication immédiate des blocs existants
    _deduplicateBlocks();

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
    notifyListeners();
  }

  /// Détecte et élimine automatiquement tous les doublons de blocs
  int _deduplicateBlocks() {
    final seen = <String>{};
    final uniqueBlocks = <TimeBlock>[];
    var removed = 0;
    for (final b in blocks) {
      final sig = '${b.date}|${b.startMin}|${b.endMin}|${b.title.trim().toLowerCase()}';
      if (seen.add(sig)) {
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

  /// Nettoie tous les doublons et persiste
  int cleanDuplicates() {
    final count = _deduplicateBlocks();
    if (count > 0) {
      _save();
      notifyListeners();
    }
    return count;
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
        buffer.writeln('  Rappel: ${r.reminderMin == 0 ? "À l\'heure" : "${r.reminderMin} min avant"}');
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

    buffer.writeln('==================================================');
    buffer.writeln('FICHIER DE DONNÉES JSON (POUR RESTAURATION) :');
    final backupData = {
      'version': 1,
      'exportedAt': now.toIso8601String(),
      'defaultReminder': defaultReminder,
      'routines': routines.map((e) => e.toJson()).toList(),
      'blocks': blocks.map((e) => e.toJson()).toList(),
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
    _prefs?.setStringList(_kApplied, _applied.toList());
    _prefs?.setInt(_kDefaultReminder, defaultReminder);
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

  /// Résout automatiquement TOUS les conflits d'une date en décalant en cascade les blocs qui se chevauchent
  int resolveAllConflicts(DateTime d) {
    final k = dateKey(d);
    final dayBlocks = blocks.where((b) => b.date == k).toList()
      ..sort((a, b) => a.startMin.compareTo(b.startMin));

    var resolvedCount = 0;
    for (var i = 0; i < dayBlocks.length - 1; i++) {
      final current = dayBlocks[i];
      final next = dayBlocks[i + 1];

      if (next.startMin < current.endMin) {
        final nextDur = (next.endMin - next.startMin).clamp(15, 24 * 60);
        next.startMin = current.endMin;
        next.endMin = (next.startMin + nextDur).clamp(0, 24 * 60);
        NotificationService.schedule(next);
        resolvedCount++;
      }
    }

    if (resolvedCount > 0) {
      _save();
      notifyListeners();
    }
    return resolvedCount;
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
      routines.add(r);
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

  /// Minutes planifiées par catégorie sur [days] jours.
  Map<String, int> minutesByCategory(DateTime end, {int days = 7}) {
    final keys = {
      for (var i = 0; i < days; i++) dateKey(end.subtract(Duration(days: i)))
    };
    final map = <String, int>{};
    for (final b in blocks.where((b) => keys.contains(b.date))) {
      map[b.categoryId] = (map[b.categoryId] ?? 0) + b.duration;
    }
    return map;
  }

  /// (date, planifié, terminé) en minutes par jour sur [days] jours.
  List<(DateTime, int, int)> dailyStats(DateTime end, {int days = 7}) {
    return [
      for (var i = days - 1; i >= 0; i--)
        () {
          final d = DateTime(end.year, end.month, end.day)
              .subtract(Duration(days: i));
          final list = blocksFor(d);
          final planned = list.fold<int>(0, (s, b) => s + b.duration);
          final done =
              list.where((b) => b.done).fold<int>(0, (s, b) => s + b.duration);
          return (d, planned, done);
        }()
    ];
  }
}
