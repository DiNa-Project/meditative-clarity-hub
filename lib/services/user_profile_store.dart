import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

class UserProfileStore {
  static const _nameKey = 'user_name';
  static const _startDateKey = 'start_date';

  static Future<UserProfile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_nameKey);
    final startDate = prefs.getString(_startDateKey);
    if (name == null ||
        name.isEmpty ||
        startDate == null ||
        startDate.isEmpty) {
      return null;
    }
    return UserProfile(name: name, startDate: startDate);
  }

  static Future<void> save(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, profile.name);
    await prefs.setString(_startDateKey, profile.startDate);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_nameKey);
    await prefs.remove(_startDateKey);
  }
}
