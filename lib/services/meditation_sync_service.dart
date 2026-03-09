import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../models/user_profile.dart';
import 'meditation_session_store.dart';

class MeditationSyncService {
  static const _endpoint =
      'https://script.google.com/macros/s/AKfycbxSAnc_OfBdT64hbIbRCLikn-fAmk-CF47QnG8xhsN_SJ05t5psjSx1AgxJvmCGnN_4/exec';

  static Future<void> syncPending({
    required String deviceId,
    required UserProfile profile,
    bool ignoreBackoff = false,
  }) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (!_hasInternet(connectivity)) {
      return;
    }

    final pending = ignoreBackoff
      ? (await MeditationSessionStore.loadAll())
          .where((session) => !session.synced)
          .toList()
      : await MeditationSessionStore.loadPendingDue();
    if (pending.isEmpty) {
      return;
    }

    final sessionsToSync = pending;

    List<Map<String, dynamic>> payloadData = [];
    final payloadFailedIds = <String>{};
    for (final session in sessionsToSync) {
      try {
        payloadData.add(session.toPayload());
      } catch (e) {
        print('ERROR: Failed to create payload for session ${session.id}: $e');
        payloadFailedIds.add(session.id);
        continue;
      }
    }

    if (payloadFailedIds.isNotEmpty) {
      await MeditationSessionStore.markSyncFailed(
        payloadFailedIds,
        error: 'payload-conversion-failed',
      );
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

    http.Response response;
    try {
      response = await _postJsonWithAppsScriptRedirectHandling(
        uri: Uri.parse(_endpoint),
        body: jsonEncode(payload),
      );
    } catch (e) {
      await MeditationSessionStore.markSyncFailed(
        sessionsToSync.map((session) => session.id).toSet(),
        error: 'network-error: $e',
      );
      return;
    }

    print('SYNC_DEBUG status=${response.statusCode} body=${response.body}');

    final successStatus =
        response.statusCode >= 200 && response.statusCode < 400;
    Map<String, dynamic>? decodedBody;
    try {
      decodedBody = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      decodedBody = null;
    }

    final successBody = decodedBody?['status'] == 'success';

    if (successStatus && successBody) {
      await MeditationSessionStore.markSynced(
        sessionsToSync.map((session) => session.id).toSet(),
      );
    } else {
      final bodyStatus = decodedBody?['status'];
      await MeditationSessionStore.markSyncFailed(
        sessionsToSync.map((session) => session.id).toSet(),
        error: 'http-${response.statusCode}-status-${bodyStatus ?? 'invalid-body'}',
      );
    }
  }

  static bool _hasInternet(dynamic connectivityResult) {
    if (connectivityResult is ConnectivityResult) {
      return connectivityResult != ConnectivityResult.none;
    }
    if (connectivityResult is List<ConnectivityResult>) {
      return connectivityResult.any((value) => value != ConnectivityResult.none);
    }
    return false;
  }

  static Future<http.Response> _postJsonWithAppsScriptRedirectHandling({
    required Uri uri,
    required String body,
  }) async {
    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: body,
    );

    if (!_isRedirect(response.statusCode)) {
      return response;
    }

    final location = response.headers['location'];
    if (location == null || location.isEmpty) {
      return response;
    }

    final redirectUri = uri.resolve(location);
    print(
      'SYNC_DEBUG redirect status=${response.statusCode} location=$redirectUri',
    );

    // Google Apps Script often returns 302 after successful POST.
    // The redirect target returns the final JSON result via GET.
    return http.get(redirectUri);
  }

  static bool _isRedirect(int statusCode) {
    return statusCode == 301 ||
        statusCode == 302 ||
        statusCode == 303 ||
        statusCode == 307 ||
        statusCode == 308;
  }
}
