import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_client.dart';
import '../../../core/api/api_constants.dart';
import '../../../core/auth/auth_notifier.dart';
import '../data/family_contact_model.dart';

export '../data/family_contact_model.dart';

final familyContactsProvider =
    AsyncNotifierProvider<FamilyContactsNotifier, List<FamilyContactModel>>(
  FamilyContactsNotifier.new,
);

class FamilyContactsNotifier extends AsyncNotifier<List<FamilyContactModel>> {
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
    final response = await ref
        .read(dioClientProvider)
        .get<List<dynamic>>(ApiPaths.familyContacts);
    return (response.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(FamilyContactModel.fromJson)
        .toList();
  }

  Future<FamilyContactModel> add({
    required String fullName,
    required String phoneNumber,
  }) async {
    final response =
        await ref.read(dioClientProvider).post<Map<String, dynamic>>(
      ApiPaths.familyContacts,
      data: {'fullName': fullName, 'phoneNumber': phoneNumber},
    );
    final created = FamilyContactModel.fromJson(response.data ?? const {});
    final current = state.valueOrNull ?? const [];
    state = AsyncData([...current, created]
      ..sort((a, b) => a.fullName.compareTo(b.fullName)));
    return created;
  }
}
