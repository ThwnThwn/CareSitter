import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/app/push/firebase_push_notifications.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/core/api/push_device_repository.dart';
import 'package:caresitter_customer/core/push/push_message.dart';
import 'package:caresitter_customer/core/push/push_messaging_gateway.dart';
import 'package:caresitter_customer/core/push/push_receipt_store.dart';
import 'package:caresitter_customer/core/push/notification_deep_link_service.dart';
import 'package:caresitter_customer/features/home/presentation/controllers/notifications_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import '../../core/push/push_receipt_store_test.dart' show MemoryPushStorage;

class Auth extends AuthNotifier {
  int epoch = 0;
  @override
  int get sessionGeneration => epoch;
  @override
  Future<AuthState> build() async =>
      const AuthState(userId: 'owner', isAuthenticated: true);
  void switchOwner() {
    epoch++;
    state = const AsyncData(AuthState(userId: 'other', isAuthenticated: true));
  }
}

class Gateway extends NoopPushMessagingGateway {
  PushPermission status = PushPermission.authorized;
  int prompts = 0, deletes = 0;
  Completer<String?>? pending;
  bool tokenFails = false;
  PushMessage? initial;
  final refresh = StreamController<String>.broadcast(),
      messages = StreamController<PushMessage>.broadcast(),
      opens = StreamController<PushMessage>.broadcast();
  @override
  Future<bool> initialize() async => true;
  @override
  Future<PushPermission> permission({bool request = false}) async {
    if (request) prompts++;
    return status;
  }

  @override
  Future<String?> token() async {
    if (tokenFails) throw StateError('APNs unavailable');
    return pending == null ? 'token' : await pending!.future;
  }

  @override
  Stream<String> get tokenRefresh => refresh.stream;
  @override
  Stream<PushMessage> get foreground => messages.stream;
  @override
  Stream<PushMessage> get opened => opens.stream;
  @override
  Future<PushMessage?> initialMessage() async => initial;
  @override
  Future<void> deleteToken() async {
    deletes++;
  }
}

class Devices implements PushDeviceRepository {
  int registrations = 0, removed = 0;
  @override
  Future<String?> register(
      {required String platform,
      required String pushToken,
      required String deviceName}) async {
    registrations++;
    return 'device';
  }

  @override
  Future<void> unregister(String id) async {
    removed++;
  }
}

class Inbox extends NotificationsNotifier {
  static Completer<void>? pending;
  int refreshes = 0;
  @override
  Future<List<AppNotification>> build() async => [];
  @override
  Future<void> refresh() async {
    refreshes++;
    if (pending != null) await pending!.future;
  }
}

class Bookings extends BookingStore {
  @override
  List<BookingModel> build() => [];
  @override
  Future<void> requestSync() async {}
}

