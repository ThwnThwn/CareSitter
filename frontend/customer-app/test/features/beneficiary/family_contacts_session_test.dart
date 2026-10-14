import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/features/beneficiary/data/repositories/family_contact_repository.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/family_contact_controller.dart';
import '../../support/session_test_auth.dart';

void main() {
  for (final nextUser in ['second', 'first', null]) {
    test('late contact creation cannot update a new session ($nextUser)', () async {
      late _Contacts repository;
      final container = ProviderContainer(overrides: [
        authStateProvider.overrideWith(SessionTestAuth.new),
        familyContactRepositoryProvider
            .overrideWith((ref) => repository = _Contacts(ref)),
      ]);
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);
      container.listen(familyContactsProvider, (_, __) {});
      await container.read(familyContactsProvider.future);
      final pending = container
          .read(familyContactsProvider.notifier)
          .add(fullName: 'Liên hệ cũ', phoneNumber: '0901234567');
      final rejected = expectLater(pending, throwsStateError);
      (container.read(authStateProvider.notifier) as SessionTestAuth)
          .switchTo(nextUser);
      await flushSessionWork();
      await container.read(familyContactsProvider.future);
      repository.created.complete(const FamilyContactModel(
          id: 'old', fullName: 'Liên hệ cũ', phoneNumber: '0901234567'));
      await rejected;
      expect(repository.cancellation!.isCancelled, isTrue);
      expect(
          container
              .read(familyContactsProvider)
              .requireValue
              .map((contact) => contact.id),
          nextUser == null ? isEmpty : [nextUser]);
    });
  }
}

class _Contacts implements FamilyContactRepository {
  _Contacts(this.ref);
  final Ref ref;
  final created = Completer<FamilyContactModel>();
  ApiCancellation? cancellation;
  @override
  Future<List<FamilyContactModel>> getContacts(
          {ApiCancellation? cancellation}) async =>
      [
        FamilyContactModel(
            id: ref.read(authStateProvider).requireValue.userId!,
            fullName: 'Liên hệ hiện tại',
            phoneNumber: '0901234568'),
      ];
  @override
  Future<FamilyContactModel> createContact(
      {required String fullName,
      required String phoneNumber,
      ApiCancellation? cancellation}) {
    this.cancellation = cancellation;
    return created.future;
  }
}
