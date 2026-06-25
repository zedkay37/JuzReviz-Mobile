import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Notifications locales : rappel quotidien de révision à l'heure choisie.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const int _reminderId = 1001;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Rappels de révision',
      channelDescription: 'Rappel quotidien pour la révision du Coran',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Fallback : UTC (déjà la valeur par défaut).
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios));
    _ready = true;
  }

  /// Demande les autorisations (Android 13+, iOS). Renvoie `true` si accordé.
  Future<bool> requestPermissions() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
    return granted ?? true;
  }

  /// Planifie un rappel quotidien à `hh:mm` (répétition par l'heure).
  Future<void> scheduleDaily(int hour, int minute) async {
    await init();
    await _plugin.cancel(_reminderId);
    final now = tz.TZDateTime.now(tz.local);
    var when =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      _reminderId,
      'JuzReviz',
      'C’est l’heure de ta révision 🌙',
      when,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelReminder() async {
    await init();
    await _plugin.cancel(_reminderId);
  }

  /// Applique l'état des réglages (`HH:MM`, activé/désactivé).
  Future<void> apply({required bool enabled, required String hhmm}) async {
    if (!enabled) {
      await cancelReminder();
      return;
    }
    final granted = await requestPermissions();
    if (!granted) return;
    final parts = hhmm.split(':');
    final h = int.tryParse(parts.first) ?? 8;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    await scheduleDaily(h, m);
  }
}
