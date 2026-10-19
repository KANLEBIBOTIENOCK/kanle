import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'models.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const String _kChannelId = 'kanle_alarms_v5';
  static const String _kChannelName = 'Alarmes & Rappels Kanlé';
  static const String _kChannelDesc =
      'Alarmes prioritaires pour vos blocs de temps et routines (Mode Réveil Android)';

  static const _androidDetails = AndroidNotificationDetails(
    _kChannelId,
    _kChannelName,
    channelDescription: _kChannelDesc,
    importance: Importance.max,
    priority: Priority.max,
    visibility: NotificationVisibility.public,
    category: AndroidNotificationCategory.alarm,
    audioAttributesUsage: AudioAttributesUsage.alarm,
    playSound: true,
    enableVibration: true,
    fullScreenIntent: true,
  );

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
      debugPrint('Timezone local initialisé sur: ${info.identifier}');
    } catch (e) {
      debugPrint('Erreur init timezone: $e, fallback sur UTC');
      tz.setLocalLocation(tz.UTC);
    }

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Notification touchée: ${response.payload}');
      },
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Création explicite du canal Android avec priorité MAX et usage Réveil (Alarm)
    const channel = AndroidNotificationChannel(
      _kChannelId,
      _kChannelName,
      description: _kChannelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );
    await android?.createNotificationChannel(channel);

    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    _ready = true;
  }

  static Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final notif = await android?.requestNotificationsPermission() ?? false;
    final alarm = await android?.requestExactAlarmsPermission() ?? false;
    return notif && alarm;
  }

  static Future<void> showTest() async {
    if (!_ready) return;
    await _plugin.show(
      id: 999999,
      title: 'Kanlé · Test immédiat',
      body: 'Le canal d\'alarme prioritaire fonctionne parfaitement !',
      notificationDetails: const NotificationDetails(android: _androidDetails),
    );
  }

  /// Programme une alarme test dans [seconds] secondes avec le mode AlarmClock natif
  /// (Idéal pour éteindre l'écran et vérifier le réveil automatique du téléphone)
  static Future<void> scheduleTestDelayed({int seconds = 10}) async {
    if (!_ready) return;
    final now = tz.TZDateTime.now(tz.local);
    final when = now.add(Duration(seconds: seconds));
    await _plugin.zonedSchedule(
      id: 999998,
      title: 'Kanlé · Alarme Réveil ($seconds s)',
      body: 'Alarme prioritaire déclenchée avec succès en veille !',
      scheduledDate: when,
      notificationDetails: const NotificationDetails(android: _androidDetails),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
    );
  }

  static Future<void> cancel(int notifId) async {
    if (!_ready) return;
    final endNotifId = (notifId ^ 0x40000000) & 0x7FFFFFFF;
    await _plugin.cancel(id: notifId);
    await _plugin.cancel(id: endNotifId);
  }

  static Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }

  /// Re-planifie tous les blocs actifs à venir
  static Future<void> rescheduleAll(List<TimeBlock> blocks) async {
    if (!_ready) return;
    for (final b in blocks) {
      if (!b.done && b.reminderMin >= 0) {
        await schedule(b);
      }
    }
  }

  /// Programme le rappel d'un bloc avec le mode AlarmClock (Priorité système absolue)
  static Future<void> schedule(TimeBlock b) async {
    if (!_ready) return;
    await cancel(b.notifId);
    if (b.reminderMin < 0 || b.done) return;

    final p = b.date.split('-').map(int.parse).toList();
    final start = tz.TZDateTime(
      tz.local,
      p[0],
      p[1],
      p[2],
      b.startMin ~/ 60,
      b.startMin % 60,
    );
    final end = tz.TZDateTime(
      tz.local,
      p[0],
      p[1],
      p[2],
      b.endMin ~/ 60,
      b.endMin % 60,
    );
    final now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime? targetSchedule;
    String bodyText = '';

    if (b.reminderMin > 0) {
      final anticip = start.subtract(Duration(minutes: b.reminderMin));
      if (anticip.isAfter(now)) {
        targetSchedule = anticip;
        bodyText = 'Commence dans ${b.reminderMin} min (${fmtMin(b.startMin)})';
      } else if (start.isAfter(now)) {
        targetSchedule = start;
        bodyText = 'Commence maintenant (${fmtMin(b.startMin)})';
      }
    } else {
      if (start.isAfter(now)) {
        targetSchedule = start;
        bodyText = 'Commence maintenant (${fmtMin(b.startMin)})';
      }
    }

    if (targetSchedule != null) {
      debugPrint('Planification AlarmClock début ID ${b.notifId} ("${b.title}") pour $targetSchedule');
      try {
        await _plugin.zonedSchedule(
          id: b.notifId,
          title: b.title,
          body: bodyText,
          scheduledDate: targetSchedule,
          notificationDetails: const NotificationDetails(android: _androidDetails),
          androidScheduleMode: AndroidScheduleMode.alarmClock,
        );
      } catch (e) {
        debugPrint('Erreur planif alarme début: $e');
      }
    }

    // Notification de FIN de bloc demandée par l'utilisateur
    if (end.isAfter(now)) {
      final endNotifId = (b.notifId ^ 0x40000000) & 0x7FFFFFFF;
      debugPrint('Planification AlarmClock fin ID $endNotifId ("${b.title}") pour $end');
      try {
        await _plugin.zonedSchedule(
          id: endNotifId,
          title: '${b.title} · Terminé',
          body: 'Le créneau "${b.title}" est maintenant terminé (${fmtMin(b.endMin)}).',
          scheduledDate: end,
          notificationDetails: const NotificationDetails(android: _androidDetails),
          androidScheduleMode: AndroidScheduleMode.alarmClock,
        );
      } catch (e) {
        debugPrint('Erreur planif alarme fin: $e');
      }
    }
  }

  /// Annule les notifications associées à une tâche
  static Future<void> cancelTask(TaskItem task) async {
    if (!_ready) return;
    await _plugin.cancel(id: task.notifId);
    // Pour les tâches récurrentes sur plusieurs jours, annuler également les IDs dérivés
    for (var w = 1; w <= 7; w++) {
      await _plugin.cancel(id: (task.notifId + w) & 0x7FFFFFFF);
    }
  }

  /// Programme le rappel d'une tâche (ponctuelle ou récurrente) en mode AlarmClock
  static Future<void> scheduleTask(TaskItem task) async {
    if (!_ready) return;
    await cancelTask(task);
    if (task.timeMin == null) return;

    final hour = task.timeMin! ~/ 60;
    final minute = task.timeMin! % 60;
    final now = tz.TZDateTime.now(tz.local);

    if (task.isDaily) {
      // Rappel quotidien à heure fixe
      var target = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (target.isBefore(now)) {
        target = target.add(const Duration(days: 1));
      }
      try {
        await _plugin.zonedSchedule(
          id: task.notifId,
          title: 'Tâche : ${task.title}',
          body: 'Rappel quotidien prévu à ${fmtMin(task.timeMin!)}',
          scheduledDate: target,
          notificationDetails: const NotificationDetails(android: _androidDetails),
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (e) {
        debugPrint('Erreur planification tâche quotidienne: $e');
      }
    } else if (task.weekdays.isNotEmpty) {
      // Rappel sur jours de semaine spécifiques
      for (final w in task.weekdays) {
        final subId = (task.notifId + w) & 0x7FFFFFFF;
        var target = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
        while (target.weekday != w || target.isBefore(now)) {
          target = target.add(const Duration(days: 1));
        }
        try {
          await _plugin.zonedSchedule(
            id: subId,
            title: 'Tâche : ${task.title}',
            body: 'Rappel planifié à ${fmtMin(task.timeMin!)}',
            scheduledDate: target,
            notificationDetails: const NotificationDetails(android: _androidDetails),
            androidScheduleMode: AndroidScheduleMode.alarmClock,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        } catch (e) {
          debugPrint('Erreur planification tâche weekday: $e');
        }
      }
    } else if (task.date != null) {
      // Tâche ponctuelle à date et heure précises
      final p = task.date!.split('-').map(int.parse).toList();
      final target = tz.TZDateTime(tz.local, p[0], p[1], p[2], hour, minute);
      if (target.isAfter(now)) {
        try {
          await _plugin.zonedSchedule(
            id: task.notifId,
            title: 'Tâche : ${task.title}',
            body: 'Rappel prévu à ${fmtMin(task.timeMin!)}',
            scheduledDate: target,
            notificationDetails: const NotificationDetails(android: _androidDetails),
            androidScheduleMode: AndroidScheduleMode.alarmClock,
          );
        } catch (e) {
          debugPrint('Erreur planification tâche ponctuelle: $e');
        }
      }
    }
  }

  /// Re-planifie toutes les tâches actives
  static Future<void> rescheduleAllTasks(List<TaskItem> tasks) async {
    if (!_ready) return;
    for (final t in tasks) {
      if (!t.done || t.isRecurring) {
        await scheduleTask(t);
      }
    }
  }
}
