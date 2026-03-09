import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../models/user_profile.dart';
import 'meditation_session_store.dart';

class MeditationSyncService {
  static const _endpoint =
      'https://script.google.com/macros/s/AKfycbyDvZk-2OKAzlcdf-dIPmW3yk1kORdgRDTIB2ble8AdV1ndG58Clyb-S1yg3-lTn3ZqQA/exec';

  static Future<void> syncPending({
    required String deviceId,
    required UserProfile profile,
  }) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      return;
    }

    final sessions = await MeditationSessionStore.loadAll();
    final pending = sessions.where((session) => !session.synced).toList();
    if (pending.isEmpty) {
      return;
    }

    final start = _dateOnly(DateTime.parse(profile.startDate));
    final end = start.add(const Duration(days: 9));
    final inRange = pending.where((session) {
      final sessionDate = _dateOnly(DateTime.parse(session.musicStartTime));
      return !sessionDate.isBefore(start) && !sessionDate.isAfter(end);
    }).toList();

    if (inRange.isEmpty) {
      return;
    }

    List<Map<String, dynamic>> payloadData = [];
    for (final session in inRange) {
      try {
        payloadData.add(session.toPayload());
      } catch (e) {
        print('ERROR: Failed to create payload for session ${session.id}: $e');
        // Skip this session on error.
        continue;
      }
    }

    if (payloadData.isEmpty) {
      print('ERROR: No sessions could be converted to payload');
      return;
    }

    final payload = {
      'data': payloadData,
    };

    for (final item in payloadData) {
      print(
        'PAYLOAD_DEBUG session=${item['session_id']} user=${item['username']} '
        'answers=${item['answers_csv']}',
      );
    }

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    print('SYNC_DEBUG status=${response.statusCode} body=${response.body}');

    final successStatus =
        response.statusCode >= 200 && response.statusCode < 400;
    var successBody = false;
    if (!successStatus) {
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        successBody = decoded['status'] == 'success';
      } catch (_) {
        successBody = false;
      }
    }

    if (successStatus || successBody) {
      await MeditationSessionStore.markSynced(
        inRange.map((session) => session.id).toSet(),
      );
    }
  }

  static DateTime _dateOnly(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }
}
