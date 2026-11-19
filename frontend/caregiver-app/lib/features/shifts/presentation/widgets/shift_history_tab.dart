import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caregiver_app/core/widgets/page_controls.dart';
import '../controllers/shift_history_provider.dart';
import 'shift_list_content.dart';
import 'shift_read_state.dart';

class ShiftHistoryTab extends ConsumerStatefulWidget {
  const ShiftHistoryTab({super.key});

  @override
  ConsumerState<ShiftHistoryTab> createState() => _ShiftHistoryTabState();
}

class _ShiftHistoryTabState extends ConsumerState<ShiftHistoryTab> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final provider = shiftHistoryProvider(_page);
    final result = ref.watch(provider);
    final data =
        result.isReloading || result.hasError ? null : result.valueOrNull;
    if (data == null) {
      return Column(
        children: [
          Expanded(
              child: ShiftReadState(
            error: result.error,
            onRetry: () => ref.invalidate(provider),
          )),
          if (_page > 1)
            PageControls(
              page: _page,
              onPrevious: () => setState(() => _page--),
              onNext: null,
            ),
        ],
      );
    }
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(provider);
              // The provider exposes errors through the tab state.
              await ref
                  .read(provider.future)
                  .then<void>((_) {}, onError: (Object _) {});
            },
            child: ShiftListContent(
              filtered: data.items,
              emptyIcon: Icons.history_rounded,
              emptyTitle: 'Chưa có lịch sử',
              emptyMessage: 'Các ca đã hoàn thành sẽ được lưu lại ở đây.',
              storageKey: 'history-shifts-$_page',
            ),
          ),
        ),
        if (_page > 1 || data.hasMore)
          PageControls(
            page: _page,
            onPrevious: _page > 1 ? () => setState(() => _page--) : null,
            onNext: data.hasMore ? () => setState(() => _page++) : null,
          ),
      ],
    );
  }
}
