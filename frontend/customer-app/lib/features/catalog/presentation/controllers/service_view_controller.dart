import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/analytics/app_analytics.dart';
import 'service_controller.dart';

final serviceViewControllerProvider =
    AutoDisposeNotifierProvider.family<ServiceViewController, bool, String>(
        ServiceViewController.new);

class ServiceViewController extends AutoDisposeFamilyNotifier<bool, String> {
  @override
  bool build(String arg) {
    var active = true;
    ref.onDispose(() => active = false);
    void record() {
      if (!active || state) return;
      final items = ref.read(serviceStoreProvider).valueOrNull;
      if (items?.any((item) => item.id == arg) != true) return;
      state = true;
      ref.read(appAnalyticsProvider).log(AnalyticsEvent.viewItem,
          {'item_category': 'care_service', 'item_id': arg});
    }

    ref.listen(serviceStoreProvider, (_, __) => record());
    unawaited(Future.microtask(record));
    return false;
  }
}
