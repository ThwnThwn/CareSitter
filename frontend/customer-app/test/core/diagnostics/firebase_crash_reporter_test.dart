import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/diagnostics/firebase_crash_reporter.dart';

class CrashSdk implements FirebaseCrashlytics {
  final ids = <String>[], collectionChanges = <bool>[];
  @override
  Future<void> setUserIdentifier(String identifier) async {
    ids.add(identifier);
  }

  @override
  Future<void> setCustomKey(String key, Object value) async {}
  @override
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {
    collectionChanges.add(enabled);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('native crash context never receives account IDs across login or logout',
      () async {
    final sdk = CrashSdk();
    final reporter = FirebaseCrashReporter(sdk);
    await reporter.identify('first-account');
    await reporter.identify('second-account');
    await reporter.identify(null);
    expect(sdk.ids, ['', '', '']);
    expect(sdk.collectionChanges, isEmpty);
  });
}
