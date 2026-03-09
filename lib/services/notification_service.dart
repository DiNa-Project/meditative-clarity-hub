import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static const _scheduledStartKey = 'notifications_scheduled_for_start_date';
  static const _meditationHour = 20;
  static const _labHour = 10;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Pacific/Auckland'));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(settings);

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> ensureScheduled(String startDateIso) async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyScheduledFor = prefs.getString(_scheduledStartKey);
    if (alreadyScheduledFor == startDateIso) {
      return;
    }

    if (alreadyScheduledFor != null && alreadyScheduledFor.isNotEmpty) {
      await _plugin.cancelAll();
    }

    final startDate = DateTime.parse(startDateIso);
    await _scheduleMeditationRange(startDate);
    await _scheduleLabReminder(startDate);
    await prefs.setString(_scheduledStartKey, startDateIso);
  }

  static Future<void> _scheduleMeditationRange(DateTime startDate) async {
    for (var day = 0; day <= 9; day++) {
      final date = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      ).add(Duration(days: day));
      final localTime = DateTime(
        date.year,
        date.month,
        date.day,
        _meditationHour,
      );
      if (localTime.isBefore(DateTime.now())) {
        continue;
      }
      await _plugin.zonedSchedule(
        1000 + day,
        'Time to meditate',
        'Take a few minutes for today\'s session.',
        tz.TZDateTime.from(localTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'meditation_reminders',
            'Meditation reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  static Future<void> _scheduleLabReminder(DateTime startDate) async {
    final date = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    ).add(const Duration(days: 10));
    final localTime = DateTime(date.year, date.month, date.day, _labHour);
    if (localTime.isBefore(DateTime.now())) {
      return;
    }
    await _plugin.zonedSchedule(
      2000,
      'Lab visit reminder',
      'Please complete your lab experiment today.',
      tz.TZDateTime.from(localTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'lab_reminders',
          'Lab reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
