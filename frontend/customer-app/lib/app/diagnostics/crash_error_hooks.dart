import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:caresitter_customer/core/diagnostics/crash_reporter.dart';

/// Installs once at bootstrap, preserves any handlers installed before us.
void installCrashErrorHooks(CrashReporter reporter) {
  if (!reporter.available) return;
  final previousFlutter = FlutterError.onError;
  final previousPlatform = PlatformDispatcher.instance.onError;
  void report(Object error, StackTrace stack, String source) {
    unawaited(reporter
        .record(error, stack, fatal: true, source: source)
        .catchError((Object _) {
      debugPrint('[Crashlytics] delivery unavailable');
    }));
  }

  FlutterError.onError = (details) {
    if (previousFlutter != null) {
      previousFlutter(details);
    } else {
      FlutterError.presentError(details);
    }
    report(details.exception, details.stack ?? StackTrace.current,
        'flutter_framework');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    report(error, stack, 'platform_dispatcher');
    return previousPlatform?.call(error, stack) ?? false;
  };
}
