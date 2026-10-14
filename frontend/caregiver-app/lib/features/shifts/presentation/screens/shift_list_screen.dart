import 'package:caregiver_app/features/shifts/presentation/widgets/shift_list_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';

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
              ShiftListContent(
                filtered: shifts.where((shift) => const {
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
              ShiftListContent(
                filtered: shifts.where((shift) => const {
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
              ShiftListContent(
                filtered: shifts.where(
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
}
