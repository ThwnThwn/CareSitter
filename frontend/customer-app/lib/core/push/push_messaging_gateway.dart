import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'push_message.dart';

final pushMessagingGatewayProvider =
    Provider<PushMessagingGateway>((_) => NoopPushMessagingGateway());

enum PushPermission { notDetermined, authorized, provisional, denied }

abstract interface class PushMessagingGateway {
  Future<bool> initialize();
  Future<PushPermission> permission({bool request = false});
  Future<String?> token();
  Future<void> deleteToken();
  Stream<String> get tokenRefresh;
  Stream<PushMessage> get foreground;
  Stream<PushMessage> get opened;
  Future<PushMessage?> initialMessage();
}

class NoopPushMessagingGateway implements PushMessagingGateway {
  @override
  Future<bool> initialize() async => false;
  @override
  Future<PushPermission> permission({bool request = false}) async =>
      PushPermission.denied;
  @override
  Future<String?> token() async => null;
  @override
  Future<void> deleteToken() async {}
  @override
  Stream<String> get tokenRefresh => const Stream.empty();
  @override
  Stream<PushMessage> get foreground => const Stream.empty();
  @override
  Stream<PushMessage> get opened => const Stream.empty();
  @override
  Future<PushMessage?> initialMessage() async => null;
}
