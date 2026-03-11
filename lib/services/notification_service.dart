import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'meditation_session_store.dart';

class NotificationService {
  static const _scheduledStartKey = 'notifications_scheduled_for_start_date';
  static const _labScheduledForTenSessionsKey =
      'lab_reminder_scheduled_after_ten_sessions';
  static const _meditationReminderId = 1000;
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
    if (alreadyScheduledFor != null &&
        alreadyScheduledFor.isNotEmpty &&
        alreadyScheduledFor != startDateIso) {
      // Reset reminders if study start date changed.
      await _cancelMeditationReminders();
      await _plugin.cancel(2000);
      await prefs.remove(_labScheduledForTenSessionsKey);
    }

    final startDate = DateTime.parse(startDateIso);
    await ensureMeditationReminderUntilTenSessions(startDate);
    await prefs.setString(_scheduledStartKey, startDateIso);
  }

  static Future<void> ensureMeditationReminderUntilTenSessions(
    DateTime startDate,
  ) async {
    final sessions = await MeditationSessionStore.loadAll();
    if (sessions.length >= 10) {
      await _cancelMeditationReminders();
      return;
    }

    await _cancelMeditationReminders();

    final first = _nextMeditationReminderTime(startDate);
    await _plugin.zonedSchedule(
      _meditationReminderId,
      'Time to meditate',
      'Take a few minutes for today\'s session.',
      tz.TZDateTime.from(first, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'meditation_reminders',
          'Meditation reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> ensureLabReminderAfterTenSessions() async {
    final sessions = await MeditationSessionStore.loadAll();
    if (sessions.length < 10) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final alreadyScheduled =
        prefs.getBool(_labScheduledForTenSessionsKey) ?? false;
    if (alreadyScheduled) {
      return;
    }

    await _scheduleLabReminderForTomorrow();
    await prefs.setBool(_labScheduledForTenSessionsKey, true);
  }

  static Future<void> resetForReRegistration() async {
    await _cancelMeditationReminders();
    await _plugin.cancel(2000);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scheduledStartKey);
    await prefs.remove(_labScheduledForTenSessionsKey);
  }

  static DateTime _nextMeditationReminderTime(DateTime startDate) {
    final now = DateTime.now();
    final startLocal = DateTime(startDate.year, startDate.month, startDate.day);
    final baseDate = startLocal.isAfter(now)
        ? startLocal
        : DateTime(now.year, now.month, now.day);

    var reminderTime = DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      _meditationHour,
    );

    if (!reminderTime.isAfter(now)) {
      reminderTime = reminderTime.add(const Duration(days: 1));
    }
    return reminderTime;
  }

  static Future<void> _cancelMeditationReminders() async {
    await _plugin.cancel(_meditationReminderId);
    // Cleanup for previous implementation that used IDs 1000..1009.
    for (var id = 1000; id <= 1009; id++) {
      await _plugin.cancel(id);
    }
  }

  static Future<void> _scheduleLabReminderForTomorrow() async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final date = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
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
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
