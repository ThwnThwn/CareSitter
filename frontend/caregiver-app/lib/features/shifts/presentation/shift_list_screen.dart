import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
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
        body: TabBarView(
          children: [
            _buildUpcomingShifts(context, ref, shifts),
            _buildPendingShifts(context, ref, shifts),
            _buildHistoryShifts(context, ref, shifts),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingShifts(BuildContext context, WidgetRef ref, List<MockBooking> shifts) {
    final upcomingList = shifts.where((s) => s.status == 'confirmed' || s.status == 'in_progress').toList();

    if (upcomingList.isEmpty) {
      return const Center(
        child: Text('Không có ca làm việc sắp tới', style: TextStyle(color: AppColors.textSecondary)),
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

  Widget _buildPendingShifts(BuildContext context, WidgetRef ref, List<MockBooking> shifts) {
    final pendingList = shifts.where((s) => s.status == 'pending').toList();

    if (pendingList.isEmpty) {
      return const Center(
        child: Text('Không có ca đang chờ phản hồi', style: TextStyle(color: AppColors.textSecondary)),
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

  Widget _buildHistoryShifts(BuildContext context, WidgetRef ref, List<MockBooking> shifts) {
    final historyList = shifts.where((s) => s.status == 'completed').toList();

    if (historyList.isEmpty) {
      return const Center(
        child: Text('Chưa có lịch sử ca làm việc', style: TextStyle(color: AppColors.textSecondary)),
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
    Color statusColor;
    String statusText;

    switch (status) {
      case 'in_progress':
        statusColor = const Color(0xFF27AE60);
        statusText = 'Đang diễn ra';
        break;
      case 'confirmed':
      case 'upcoming':
        statusColor = AppColors.primary;
        statusText = 'Sắp tới';
        break;
      case 'pending':
        statusColor = const Color(0xFFF2994A);
        statusText = 'Chờ phản hồi';
        break;
      case 'completed':
        statusColor = AppColors.textSecondary;
        statusText = 'Hoàn thành';
        break;
      default:
        statusColor = AppColors.textHint;
        statusText = status;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
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
                        style: const TextStyle(
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            serviceName,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      time,
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.calendar_month_rounded,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      date,
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600),
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
                            ref.read(shiftsProvider.notifier).declineBooking(id);
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
