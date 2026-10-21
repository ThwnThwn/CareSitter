import 'dart:async';

import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/features/beneficiary/data/repositories/beneficiary_repository.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_load_state_controller.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps loading until the beneficiary request completes', () async {
    final repository = _Repository();
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_Auth.new),
      beneficiaryRepositoryProvider.overrideWithValue(repository),
      addressStoreProvider.overrideWith(_Addresses.new),
    ]);
    addTearDown(container.dispose);

    container.read(beneficiaryStoreProvider);
    await container.read(authStateProvider.future);
    await _flush();
    expect(container.read(beneficiaryLoadStateProvider).isLoading, isTrue);

    repository.pending.complete([
      {
        'Id': '11111111-1111-1111-1111-111111111111',
        'FullName': 'Trần Thị Loan',
        'RelationshipToCustomer': 'Mẹ',
      }
    ]);
    await _flush();

    expect(container.read(beneficiaryLoadStateProvider).hasValue, isTrue);
    expect(
        container.read(beneficiaryStoreProvider).single.name, 'Trần Thị Loan');
  });
}

Future<void> _flush() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(userId: 'owner', isAuthenticated: true);
}

class _Addresses extends AddressStore {
  @override
  Future<List<AddressModel>> build() async => const [];
}

class _Repository implements BeneficiaryRepository {
  final pending = Completer<List<Map<String, dynamic>>>();

  @override
  Future<List<Map<String, dynamic>>> getBeneficiaries() => pending.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
