import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  final deviceId = await DeviceIdStore.getOrCreate();
  runApp(MyApp(deviceId: deviceId));
}

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
}

class UserProfile {
  const UserProfile({required this.name, required this.startDate});

  final String name;
  final String startDate;
}

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
        'Take a few minutes for today’s session.',
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
    return {
      'uuid': deviceId,
      'username': userName,
      'start_date': startDate,
      'time_start_meditation': musicStartTime,
      'q1': answers[0],
      'q2': answers[1],
      'q3': answers[2],
      'q4': answers[3],
      'q5': answers[4],
      'q6': answers[5],
    };
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

class MeditationSessionStore {
  static const _prefsKey = 'meditation_sessions';

  static Future<List<MeditationSession>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => MeditationSession.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveAll(List<MeditationSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      sessions.map((session) => session.toJson()).toList(),
    );
    await prefs.setString(_prefsKey, encoded);
  }

  static Future<void> add(MeditationSession session) async {
    final sessions = await loadAll();
    sessions.add(session);
    await saveAll(sessions);
  }

  static Future<void> markSynced(Set<String> ids) async {
    if (ids.isEmpty) {
      return;
    }
    final sessions = await loadAll();
    final updated = sessions
        .map(
          (session) => ids.contains(session.id)
              ? session.copyWith(synced: true)
              : session,
        )
        .toList();
    await saveAll(updated);
  }
}

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

    final payload = {
      'data': inRange.map((session) => session.toPayload()).toList(),
    };

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

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

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.deviceId});

  final String deviceId;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          onPrimary: Colors.white,
          secondary: Colors.black,
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black),
          bodyLarge: TextStyle(color: Colors.black),
          titleLarge: TextStyle(color: Colors.black),
        ),
      ),
      home: AppBootstrapper(deviceId: deviceId),
    );
  }
}

class AppBootstrapper extends StatefulWidget {
  const AppBootstrapper({super.key, required this.deviceId});

  final String deviceId;

