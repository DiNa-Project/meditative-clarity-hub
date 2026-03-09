import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/meditation_sync_service.dart';
import '../services/notification_service.dart';
import '../services/user_profile_store.dart';
import 'home_page.dart';
import 'onboarding_page.dart';

class AppBootstrapper extends StatefulWidget {
  const AppBootstrapper({super.key, required this.deviceId});

  final String deviceId;

  @override
  State<AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<AppBootstrapper>
    with WidgetsBindingObserver {
  Future<UserProfile?>? _profileFuture;
  bool _hasTriggeredSync = false;
  bool _syncInProgress = false;
  UserProfile? _currentProfile;
  StreamSubscription<dynamic>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _profileFuture = UserProfileStore.load();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      result,
    ) {
      if (_hasInternet(result)) {
        unawaited(_triggerSyncIfPossible());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_triggerSyncIfPossible());
    }
  }

  Future<void> _triggerSyncIfPossible() async {
    final profile = _currentProfile;
    if (profile == null || _syncInProgress) {
      return;
    }

    _syncInProgress = true;
    try {
      await MeditationSyncService.syncPending(
        deviceId: widget.deviceId,
        profile: profile,
        ignoreBackoff: true,
      );
    } finally {
      _syncInProgress = false;
    }
  }

  bool _hasInternet(dynamic connectivityResult) {
    if (connectivityResult is ConnectivityResult) {
      return connectivityResult != ConnectivityResult.none;
    }
    if (connectivityResult is List<ConnectivityResult>) {
      return connectivityResult.any((value) => value != ConnectivityResult.none);
    }
    return false;
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

        _currentProfile = profile;

        if (!_hasTriggeredSync) {
          _hasTriggeredSync = true;
          unawaited(_triggerSyncIfPossible());
        }

        unawaited(NotificationService.ensureScheduled(profile.startDate));
        unawaited(NotificationService.ensureLabReminderAfterTenSessions());

        return MyHomePage(
          title: '',
          deviceId: widget.deviceId,
          profile: profile,
        );
      },
    );
  }
}
