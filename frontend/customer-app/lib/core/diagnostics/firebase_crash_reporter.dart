import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'crash_reporter.dart';
import 'guarded_crash_reporter.dart';
import 'lab_demo_policy.dart';

class FirebaseCrashReporter implements CrashReporter {
  FirebaseCrashReporter(this._sdk);
  final FirebaseCrashlytics _sdk;
  @override
  bool get available => true;
  static Future<CrashReporter> initialize() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS) ||
        !Firebase.apps.any((app) => app.name == '[DEFAULT]')) {
      return NoopCrashReporter();
    }
    try {
      final sdk = FirebaseCrashlytics.instance;
      await sdk.setUserIdentifier('');
      await sdk.setCrashlyticsCollectionEnabled(
          kReleaseMode || LabDemoPolicy.enabled);
      if (LabDemoPolicy.enabled) {
        final previousCrash = await sdk.didCrashOnPreviousExecution();
        debugPrint('[Crashlytics] previous crash: $previousCrash; '
            'collection: ${sdk.isCrashlyticsCollectionEnabled}');
        await sdk.sendUnsentReports();
      }
      await sdk.setCustomKey('app_role', 'customer');
      await sdk.setCustomKey('screen', 'bootstrap');
      await sdk.setCustomKey('demo_run_id', '');
      final reporter = GuardedCrashReporter(FirebaseCrashReporter(sdk));
      await reporter.identify(null);
      return reporter;
    } catch (_) {
      return NoopCrashReporter();
    }
  }

  @override
  Future<void> identify(String? userId) async {
    // Native reports stay anonymous. A timed-out platform call cannot restore
    // a previous account ID after logout; Analytics owns account attribution.
    await _sdk.setUserIdentifier('');
    await _sdk.setCustomKey('demo_run_id', '');
  }

  @override
  Future<void> setScreen(String screen) => _sdk.setCustomKey('screen', screen);
  @override
  Future<void> record(Object error, StackTrace stack,
          {required bool fatal, required String source}) =>
      _sdk.recordError(StateError('unhandled_${error.runtimeType}'), stack,
          fatal: fatal, reason: source, printDetails: false);
  @override
  Future<void> nonfatalDemo(String runId) async {
    await _sdk.setCustomKey('demo_run_id', runId);
    try {
      await _sdk.recordError(
          StateError('lab3_nonfatal_demo'), StackTrace.current,
          reason: 'lab3_demo', fatal: false, printDetails: false);
    } finally {
      await _sdk.setCustomKey('demo_run_id', '');
    }
  }

  @override
  Future<void> crashDemo(String runId) async {
    await _sdk.setCustomKey('demo_run_id', runId);
    _sdk.crash();
  }
}