class Links implements NotificationDeepLinkService {
  final deliveries = <String?>[];
  @override
  Future<void> handle(Map<String, dynamic> data, {String? deliveryId}) async {
    deliveries.add(deliveryId);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FailingBindingStore extends PushReceiptStore {
  FailingBindingStore() : super(MemoryPushStorage());
  bool failBind = true, failClear = false;
  @override
  Future<void> bind(String owner) async {
    if (failBind) throw StateError('keychain unavailable');
    await super.bind(owner);
  }

  @override
  Future<void> clearBinding() async {
    if (failClear) throw StateError('keychain unavailable');
    await super.clearBinding();
  }
}

void main() {
  late ProviderContainer container;
  late Gateway gateway;
  late Devices devices;
  late Links links;
  late PushReceiptStore receipts;
  late Duration operationTimeout;
  Future<void> settle() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() async {
    gateway = Gateway();
    devices = Devices();
    links = Links();
    receipts = FailingBindingStore()..failBind = false;
    operationTimeout = const Duration(seconds: 10);
    Inbox.pending = null;
    container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(Auth.new),
      pushMessagingGatewayProvider.overrideWithValue(gateway),
      pushDeviceRepositoryProvider.overrideWithValue(devices),
      pushReceiptStoreProvider.overrideWithValue(receipts),
      notificationDeepLinkServiceProvider.overrideWithValue(links),
      notificationsProvider.overrideWith(Inbox.new),
      bookingStoreProvider.overrideWith(Bookings.new),
      pushNotificationServiceProvider.overrideWith((ref) {
        final service =
            PushNotificationService(ref, operationTimeout: operationTimeout);
        ref.onDispose(service.dispose);
        return service;
      })
    ]);
    await container.read(authStateProvider.future);
  });
  tearDown(() async {
    container.dispose();
    await gateway.refresh.close();
    await gateway.messages.close();
    await gateway.opens.close();
  });
  test(
      'denied permission does not prompt on background sync or register a token',
      () async {
    gateway.status = PushPermission.denied;
    await container
        .read(pushNotificationServiceProvider)
        .syncTokenForCurrentUser();
    await container
        .read(pushNotificationServiceProvider)
        .syncTokenForCurrentUser();
    expect(gateway.prompts, 0);
    expect(devices.registrations, 0);
  });
  test('late token fetch cannot register under a new session', () async {
    gateway.pending = Completer<String?>();
    final sync = container
        .read(pushNotificationServiceProvider)
        .syncTokenForCurrentUser();
    await settle();
    (container.read(authStateProvider.notifier) as Auth).switchOwner();
    gateway.pending!.complete('old-token');
    await sync;
    expect(devices.registrations, 0);
  });
  test(
      'token refresh belongs to current owner and logout deletes the SDK token',
      () async {
    final service = container.read(pushNotificationServiceProvider);
    await service.syncTokenForCurrentUser();
    expect(devices.registrations, 1);
    gateway.refresh.add('rotated');
    await settle();
    expect(devices.registrations, 2);
    await service.unregisterCurrentDevice();
    expect(devices.removed, 1);
    expect(gateway.deletes, 1);
  });
  test(
      'terminated and background open dispatch addressed delivery to the route port',
      () async {
    gateway.initial = PushMessage(
        id: 'initial',
        data: {'type': 'INFO', 'recipient_user_id': 'owner'},
        sentAt: DateTime.now());
    await container
        .read(pushNotificationServiceProvider)
        .syncTokenForCurrentUser();
    expect(links.deliveries, ['initial']);
    gateway.opens.add(PushMessage(
        id: 'background',
        data: {'type': 'INFO', 'recipient_user_id': 'owner'},
        sentAt: DateTime.now()));
    await settle();
    expect(links.deliveries, ['initial', 'background']);
    gateway.opens.add(PushMessage(
        id: 'foreign',
        data: {'recipient_user_id': 'other'},
        sentAt: DateTime.now()));
    await settle();
    expect(links.deliveries, hasLength(2));
  });
  test('foreground Console push is persisted once under its explicit owner',
      () async {
    await container
        .read(pushNotificationServiceProvider)
        .syncTokenForCurrentUser();
    final message = PushMessage(
        id: 'console',
        data: {
          'source': 'console_test',
          'recipient_user_id': 'owner',
          'type': 'INFO'
        },
        sentAt: DateTime.now());
    gateway.messages.add(message);
    await settle();
    gateway.opens.add(message);
    await settle();
    expect((await receipts.list('owner')).single.id, 'console:console');
  });
  test('cold-start notification still opens when APNs token fetch fails',
      () async {
    gateway.tokenFails = true;
    gateway.initial = PushMessage(
        id: 'cold',
        data: {'recipient_user_id': 'owner'},
        sentAt: DateTime.now());
    await container
        .read(pushNotificationServiceProvider)
        .syncTokenForCurrentUser();
    expect(links.deliveries, ['cold']);
    expect(devices.registrations, 0);
  });
  test('stalled token fetch is bounded and cannot block logout indefinitely',
      () async {
    gateway.pending = Completer<String?>();
    operationTimeout = const Duration(milliseconds: 20);
    final service = container.read(pushNotificationServiceProvider);
    final sync = service.syncTokenForCurrentUser();
    await settle();
    final logout = service.unregisterCurrentDevice();
    await Future.wait([sync, logout]).timeout(const Duration(seconds: 1));
    gateway.pending!.complete('late-token');
    await settle();
    expect(gateway.deletes, 1);
    expect(devices.registrations, 0);
  });
  test('stalled inbox refresh cannot hold the logout queue', () async {
    operationTimeout = const Duration(milliseconds: 20);
    Inbox.pending = Completer<void>();
    final service = container.read(pushNotificationServiceProvider);
    final sync = service.syncTokenForCurrentUser();
    await settle();
    await Future.wait([sync, service.unregisterCurrentDevice()])
        .timeout(const Duration(seconds: 1));
    expect(gateway.deletes, 1);
    Inbox.pending!.complete();
  });
  test('stalled inbox cannot suppress a notification deep link', () async {
    operationTimeout = const Duration(milliseconds: 20);
    Inbox.pending = Completer<void>();
    gateway.initial = PushMessage(
        id: 'cold-slow-inbox',
        data: {'recipient_user_id': 'owner'},
        sentAt: DateTime.now());
    await container
        .read(pushNotificationServiceProvider)
        .syncTokenForCurrentUser();
    expect(links.deliveries, ['cold-slow-inbox']);
    Inbox.pending!.complete();
    await settle();
  });
  test(
      'failed keychain binding retries instead of remembering a successful token',
      () async {
    final failing = receipts as FailingBindingStore;
    failing.failBind = true;
    final service = container.read(pushNotificationServiceProvider);
    await service.syncTokenForCurrentUser();
    failing.failBind = false;
    await service.syncTokenForCurrentUser();
    expect(devices.registrations, 2);
    failing.failClear = true;
    await service.unregisterCurrentDevice();
    expect(devices.removed, 1);
    expect(gateway.deletes, 1);
  });
}
