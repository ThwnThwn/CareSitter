import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/widgets/page_controls.dart';
import '../../data/models/wallet_activity.dart';
import '../controllers/wallet_activity_provider.dart';
import 'earnings_transaction_list.dart';

class WalletActivityHistory extends ConsumerStatefulWidget {
  const WalletActivityHistory({super.key});

  @override
  ConsumerState<WalletActivityHistory> createState() =>
      _WalletActivityHistoryState();
}

class _WalletActivityHistoryState extends ConsumerState<WalletActivityHistory> {
  WalletActivityKind _kind = WalletActivityKind.transactions;
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final provider = walletActivityProvider((_kind, _page));
    final result = ref.watch(provider);
    final data =
        result.isReloading || result.hasError ? null : result.valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            _filter(WalletActivityKind.transactions, 'Giao dịch ví'),
            _filter(WalletActivityKind.payouts, 'Yêu cầu rút tiền'),
            IconButton(
              tooltip: 'Làm mới lịch sử',
              onPressed:
                  result.isLoading ? null : () => ref.invalidate(provider),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (result.isLoading) const LinearProgressIndicator(),
        if (result.hasError)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => ref.invalidate(provider),
              child: const Text('Chưa tải được lịch sử. Thử lại'),
            ),
          ),
        if (data != null) EarningsTransactionList(transactions: data.items),
        if (_page > 1 || data?.hasMore == true)
          PageControls(
            page: _page,
            onPrevious: _page > 1 ? () => setState(() => _page--) : null,
            onNext:
                data?.hasMore == true ? () => setState(() => _page++) : null,
          ),
      ],
    );
  }

  Widget _filter(WalletActivityKind kind, String label) => ChoiceChip(
        label: Text(label),
        selected: _kind == kind,
        onSelected: (_) {
          if (_kind == kind) return;
          setState(() {
            _kind = kind;
            _page = 1;
          });
        },
      );
}
