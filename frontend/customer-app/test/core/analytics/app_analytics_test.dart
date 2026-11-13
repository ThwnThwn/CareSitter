import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/analytics/app_analytics.dart';
import 'package:caresitter_customer/core/analytics/analytics_sink.dart';

class Sink implements AnalyticsSink {
  final calls = <String>[];
  bool failIdentity = false;
  @override
  Future<void> setUserId(String? id) async {
    if (failIdentity) throw StateError('sdk unavailable');
    calls.add('user:$id');
  }

  @override
  Future<void> log(
          AnalyticsEvent event, Map<String, Object> parameters) async =>
      calls.add(event.eventName);
}

void main() {
  test('identity precedes login and logout precedes clearing identity',
      () async {
    final sink = Sink();
    final analytics = AppAnalytics(sink);
    analytics.identify('opaque-owner');
    analytics.log(
        AnalyticsEvent.login, {'method': 'google', 'app_role': 'customer'});
    analytics
        .log(AnalyticsEvent.logout, {'method': 'user', 'app_role': 'customer'});
    analytics.identify(null);
    await analytics.drained;
    expect(sink.calls, ['user:opaque-owner', 'login', 'logout', 'user:null']);
  });
  test('same completed operation emits once and all seven schemas exist',
      () async {
    final sink = Sink();
    final analytics = AppAnalytics(sink);
    analytics.logOnce(
        AnalyticsEvent.fileUploadCompleted, 'operation', {'file_type': 'pdf'});
    analytics.logOnce(
        AnalyticsEvent.fileUploadCompleted, 'operation', {'file_type': 'pdf'});
    await analytics.drained;
    expect(sink.calls, ['file_upload_completed']);
    expect(AnalyticsEvent.values.length, 7);
  });
  test('unknown or sensitive parameter names are rejected', () {
    final analytics = AppAnalytics(Sink());
    expect(
        () => analytics
            .log(AnalyticsEvent.login, {'email': 'someone@example.com'}),
        throwsArgumentError);
  });
  test('identity failure suppresses later events under the old owner',
      () async {
    final sink = Sink()..failIdentity = true;
    final analytics = AppAnalytics(sink);
    analytics.identify('owner');
    analytics.log(AnalyticsEvent.login);
    await analytics.drained;
    expect(sink.calls, isEmpty);
  });
}
