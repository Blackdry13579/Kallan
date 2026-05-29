import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationScheduler {
  static const int _reminderId = 1;
  static const String _channelId = 'kalan_daily_reminder';
  static const String _channelName = 'Rappels de révision';

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (_) {},
    );

    // Demande la permission sur Android 13+
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    }

    _initialized = true;

    // Replanifie au démarrage si les notifications sont activées
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('notifications_enabled') ?? true) {
      final timeStr = prefs.getString('reminder_time') ?? '19:00';
      final parts = timeStr.split(':');
      await scheduleDaily(int.parse(parts[0]), int.parse(parts[1]));
    }
  }

  /// Planifie un rappel quotidien à [hour]:[minute] heure locale.
  static Future<void> scheduleDaily(int hour, int minute) async {
    if (!_initialized) await init();

    await _plugin.zonedSchedule(
      _reminderId,
      'Il est temps de réviser ! 📚',
      'Ouvre KALAN et fais tes flashcards du jour.',
      _nextOccurrence(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Rappel quotidien de révision KALAN',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint('[NotificationScheduler] Rappel programmé à $hour:${minute.toString().padLeft(2, '0')}');
  }

  /// Annule le rappel quotidien.
  static Future<void> cancel() async {
    await _plugin.cancel(_reminderId);
    debugPrint('[NotificationScheduler] Rappel annulé');
  }

  // Calcule la prochaine occurrence de [hour]:[minute] en heure locale,
  // convertie en TZDateTime UTC pour le plugin.
  static tz.TZDateTime _nextOccurrence(int hour, int minute) {
    final now = DateTime.now();
    var local = DateTime(now.year, now.month, now.day, hour, minute);
    if (!local.isAfter(now)) {
      local = local.add(const Duration(days: 1));
    }
    return tz.TZDateTime.from(local.toUtc(), tz.UTC);
  }
}
