import 'analytics_event.dart';

abstract interface class AnalyticsSink {
  Future<void> setUserId(String? userId);
  Future<void> log(AnalyticsEvent event, Map<String, Object> parameters);
}

class NoopAnalyticsSink implements AnalyticsSink {
  @override
  Future<void> setUserId(String? userId) async {}
  @override
  Future<void> log(
      AnalyticsEvent event, Map<String, Object> parameters) async {}
}
