import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'analytics_event.dart';
import 'analytics_sink.dart';

class FirebaseAnalyticsSink implements AnalyticsSink {
  FirebaseAnalytics? get _sdk =>
      Firebase.apps.any((app) => app.name == '[DEFAULT]')
          ? FirebaseAnalytics.instance
          : null;

  @override
  Future<void> setUserId(String? userId) async => _sdk?.setUserId(id: userId);

  @override
  Future<void> log(AnalyticsEvent event, Map<String, Object> parameters) async {
    final sdk = _sdk;
    if (sdk == null) return;
    if (event == AnalyticsEvent.viewItem) {
      await sdk.logViewItem(items: [
        AnalyticsEventItem(
          itemId: parameters['item_id'] as String?,
          itemCategory: parameters['item_category'] as String?,
        )
      ]);
    } else {
      await sdk.logEvent(name: event.eventName, parameters: parameters);
    }
  }
}
