import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/notify/notifications.dart';
import 'platforms/macos/macos_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // The macOS build is a separate, read-only shell (see macos_app.dart) —
  // routed here before any mobile-only plugin (home_widget, local
  // notifications) is touched, so this branch never runs on iOS/Android.
  if (Platform.isMacOS) {
    runApp(const ProviderScope(child: MacosSpendlyApp()));
    return;
  }
  // Notification init/scheduling is deferred to app.dart's post-first-frame
  // hook (Sprint 7) — both do platform-channel round trips (timezone lookup,
  // plugin registration, a possible OS permission prompt) that otherwise block
  // cold start past the 2s NFR budget.
  final notifications = NotificationService();
  runApp(
    ProviderScope(
      overrides: [notificationServiceProvider.overrideWithValue(notifications)],
      child: const SpendlyApp(),
    ),
  );
}
