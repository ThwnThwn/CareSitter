import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/shift_status_style.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/mock/mock_data.dart';
import 'providers/shifts_provider.dart';

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
              _buildUpcomingShifts(context, ref, shifts),
              _buildPendingShifts(context, ref, shifts),
              _buildHistoryShifts(context, ref, shifts),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingShifts(
      BuildContext context, WidgetRef ref, List<MockBooking> shifts) {
    final upcomingList = shifts
        .where((s) =>
            s.status == 'confirmed' ||
            s.status == 'assigned' ||
            s.status == 'caregiver_en_route' ||
            s.status == 'in_progress')
        .toList();

    if (upcomingList.isEmpty) {
      return const AppEmptyState(
        icon: Icons.event_available_rounded,
        title: 'Chưa có ca sắp tới',
        message: 'Các ca bạn đã nhận sẽ xuất hiện ở đây.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: upcomingList.length,
      itemBuilder: (context, index) {
        final item = upcomingList[index];
        return _buildShiftItem(
          context: context,
          ref: ref,
          id: item.id,
          beneficiaryName: item.beneficiaryName,
          serviceName: item.serviceName,
          date: item.date,
          time: item.time,
          status: item.status,
        );
      },
    );
  }

  Widget _buildPendingShifts(
      BuildContext context, WidgetRef ref, List<MockBooking> shifts) {
    final pendingList = shifts
        .where((s) => s.status == 'pending' || s.status == 'open')
        .toList();

    if (pendingList.isEmpty) {
      return const AppEmptyState(
        icon: Icons.hourglass_empty_rounded,
        title: 'Không có lời mời nào',
        message: 'Khi có ca mới phù hợp, lời mời sẽ hiển thị tại đây.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pendingList.length,
      itemBuilder: (context, index) {
        final item = pendingList[index];
        return _buildShiftItem(
          context: context,
          ref: ref,
          id: item.id,
          beneficiaryName: item.beneficiaryName,
          serviceName: item.serviceName,
          date: item.date,
          time: item.time,
          status: item.status,
          isInvitation: true,
        );
      },
    );
  }

  Widget _buildHistoryShifts(
      BuildContext context, WidgetRef ref, List<MockBooking> shifts) {
    final historyList = shifts.where((s) => s.status == 'completed').toList();

    if (historyList.isEmpty) {
      return const AppEmptyState(
        icon: Icons.history_rounded,
        title: 'Chưa có lịch sử',
        message: 'Các ca đã hoàn thành sẽ được lưu lại ở đây.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: historyList.length,
      itemBuilder: (context, index) {
        final item = historyList[index];
        return _buildShiftItem(
          context: context,
          ref: ref,
          id: item.id,
          beneficiaryName: item.beneficiaryName,
          serviceName: item.serviceName,
          date: item.date,
          time: item.time,
          status: item.status,
        );
      },
    );
  }

  Widget _buildShiftItem({
    required BuildContext context,
    required WidgetRef ref,
    required String id,
    required String beneficiaryName,
    required String serviceName,
    required String date,
    required String time,
    required String status,
    bool isInvitation = false,
  }) {
    final style = ShiftStatusStyle.of(status);
    final statusColor = style.color;
    final isPending = status == 'pending' || status == 'open';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: isPending
                ? AppColors.statusPending.withValues(alpha: 0.3)
                : AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () {
            if (status == 'in_progress') {
              context.push('/shifts/$id/active');
            } else {
              context.push('/shifts/$id');
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primaryContainer,
                      child: Text(
                        beneficiaryName.substring(0, 1),
                        style: GoogleFonts.beVietnamPro(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            beneficiaryName,
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            serviceName,
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: style.backgroundColor,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        style.label,
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          time,
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_rounded,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          date,
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                if (isInvitation) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ref
                                .read(shiftsProvider.notifier)
                                .declineBooking(id);
                          },
                          child: const Text('Từ chối'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => context.push('/shifts/$id'),
                          child: const Text('Xem & Nhận ca'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
