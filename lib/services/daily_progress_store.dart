import 'package:shared_preferences/shared_preferences.dart';

class DailyProgressStore {
  static const _lastCompletedDateKey = 'last_completed_timestamp';

  static Future<DateTime?> getLastCompletedTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(_lastCompletedDateKey);
    if (timestamp == null || timestamp.isEmpty) {
      return null;
    }
    try {
      return DateTime.parse(timestamp);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setLastCompletedTimestamp(DateTime dateTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCompletedDateKey, dateTime.toIso8601String());
  }

  static String formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
