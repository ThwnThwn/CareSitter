import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caregiver_app/core/api/api_cancellation.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/error/app_exception.dart';
import '../../data/models/wallet_activity.dart';
import '../../data/repositories/earnings_repository.dart';

final walletActivityProvider = FutureProvider.autoDispose
    .family<WalletActivityPage, (WalletActivityKind, int)>((ref, query) {
  final session = ref.watch(authStateProvider.select((state) =>
      (state.valueOrNull?.userId, state.valueOrNull?.isAuthenticated)));
  if (session.$2 != true) {
    throw const AppApiException(
        message: 'Vui lòng đăng nhập lại.', statusCode: 401);
  }
  final token = ApiCancellation();
  ref.onDispose(token.cancel);
  return ref
      .watch(earningsRepositoryProvider)
      .loadActivity(query.$1, query.$2, token: token);
});
