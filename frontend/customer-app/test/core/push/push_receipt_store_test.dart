import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/push/push_receipt_store.dart';
import 'package:caresitter_customer/core/push/push_receipt_storage.dart';
import 'package:caresitter_customer/core/push/push_message.dart';

class MemoryPushStorage implements PushReceiptStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);
}

class DelayedBindingStorage extends MemoryPushStorage {
  final started = Completer<void>(), finish = Completer<void>();
  @override
  Future<void> write(String key, String value) async {
    if (key == 'push_receipt_bound_owner') {
      started.complete();
      await finish.future;
    }
    await super.write(key, value);
  }
}

PushMessage push(String id,
        {String? owner = 'owner', String source = 'console_test'}) =>
    PushMessage(
        id: id,
        data: {
          'source': source,
          if (owner != null) 'recipient_user_id': owner,
          'type': 'INFO'
        },
        sentAt: DateTime.now().toUtc(),
        title: 'Synthetic',
        body: 'Test');
void main() {
  test('logout clears an already-started binding write after it completes',
      () async {
    final storage = DelayedBindingStorage();
    final store = PushReceiptStore(storage);
    final bind = store.bind('owner');
    await storage.started.future;
    final clear = store.clearBinding();
    storage.finish.complete();
    await Future.wait([bind, clear]);
    expect(await store.capture(push('late')), isFalse);
  });
  test('only explicitly addressed Console receipts enter the owner inbox',
      () async {
    final store = PushReceiptStore(MemoryPushStorage());
    await store.bind('owner');
    expect(await store.capture(push('unaddressed', owner: null)), isFalse);
    expect(await store.capture(push('other', owner: 'other')), isFalse);
    expect(await store.capture(push('business', source: 'server')), isFalse);
    expect(await store.capture(push('console')), isTrue);
    expect((await store.list('owner')).single.id, 'console:console');
    expect(await store.list('other'), isEmpty);
  });
  test('duplicate foreground/open delivery keeps read status and one receipt',
      () async {
    final store = PushReceiptStore(MemoryPushStorage());
    await store.bind('owner');
    await store.capture(push('same'));
    await store.markRead('owner', 'console:same');
    await store.capture(push('same'));
    final result = await store.list('owner');
    expect(result.length, 1);
    expect(result.single.isRead, isTrue);
  });
  test(
      'per-delivery storage preserves concurrent writes without a shared inbox array',
      () async {
    final store = PushReceiptStore(MemoryPushStorage());
    await store.bind('owner');
    await Future.wait(
        [for (var i = 0; i < 12; i++) store.capture(push('id-$i'))]);
    expect(await store.list('owner'), hasLength(12));
    await store.clearBinding();
    expect(await store.capture(push('late')), isFalse);
  });
}
