import 'dart:async';

import 'package:caresitter_customer/features/nutrition/data/sources/nutrition_disclaimer_ack_store.dart';
import 'package:caresitter_customer/features/nutrition/presentation/controllers/nutrition_disclaimer_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Store extends NutritionDisclaimerAckStore {
  bool acknowledged = false;
  bool readError = false;
  bool writeError = false;
  int writes = 0;
  Completer<void>? pendingWrite;

  @override
  Future<bool> isAcknowledged(String userId, String version) async {
    if (readError) throw StateError('read unavailable');
    return acknowledged;
  }

  @override
  Future<void> acknowledge(String userId, String version) async {
    writes++;
    if (pendingWrite != null) await pendingWrite!.future;
    if (writeError) throw StateError('write unavailable');
  }
}

void main() {
  const key = (userId: 'user-a', version: 'v1');
  late _Store store;
  late ProviderContainer container;

  setUp(() {
    store = _Store();
    container = ProviderContainer(overrides: [
      nutritionDisclaimerAckStoreProvider.overrideWithValue(store),
    ]);
  });
  tearDown(() => container.dispose());

  Future<void> load(NutritionDisclaimerKey key) async {
    final ready = Completer<void>();
    container.listen(nutritionDisclaimerControllerProvider(key), (_, next) {
      if (next != NutritionDisclaimerState.loading && !ready.isCompleted) {
        ready.complete();
      }
    }, fireImmediately: true);
    await ready.future;
    await container.pump();
  }

  test('unacknowledged starts loading and then needs acknowledgment', () async {
    expect(container.read(nutritionDisclaimerControllerProvider(key)),
        NutritionDisclaimerState.loading);
    await load(key);
    expect(container.read(nutritionDisclaimerControllerProvider(key)),
        NutritionDisclaimerState.needsAck);
    expect(
        await container
            .read(nutritionDisclaimerControllerProvider(key).notifier)
            .acknowledge(),
        NutritionDisclaimerAckResult.saved);
    expect(container.read(nutritionDisclaimerControllerProvider(key)),
        NutritionDisclaimerState.acknowledged);
  });

  test('existing acknowledgment is loaded', () async {
    store.acknowledged = true;
    await load(key);
    expect(container.read(nutritionDisclaimerControllerProvider(key)),
        NutritionDisclaimerState.acknowledged);
  });

  for (final userId in <String?>[null, '', '  ']) {
    test('user $userId is unavailable and cannot write', () async {
      final unavailable = (userId: userId, version: 'v1');
      await load(unavailable);
      expect(container.read(nutritionDisclaimerControllerProvider(unavailable)),
          NutritionDisclaimerState.unavailable);
      expect(
          await container
              .read(nutritionDisclaimerControllerProvider(unavailable).notifier)
              .acknowledge(),
          NutritionDisclaimerAckResult.stale);
      expect(store.writes, 0);
    });
  }

  test('read failure still needs acknowledgment', () async {
    store.readError = true;
    await load(key);
    expect(container.read(nutritionDisclaimerControllerProvider(key)),
        NutritionDisclaimerState.needsAck);
  });

  test('write failure acknowledges only in memory', () async {
    store.writeError = true;
    await load(key);
    expect(
        await container
            .read(nutritionDisclaimerControllerProvider(key).notifier)
            .acknowledge(),
        NutritionDisclaimerAckResult.savedInMemoryOnly);
    expect(container.read(nutritionDisclaimerControllerProvider(key)),
        NutritionDisclaimerState.acknowledged);
  });

  test('old key is stale after the subscription switches keys', () async {
    final old = container.listen(
        nutritionDisclaimerControllerProvider(key), (_, __) {});
    await container.pump();
    final controller =
        container.read(nutritionDisclaimerControllerProvider(key).notifier);
    old.close();
    await load((userId: 'user-b', version: 'v2'));
    expect(await controller.acknowledge(), NutritionDisclaimerAckResult.stale);
    expect(store.writes, 0);
  });

  test('write completed after disposal reports stale', () async {
    final subscription = container.listen(
        nutritionDisclaimerControllerProvider(key), (_, __) {});
    await container.pump();
    store.pendingWrite = Completer<void>();
    final result = container
        .read(nutritionDisclaimerControllerProvider(key).notifier)
        .acknowledge();
    subscription.close();
    await container.pump();
    store.pendingWrite!.complete();
    expect(await result, NutritionDisclaimerAckResult.stale);
  });
}