  @override
  State<AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<AppBootstrapper> {
  Future<UserProfile?>? _profileFuture;
  bool _hasTriggeredSync = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = UserProfileStore.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final profile = snapshot.data;
        if (profile == null) {
          return OnboardingPage(
            deviceId: widget.deviceId,
            onCompleted: () {
              setState(() {
                _profileFuture = UserProfileStore.load();
              });
            },
          );
        }

        if (!_hasTriggeredSync) {
          _hasTriggeredSync = true;
          unawaited(
            MeditationSyncService.syncPending(
              deviceId: widget.deviceId,
              profile: profile,
            ),
          );
        }

        unawaited(NotificationService.ensureScheduled(profile.startDate));

        return MyHomePage(
          title: '',
          deviceId: widget.deviceId,
          profile: profile,
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
    required this.deviceId,
    required this.profile,
  });

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;
  final String deviceId;
  final UserProfile profile;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final AudioPlayer _player;
  late final AudioPlayer _previewPlayer;
  bool _isMeditating = false;
  bool _hasCompletedMeditation = false;
  StreamSubscription<void>? _completionSubscription;
  StreamSubscription<void>? _previewCompletionSubscription;
  DateTime? _meditationStartTime;
  DateTime? _nextAvailableTime;
  Timer? _lockTimer;
  Timer? _countdownTimer;
  static const bool _enableDailyLock = true;
  static const Duration _cooldownDuration = Duration(hours: 1);

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _previewPlayer = AudioPlayer();
    unawaited(_loadDailyCompletion());
    _completionSubscription = _player.onPlayerComplete.listen((_) {
      setState(() {
        _isMeditating = false;
        _hasCompletedMeditation = true;
      });

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => QuestionnairePage(
            deviceId: widget.deviceId,
            profile: widget.profile,
            musicStartTime: _meditationStartTime ?? DateTime.now(),
          ),
        ),
      );
    });
    _previewCompletionSubscription = _previewPlayer.onPlayerComplete.listen((
      _,
    ) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuestionnairePage(
            deviceId: widget.deviceId,
            profile: widget.profile,
            musicStartTime: DateTime.now(),
            isPractice: true,
          ),
        ),
      );
    });
  }

  Future<void> _loadDailyCompletion() async {
    if (!_enableDailyLock) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hasCompletedMeditation = false;
        _nextAvailableTime = null;
      });
      return;
    }

    final lastCompleted = await DailyProgressStore.getLastCompletedTimestamp();
    if (lastCompleted == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hasCompletedMeditation = false;
        _nextAvailableTime = null;
      });
      return;
    }

    final now = DateTime.now();
    final nextAvailable = lastCompleted.add(_cooldownDuration);
    final isLocked = now.isBefore(nextAvailable);

    if (!mounted) {
      return;
    }

    setState(() {
      _hasCompletedMeditation = isLocked;
      _nextAvailableTime = isLocked ? nextAvailable : null;
    });

    if (isLocked) {
      _startLockTimer(nextAvailable);
      _startCountdownTimer();
    }
  }

  void _startLockTimer(DateTime unlockTime) {
    _lockTimer?.cancel();
    final duration = unlockTime.difference(DateTime.now());
    if (duration.isNegative) {
      _unlockMeditation();
      return;
    }

    _lockTimer = Timer(duration, () {
      _unlockMeditation();
    });
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      if (_nextAvailableTime == null) {
        _countdownTimer?.cancel();
        return;
      }
      final remaining = _nextAvailableTime!.difference(DateTime.now());
      if (remaining.isNegative) {
        _unlockMeditation();
        _countdownTimer?.cancel();
        return;
      }
      setState(() {}); // Update UI with new countdown
    });
  }

  void _unlockMeditation() {
    if (!mounted) {
      return;
    }
    setState(() {
      _hasCompletedMeditation = false;
      _nextAvailableTime = null;
    });
  }

  @override
  void dispose() {
    _completionSubscription?.cancel();
    _previewCompletionSubscription?.cancel();
    _lockTimer?.cancel();
    _countdownTimer?.cancel();
    _player.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }

  String _getRemainingTime() {
    if (_nextAvailableTime == null) {
      return '';
    }
    final remaining = _nextAvailableTime!.difference(DateTime.now());
    if (remaining.isNegative) {
      return '';
    }
    final seconds = remaining.inSeconds;
    return '${seconds}s';
  }

  Future<void> _toggleMeditation() async {
    if (_isMeditating || _hasCompletedMeditation) {
      return;
    }

    setState(() {
      _isMeditating = true;
      _meditationStartTime = DateTime.now();
    });

    await _player.play(AssetSource('meditation.mp3'));
  }

  Future<void> _startPractice() async {
    if (_previewPlayer.state == PlayerState.playing) {
      return;
    }

    await _previewPlayer.play(AssetSource('meditation_try.mp3'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: _isMeditating ? 0.6 : 1,
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                        textStyle: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: _hasCompletedMeditation
                          ? null
                          : _toggleMeditation,
                      child: Text(
                        _isMeditating
                            ? 'Meditating'
                            : (_hasCompletedMeditation ? 'Done!' : 'Meditate'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                if (_hasCompletedMeditation && _nextAvailableTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      'Available in ${_getRemainingTime()}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 24,
            bottom: 24,
            child: SizedBox(
              width: 56,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                ),
                onPressed: _isMeditating ? null : _startPractice,
                child: const Icon(Icons.play_arrow),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QuestionnairePage extends StatefulWidget {
  const QuestionnairePage({
    super.key,
    required this.deviceId,
    required this.profile,
    required this.musicStartTime,
    this.isPractice = false,
  });

  final String deviceId;
  final UserProfile profile;
  final DateTime musicStartTime;
  final bool isPractice;

  @override
  State<QuestionnairePage> createState() => _QuestionnairePageState();
}

class _QuestionnairePageState extends State<QuestionnairePage> {
  final _controller = PageController();

  final List<QuestionItem> _questions = const [
    QuestionItem(
      title:
          'During practice, I attempted to return to my present-moment experience, whether unpleasant, pleasant, or neutral.',
      info:
          'I kept bringing my attention back to what I was experiencing right now.',
    ),
    QuestionItem(
      title:
          'During practice, I attempted to return to each experience, no matter how unpleasant, with a sense that “It’s OK to experience this”.',
      info:
          '⁠I tried to allow whatever was happening, and remind myself it’s okay.',
    ),
    QuestionItem(
      title:
          'During practice, I attempted to feel each experience as bare sensations in the body (tension in throat, movement in belly, etc).',
      info:
          '⁠I noticed the feelings in my body (like tightness, warmth, or movement) without overthinking them.',
    ),
    QuestionItem(
      title:
          'During practice, I was struggling against having certain experiences (e.g., unpleasant thoughts, emotions, and/or bodily sensations).',
      info: 'I was resisting or fighting against certain experiences.',
    ),
    QuestionItem(
      title:
          'During practice, I was actively avoiding or “pushing away” certain experiences.',
      info:
          'I tried to push away or avoid certain thoughts, feelings, or sensations.',
    ),
    QuestionItem(
      title:
          'During practice I was actively trying to fix or change certain experiences, in order to get to a “better place”.',
      info:
          '⁠I was trying to change how I felt to feel better, instead of just noticing it.',
    ),
  ];

  final List<QuestionAnswer> _answers = List.generate(
    6,
    (_) => const QuestionAnswer(),
  );

  int _pageIndex = 0;
  bool _submitting = false;

  bool _canContinue(int page) {
    final start = page * 3;
    final end = start + 3;
    for (var i = start; i < end; i++) {
      if (!_answers[i].changed) {
        return false;
      }
    }
    return true;
  }

  void _updateAnswer(int index, double value) {
    setState(() {
      _answers[index] = QuestionAnswer(value: value, changed: true);
    });
  }

  void _showInfo(String info) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('More info'),
        content: Text(info),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _finish() async {
    if (!_canContinue(1)) {
      return;
    }

    if (_submitting) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    if (widget.isPractice) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      return;
    }

    final answers = _answers.map((answer) => (answer.value ?? 0)).toList();
    final session = MeditationSession(
      id: const Uuid().v4(),
      deviceId: widget.deviceId,
      userName: widget.profile.name,
      startDate: widget.profile.startDate,
      musicStartTime: widget.musicStartTime.toIso8601String(),
      answers: answers,
      synced: false,
    );

    await MeditationSessionStore.add(session);
    await DailyProgressStore.setLastCompletedTimestamp(DateTime.now());

    if (!mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const ThankYouPage()));

    // Try to sync in background (fire and forget)
    // If no internet or fails: stays synced:false
    // AppBootstrapper will retry on next app launch
    unawaited(
      MeditationSyncService.syncPending(
        deviceId: widget.deviceId,
        profile: widget.profile,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (_pageIndex == 1)
                    IconButton(
                      onPressed: () {
                        _controller.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      },
                      icon: const Icon(Icons.arrow_back),
                    )
                  else
                    const SizedBox(width: 48),
                  const Expanded(
                    child: Text(
                      'Questionnaire',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _pageIndex = index;
                  });
                },
                itemCount: 2,
                itemBuilder: (context, page) {
                  final start = page * 3;
                  final pageItems = _questions.sublist(start, start + 3);
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final questionIndex = start + index;
                      final question = pageItems[index];
                      final answer = _answers[questionIndex];
                      final value = answer.value ?? 0;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  question.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _showInfo(question.info),
                                icon: const Icon(Icons.info_outline),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2,
                              tickMarkShape: const RoundSliderTickMarkShape(),
                              activeTickMarkColor: Colors.black,
                              inactiveTickMarkColor: Colors.black26,
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 18,
                              ),
                            ),
                            child: Slider(
                              value: value,
                              min: 0,
                              max: 100,
                              divisions: 10,
                              label: value.round().toString(),
                              onChanged: (newValue) =>
                                  _updateAnswer(questionIndex, newValue),
                            ),
                          ),
                          Text(
                            'Value: ${value.round()}${answer.changed ? '' : ' (adjust to continue)'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 24),
                    itemCount: pageItems.length,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_pageIndex == 0)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _canContinue(0)
                            ? () {
                                _controller.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                );
                              }
                            : null,
                        child: const Text('Next'),
                      ),
                    )
                  else
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _canContinue(1) && !_submitting
                            ? _finish
                            : null,
                        child: Text(_submitting ? 'Submitting...' : 'Submit'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuestionItem {
  const QuestionItem({required this.title, required this.info});

  final String title;
  final String info;
}

class QuestionAnswer {
  const QuestionAnswer({this.value, this.changed = false});

  final double? value;
  final bool changed;
}

class ThankYouPage extends StatefulWidget {
  const ThankYouPage({super.key});

  @override
  State<ThankYouPage> createState() => _ThankYouPageState();
}

class _ThankYouPageState extends State<ThankYouPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 2), () {
      SystemNavigator.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: const Text(
          'Thank you',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.deviceId,
    required this.onCompleted,
  });

  final String deviceId;
  final VoidCallback onCompleted;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  DateTime? _startDate;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a start date.')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    final profile = UserProfile(
      name: _nameController.text.trim(),
      startDate: _startDate!.toIso8601String(),
    );

    await UserProfileStore.save(profile);

    if (!mounted) {
      return;
    }

    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tell us a bit about you to get started.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'User name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'Please enter your name.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  _startDate == null
                      ? 'Select start date'
                      : 'Start date: ${_startDate!.toLocal().toString().split(' ').first}',
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: Text(_saving ? 'Saving...' : 'Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
