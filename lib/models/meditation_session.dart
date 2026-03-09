class MeditationSession {
  MeditationSession({
    required this.id,
    required this.deviceId,
    required this.userName,
    required this.startDate,
    required this.musicStartTime,
    required this.answers,
    required this.synced,
  });

  final String id;
  final String deviceId;
  final String userName;
  final String startDate;
  final String musicStartTime;
  final List<double> answers;
  final bool synced;

  MeditationSession copyWith({bool? synced}) {
    return MeditationSession(
      id: id,
      deviceId: deviceId,
      userName: userName,
      startDate: startDate,
      musicStartTime: musicStartTime,
      answers: answers,
      synced: synced ?? this.synced,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'user_name': userName,
      'start_date': startDate,
      'music_start_time': musicStartTime,
      'answers': answers,
      'synced': synced,
    };
  }

  Map<String, dynamic> toPayload() {
    // Defensive check: ensure we have enough answers.
    if (answers.length < 6) {
      print(
        'ERROR: toPayload() called with insufficient answers! length=${answers.length}',
      );
      throw StateError(
        'Invalid answers count: expected 6, got ${answers.length}',
      );
    }

    return {
      'session_id': id,
      'uuid': deviceId,
      'username': userName,
      'start_date': startDate,
      'time_start_meditation': musicStartTime,
      'q1': _payloadAnswer(answers[0]),
      'q2': _payloadAnswer(answers[1]),
      'q3': _payloadAnswer(answers[2]),
      'q4': _payloadAnswer(answers[3]),
      'q5': _payloadAnswer(answers[4]),
      'q6': _payloadAnswer(answers[5]),
      'answers_csv': answers.take(6).map(_payloadAnswer).join(','),
      'payload_version': '2026-03-01-v2',
    };
  }

  String _payloadAnswer(double value) {
    if (!value.isFinite) {
      return '0';
    }
    return value.round().toString();
  }

  static MeditationSession fromJson(Map<String, dynamic> json) {
    return MeditationSession(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      userName: json['user_name'] as String,
      startDate: json['start_date'] as String,
      musicStartTime: json['music_start_time'] as String,
      answers: (json['answers'] as List<dynamic>)
          .map((value) => (value as num).toDouble())
          .toList(),
      synced: json['synced'] as bool? ?? false,
    );
  }
}
