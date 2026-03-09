import 'dart:async';

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
