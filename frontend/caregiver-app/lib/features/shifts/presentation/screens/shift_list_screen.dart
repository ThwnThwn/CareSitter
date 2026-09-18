import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/widgets/app_widgets.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_card.dart';

class ShiftListScreen extends ConsumerWidget {
  const ShiftListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shifts = ref.watch(shiftsProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Ca làm việc'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Sắp tới'),
              Tab(text: 'Đang chờ'),
              Tab(text: 'Lịch sử'),
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: () => ref.read(shiftsProvider.notifier).refresh(),
          child: TabBarView(
            children: [
              _buildList(
                context,
                ref,
                shifts.where((shift) => const {
                      ShiftStatus.confirmed,
                      ShiftStatus.assigned,
                      ShiftStatus.caregiverEnRoute,
                      ShiftStatus.inProgress,
                    }.contains(shift.statusType)),
                emptyIcon: Icons.event_available_rounded,
                emptyTitle: 'Chưa có ca sắp tới',
                emptyMessage: 'Các ca bạn đã nhận sẽ xuất hiện ở đây.',
                storageKey: 'upcoming-shifts',
              ),
              _buildList(
                context,
                ref,
                shifts.where((shift) => const {
                      ShiftStatus.pending,
                      ShiftStatus.open,
                      ShiftStatus.checkoutPendingReview,
                    }.contains(shift.statusType)),
                emptyIcon: Icons.hourglass_empty_rounded,
                emptyTitle: 'Không có ca đang chờ',
                emptyMessage:
                    'Lời mời nhận ca và ca chờ khách xác nhận hoàn tất sẽ hiển thị tại đây.',
                storageKey: 'pending-shifts',
              ),
              _buildList(
                context,
                ref,
                shifts.where(
                  (shift) => shift.statusType == ShiftStatus.completed,
                ),
                emptyIcon: Icons.history_rounded,
                emptyTitle: 'Chưa có lịch sử',
                emptyMessage: 'Các ca đã hoàn thành sẽ được lưu lại ở đây.',
                storageKey: 'history-shifts',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    Iterable<ShiftModel> filtered, {
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptyMessage,
    required String storageKey,
  }) {
    final shifts = filtered.toList(growable: false);
    if (shifts.isEmpty) {
      return AppEmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        message: emptyMessage,
      );
    }

    return ListView.builder(
      key: PageStorageKey(storageKey),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: shifts.length,
      itemBuilder: (context, index) {
        final shift = shifts[index];
        final isInvitation = shift.statusType == ShiftStatus.pending ||
            shift.statusType == ShiftStatus.open;
        return ShiftCard(
          shift: shift,
          onTap: () => context.push(
            shift.statusType == ShiftStatus.inProgress
                ? '/shifts/${shift.id}/active'
                : '/shifts/${shift.id}',
          ),
          onDecline: isInvitation
              ? () => ref.read(shiftsProvider.notifier).declineBooking(shift.id)
              : null,
          onViewOffer:
              isInvitation ? () => context.push('/shifts/${shift.id}') : null,
        );
      },
    );
  }
}
