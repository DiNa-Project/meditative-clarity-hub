import 'package:flutter/material.dart';

import 'app.dart';
import 'services/device_id_store.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  final deviceId = await DeviceIdStore.getOrCreate();
  runApp(MyApp(deviceId: deviceId));
}
