import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../pages/questionnaire_page.dart';
import '../services/daily_progress_store.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
    required this.deviceId,
    required this.profile,
  });

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
  StreamSubscription<PlayerState>? _playerStateSubscription;
  DateTime? _meditationStartTime;
  DateTime? _nextAvailableTime;
  Timer? _lockTimer;
  Timer? _countdownTimer;
  bool _hasNavigatedToQuestionnaire = false;
  static const bool _enableDailyLock = true;
  static const Duration _cooldownDuration = Duration(hours: 1);

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _previewPlayer = AudioPlayer();
    unawaited(_loadDailyCompletion());
    _completionSubscription = _player.onPlayerComplete.listen((_) {
      if (!mounted || _hasNavigatedToQuestionnaire) {
        return;
      }
      setState(() {
        _isMeditating = false;
      });
      _openQuestionnaire(
        musicStartTime: _meditationStartTime ?? DateTime.now(),
        replace: true,
      );
    });

    _playerStateSubscription = _player.onPlayerStateChanged.listen((state) {
      if (state != PlayerState.completed) {
        return;
      }
      if (!mounted || _hasNavigatedToQuestionnaire) {
        return;
      }
      setState(() {
        _isMeditating = false;
      });
      _openQuestionnaire(
        musicStartTime: _meditationStartTime ?? DateTime.now(),
        replace: true,
      );
    });

    _previewCompletionSubscription = _previewPlayer.onPlayerComplete.listen((_) {
      if (!mounted) {
        return;
      }
      _openQuestionnaire(musicStartTime: DateTime.now(), isPractice: true);
    });
  }

  void _openQuestionnaire({
    required DateTime musicStartTime,
    bool isPractice = false,
    bool replace = false,
  }) {
    if (!mounted) {
      return;
    }

    if (!isPractice) {
      _hasNavigatedToQuestionnaire = true;
    }

    final route = MaterialPageRoute(
      builder: (_) => QuestionnairePage(
        deviceId: widget.deviceId,
        profile: widget.profile,
        musicStartTime: musicStartTime,
        isPractice: isPractice,
      ),
    );

    if (replace) {
      Navigator.of(context).pushReplacement(route);
      return;
    }

    Navigator.of(context).push(route);
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
      setState(() {});
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
    _playerStateSubscription?.cancel();
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
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleMeditation() async {
    if (_isMeditating || _hasCompletedMeditation) {
      return;
    }

    setState(() {
      _isMeditating = true;
      _hasNavigatedToQuestionnaire = false;
      _meditationStartTime = DateTime.now();
    });

    try {
      await _player.play(AssetSource('meditation.mp3'));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isMeditating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to play meditation audio.')),
      );
    }
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
                      onPressed: _hasCompletedMeditation ? null : _toggleMeditation,
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
