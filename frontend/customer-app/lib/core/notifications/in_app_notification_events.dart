import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A foreground event from SignalR or FCM. Presentation is owned by the app shell
/// so feature stores never need a BuildContext or navigation dependency.
class InAppNotificationEvent {
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final String deduplicationKey;

  const InAppNotificationEvent({
    required this.title,
    required this.body,
    required this.data,
    required this.deduplicationKey,
  });
}

final inAppNotificationEventsProvider =
    Provider<InAppNotificationEvents>((ref) {
  final events = InAppNotificationEvents();
  ref.onDispose(events.dispose);
  return events;
});

class InAppNotificationEvents {
  final _controller = StreamController<InAppNotificationEvent>.broadcast();
  final _deliveredKeys = <String>{};
  final _deliveryOrder = Queue<String>();

  Stream<InAppNotificationEvent> get stream => _controller.stream;

  void publish(InAppNotificationEvent event) {
    if (event.deduplicationKey.isEmpty || !_remember(event.deduplicationKey)) {
      return;
    }
    _controller.add(event);
  }

  bool _remember(String key) {
    if (!_deliveredKeys.add(key)) return false;
    _deliveryOrder.addLast(key);
    if (_deliveryOrder.length > 128) {
      _deliveredKeys.remove(_deliveryOrder.removeFirst());
    }
    return true;
  }

  void dispose() => _controller.close();
}
