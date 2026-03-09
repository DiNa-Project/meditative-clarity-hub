import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdStore {
  static const _prefsKey = 'device_uuid';

  static Future<String> getOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefsKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final newId = const Uuid().v4();
    await prefs.setString(_prefsKey, newId);
    return newId;
  }
}
