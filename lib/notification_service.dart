import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'models.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _androidDetails = AndroidNotificationDetails(
    'kanle_reminders_v4',
    'Rappels Kanlé',
    channelDescription: 'Alarmes et rappels de vos blocs de temps',
    importance: Importance.max,
    priority: Priority.high,
    visibility: NotificationVisibility.public,
    category: AndroidNotificationCategory.reminder,
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
      title: 'Kanlé',
      body: 'Les notifications et alarmes fonctionnent parfaitement !',
      notificationDetails: const NotificationDetails(android: _androidDetails),
    );
  }

  /// Programme une alarme test dans [seconds] secondes (idéal pour tester écran éteint)
  static Future<void> scheduleTestDelayed({int seconds = 10}) async {
    if (!_ready) return;
    final now = tz.TZDateTime.now(tz.local);
    final when = now.add(Duration(seconds: seconds));
    await _plugin.zonedSchedule(
      id: 999998,
      title: 'Kanlé · Alarme test',
      body: 'Votre rappel a sonné avec succès après $seconds secondes !',
      scheduledDate: when,
      notificationDetails: const NotificationDetails(android: _androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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

  /// Re-planifie tous les blocs actifs à venir (au démarrage).
  static Future<void> rescheduleAll(List<TimeBlock> blocks) async {
    if (!_ready) return;
    for (final b in blocks) {
      if (!b.done && b.reminderMin >= 0) {
        await schedule(b);
      }
    }
  }

  /// Programme le rappel d'un bloc avec repli intelligent si le créneau est imminent,
  /// ainsi que la notification lorsque le bloc est terminé.
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
      } else {
        final diffSeconds = now.difference(start).inSeconds;
        if (diffSeconds < 60) {
          targetSchedule = now.add(const Duration(seconds: 4));
          bodyText = 'Commence maintenant (${fmtMin(b.startMin)})';
        }
      }
    } else {
      if (start.isAfter(now)) {
        targetSchedule = start;
        bodyText = 'Commence maintenant (${fmtMin(b.startMin)})';
      } else {
        final diffSeconds = now.difference(start).inSeconds;
        if (diffSeconds < 60) {
          targetSchedule = now.add(const Duration(seconds: 4));
          bodyText = 'Commence maintenant (${fmtMin(b.startMin)})';
        }
      }
    }

    if (targetSchedule != null) {
      debugPrint('Planification alarme début ID ${b.notifId} ("${b.title}") pour $targetSchedule');
      try {
        await _plugin.zonedSchedule(
          id: b.notifId,
          title: b.title,
          body: bodyText,
          scheduledDate: targetSchedule,
          notificationDetails: const NotificationDetails(android: _androidDetails),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('Erreur planif alarme début: $e');
      }
    }

    // Notification de FIN de bloc demandée par l'utilisateur
    if (end.isAfter(now)) {
      final endNotifId = (b.notifId ^ 0x40000000) & 0x7FFFFFFF;
      debugPrint('Planification alarme fin ID $endNotifId ("${b.title}") pour $end');
      try {
        await _plugin.zonedSchedule(
          id: endNotifId,
          title: '${b.title} · Terminé',
          body: 'Le créneau "${b.title}" est maintenant terminé (${fmtMin(b.endMin)}).',
          scheduledDate: end,
          notificationDetails: const NotificationDetails(android: _androidDetails),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('Erreur planif alarme fin: $e');
      }
    }
  }
}
