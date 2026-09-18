import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/features/wallet/data/models/wallet_model.dart';
import 'package:caresitter_customer/features/wallet/data/repositories/wallet_repository.dart';

export 'package:caresitter_customer/features/wallet/data/models/wallet_model.dart';

final customerWalletProvider =
    AsyncNotifierProvider<CustomerWalletStore, CustomerWallet>(
  CustomerWalletStore.new,
);

class CustomerWalletStore extends AsyncNotifier<CustomerWallet> {
  WalletRepository get _repository => ref.read(walletRepositoryProvider);

  @override
  Future<CustomerWallet> build() => _fetch();

  Future<CustomerWallet> _fetch() => _repository.getWallet();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}
