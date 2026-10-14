import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_session_scope.dart';
import 'package:caresitter_customer/features/beneficiary/data/models/family_contact_model.dart';
import 'package:caresitter_customer/features/beneficiary/data/repositories/family_contact_repository.dart';

export 'package:caresitter_customer/features/beneficiary/data/models/family_contact_model.dart';

final familyContactsProvider =
    AsyncNotifierProvider<FamilyContactsNotifier, List<FamilyContactModel>>(
  FamilyContactsNotifier.new,
);

class FamilyContactsNotifier extends AsyncNotifier<List<FamilyContactModel>> {
  FamilyContactRepository get _repository =>
      ref.read(familyContactRepositoryProvider);
  late AuthSessionScope _session;

  @override
  Future<List<FamilyContactModel>> build() async {
    _session = AuthSessionScope.watch(ref);
    final session = _session;
    ref.listen(authStateProvider, (_, next) {
      if (!session.isCurrent) {
        state = next.valueOrNull?.isAuthenticated == true
            ? const AsyncLoading()
            : const AsyncData([]);
      }
    });
    if (!_session.isCurrent) return const [];
    return _repository.getContacts(cancellation: _session.cancellation);
  }

  Future<FamilyContactModel> add({
    required String fullName,
    required String phoneNumber,
  }) async {
    final session = _session..requireCurrent();
    final created = await _repository.createContact(
      fullName: fullName,
      phoneNumber: phoneNumber,
      cancellation: session.cancellation,
    );
    session.requireCurrent();
    final current = state.valueOrNull ?? const [];
    state = AsyncData(
        [...current, created]..sort((a, b) => a.fullName.compareTo(b.fullName)));
    return created;
  }
}
