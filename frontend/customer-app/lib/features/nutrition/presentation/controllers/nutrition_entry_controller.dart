import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import '../../data/repositories/nutrition_repository.dart';

final nutritionEntryProvider = FutureProvider.autoDispose<bool>((ref) async {
  final session = ref.watch(authStateProvider
      .select((s) => (s.valueOrNull?.userId, s.valueOrNull?.isAuthenticated)));
  if (session.$2 != true) return false;
  final token = ApiCancellation();
  ref.onDispose(token.cancel);
  try {
    return (await ref.read(nutritionRepositoryProvider).capabilities(token))
        .enabled;
  } catch (_) {
    return false;
  }
});
