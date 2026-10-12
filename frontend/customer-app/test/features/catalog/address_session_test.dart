import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'package:caresitter_customer/features/catalog/data/repositories/address_repository.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';
import '../../support/session_test_auth.dart';

void main() {
  late ProviderContainer container;
  late _Addresses repository;
  late SessionTestAuth auth;
  setUp(() async {
    container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(SessionTestAuth.new),
      addressRepositoryProvider.overrideWith((ref) => repository = _Addresses(ref)),
      profileStoreProvider.overrideWith(
          (ref) => throw StateError('Old operation must not refresh profile')),
    ]);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    auth = container.read(authStateProvider.notifier) as SessionTestAuth;
    container.listen(addressStoreProvider, (_, __) {});
    await container.read(addressStoreProvider.future);
  });

  for (final nextUser in ['second', 'first']) {
    test('late create cannot modify a new login ($nextUser)', () async {
      final pending =
          container.read(addressStoreProvider.notifier).addAddress(placeId: 'place');
      final rejected = expectLater(pending, throwsStateError);
      auth.switchTo(nextUser);
      await flushSessionWork();
      await container.read(addressStoreProvider.future);
      repository.created
          .complete(const AddressModel(id: 'old-new', fullAddress: 'Old address'));
      await rejected;
      expect(repository.cancellation!.isCancelled, isTrue);
      expect(container.read(addressStoreProvider).requireValue.map((a) => a.id),
          [nextUser]);
    });
  }

  test('late deletion cannot remove an address in a new login', () async {
    final pending =
        container.read(addressStoreProvider.notifier).deleteAddress('second');
    final rejected = expectLater(pending, throwsStateError);
    auth.switchTo('second');
    await flushSessionWork();
    repository.mutation.complete();
    await rejected;
    expect(container.read(addressStoreProvider).requireValue.single.id, 'second');
  });

  test('late default-address response cannot refresh the next profile', () async {
    final pending =
        container.read(addressStoreProvider.notifier).setDefaultAddress('first');
    final rejected = expectLater(pending, throwsStateError);
    auth.switchTo('second');
    await flushSessionWork();
    repository.mutation.complete();
    await rejected;
    expect(container.read(addressStoreProvider).requireValue.single.id, 'second');
  });

  test('signed out mutations never reach the repository', () async {
    auth.switchTo(null);
    await flushSessionWork();
    await container.read(addressStoreProvider.future);
    await expectLater(
        container.read(addressStoreProvider.notifier).addAddress(placeId: 'place'),
        throwsStateError);
    expect(repository.cancellation, isNull);
    expect(container.read(addressStoreProvider).requireValue, isEmpty);
  });

  test('creation in the current login updates its cache', () async {
    final pending =
        container.read(addressStoreProvider.notifier).addAddress(placeId: 'place');
    repository.created
        .complete(const AddressModel(id: 'new', fullAddress: 'New address'));
    await pending;
    expect(container.read(addressStoreProvider).requireValue.map((a) => a.id),
        ['new', 'first']);
  });
}

class _Addresses implements AddressRepository {
  _Addresses(this.ref);
  final Ref ref;
  final created = Completer<AddressModel>();
  final mutation = Completer<void>();
  ApiCancellation? cancellation;
  @override
  Future<List<AddressModel>> getAddresses({ApiCancellation? cancellation}) async => [
        AddressModel(
            id: ref.read(authStateProvider).valueOrNull!.userId!,
            fullAddress: 'Address')
      ];
  @override
  Future<AddressModel> createAddress(
      {required String placeId,
      String? sessionToken,
      String? label,
      String? note,
      ApiCancellation? cancellation}) {
    this.cancellation = cancellation;
    return created.future;
  }

  @override
  Future<void> deleteAddress(String id, {ApiCancellation? cancellation}) =>
      mutation.future;
  @override
  Future<void> setDefaultAddress(String id, {ApiCancellation? cancellation}) =>
      mutation.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
