import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/core/auth/auth_notifier.dart';
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

  @override
  Future<List<FamilyContactModel>> build() async {
    ref.listen(authStateProvider, (_, next) {
      if (next.value?.isAuthenticated ?? false) {
        ref.invalidateSelf();
      } else {
        state = const AsyncData([]);
      }
    });
    return _load();
  }

  Future<List<FamilyContactModel>> _load() async {
    if (!(ref.read(authStateProvider).value?.isAuthenticated ?? false)) {
      return const [];
    }
    return _repository.getContacts();
  }

  Future<FamilyContactModel> add({
    required String fullName,
    required String phoneNumber,
  }) async {
    final created = await _repository.createContact(
      fullName: fullName,
      phoneNumber: phoneNumber,
    );
    final current = state.valueOrNull ?? const [];
    state = AsyncData([...current, created]
      ..sort((a, b) => a.fullName.compareTo(b.fullName)));
    return created;
  }
}
