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

  const CategoryInfo({
    required this.id,
    required this.name,
    required this.icon,
    required this.defaultColor,
  });
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

CategoryInfo getCategoryById(String? id) => kCategories.firstWhere(
      (c) => c.id == id,
      orElse: () => kCategories[0],
    );

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
