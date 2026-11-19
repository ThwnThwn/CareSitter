import 'package:caregiver_app/core/api/api_cancellation.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/auth/auth_state.dart';
import 'package:caregiver_app/core/error/app_exception.dart';
import 'package:caregiver_app/features/earnings/data/models/wallet_activity.dart';
import 'package:caregiver_app/features/earnings/data/repositories/earnings_repository.dart';
import 'package:caregiver_app/features/earnings/presentation/widgets/wallet_activity_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('withdrawal history retries and displays the current API status',
      (tester) async {
    final repository = _Wallet();
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_Auth.new),
      earningsRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: WalletActivityHistory())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Thu nhập ca chăm sóc'), findsOneWidget);

    await tester.tap(find.text('Yêu cầu rút tiền'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa tải được lịch sử. Thử lại'), findsOneWidget);
    await tester.tap(find.text('Chưa tải được lịch sử. Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Yêu cầu rút tiền · Test Bank'), findsOneWidget);
    expect(find.textContaining('Chờ duyệt'), findsOneWidget);

    repository.status = 'PAID';
    await tester.tap(find.byTooltip('Làm mới lịch sử'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Đã chuyển tiền'), findsOneWidget);
    expect(find.textContaining('Chờ duyệt'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
      userId: 'caregiver', isAuthenticated: true, roles: ['CAREGIVER']);
}

class _Wallet implements EarningsRepository {
  var _failPayoutOnce = true;
  var status = 'PENDING';

  @override
  Future<WalletActivityPage> loadActivity(WalletActivityKind kind, int page,
      {ApiCancellation? token}) async {
    final payout = kind == WalletActivityKind.payouts;
    if (payout && _failPayoutOnce) {
      _failPayoutOnce = false;
      throw const AppApiException(message: 'Mất kết nối');
    }
    return (
      items: [
        WalletActivity(
          kind: payout ? 'PAYOUT_REQUEST' : 'CAREGIVER_EARNING',
          amount: 120000,
          status: payout ? status : 'POSTED',
          date: DateTime(2026, 11, 19),
          isCredit: !payout,
          bankName: payout ? 'Test Bank' : null,
        )
      ],
      hasMore: false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
