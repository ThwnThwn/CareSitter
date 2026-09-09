import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/mock/mock_data.dart';
import 'providers/shifts_provider.dart';
import '../../earnings/presentation/providers/earnings_provider.dart';

class ShiftDetailScreen extends ConsumerWidget {
  final String id;
  const ShiftDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shifts = ref.watch(shiftsProvider);

    // Find the booking
    MockBooking? booking;
    for (final b in shifts) {
      if (b.id == id) {
        booking = b;
        break;
      }
    }

    if (booking == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chi tiết ca'),
          leading: const AppBackButton(fallbackRoute: '/shifts'),
        ),
        body: const AppEmptyState(
          icon: Icons.search_off_rounded,
          title: 'Không tìm thấy ca làm việc',
          message: 'Ca này có thể đã bị huỷ hoặc không còn tồn tại.',
        ),
      );
    }

    // Find corresponding beneficiary
    final beneficiary = MockData.beneficiaries.firstWhere(
      (b) => b.name == booking!.beneficiaryName,
      orElse: () => MockData.beneficiaries.first,
    );

    final isPending = booking.status == 'pending' || booking.status == 'open';
    final isUpcoming =
        booking.status == 'confirmed' || booking.status == 'assigned';
    final isEnRoute = booking.status == 'caregiver_en_route';
    final isInProgress = booking.status == 'in_progress';
    final isCompleted = booking.status == 'completed';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Chi tiết ca (${booking.id})'),
        leading: const AppBackButton(fallbackRoute: '/shifts'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBeneficiaryCard(beneficiary),
            const SizedBox(height: 24),
            _buildTimeAndLocation(context, booking),
            const SizedBox(height: 24),
            _buildServiceDetails(beneficiary, booking),
            const SizedBox(height: 24),
            _buildChecklist(booking),
            const SizedBox(height: 32),
            if (isPending) _buildAcceptRejectButtons(context, ref, booking.id),
            if (isUpcoming) _buildEnRouteButton(context, ref, booking.id),
            if (isUpcoming) const SizedBox(height: 12),
            if (isEnRoute) _buildEnRouteBanner(context, ref, booking),
            if (isEnRoute) const SizedBox(height: 12),
            if (isInProgress) _buildGoToActiveShiftButton(context, booking.id),
            if (isCompleted) _buildCompletedShiftCard(booking),
          ],
        ),
      ),
    );
  }

  Widget _buildBeneficiaryCard(MockBeneficiary beneficiary) {
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.primaryContainer,
          child: Text(
            beneficiary.avatarInitial,
            style: const TextStyle(
                color: AppColors.primary,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                beneficiary.name,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                '${beneficiary.age} tuổi • Quan hệ: ${beneficiary.relation} • Mức độ: ${beneficiary.careLevel}',
                style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeAndLocation(BuildContext context, MockBooking booking) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thời gian & Địa điểm',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_month,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(booking.date,
                    style: const TextStyle(
                        fontSize: 15, color: AppColors.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.access_time, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text('${booking.time} (${booking.duration})',
                    style: const TextStyle(
                        fontSize: 15, color: AppColors.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  booking.address,
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.textPrimary),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.map, color: AppColors.primary),
                onPressed: () {
                  context.push(
                    '/shifts/${booking.id}/map',
                    extra: {
                      'beneficiaryName': booking.beneficiaryName,
                      'address': booking.address,
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceDetails(
      MockBeneficiary beneficiary, MockBooking booking) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lưu ý đặc biệt (${booking.serviceName})',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('Tình trạng sức khỏe:',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(beneficiary.condition,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          const Text('Ghi chú sinh hoạt:',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(beneficiary.notes,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildChecklist(MockBooking booking) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Checklist công việc',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          if (booking.tasks.isEmpty)
            const Text('Không có checklist công việc đặc biệt.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary))
          else
            ...booking.tasks.map((task) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        task.isCompleted
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                        color: task.isCompleted
                            ? AppColors.success
                            : AppColors.textHint,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildAcceptRejectButtons(
      BuildContext context, WidgetRef ref, String bookingId) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              try {
                await ref
                    .read(shiftsProvider.notifier)
                    .declineBooking(bookingId);
                if (context.mounted) {
                  context.pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Đã từ chối ca làm việc này.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Chưa từ chối được ca: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Từ chối'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () async {
              try {
                await ref
                    .read(shiftsProvider.notifier)
                    .acceptBooking(bookingId);
                if (context.mounted) {
                  context.pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          '✅ Đã nhận ca thành công! Ca làm việc nằm trong Tab Sắp tới.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi nhận ca: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Nhận ca'),
          ),
        ),
      ],
    );
  }

  Widget _buildEnRouteButton(
      BuildContext context, WidgetRef ref, String bookingId) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          ref.read(shiftsProvider.notifier).startEnRoute(bookingId);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '🚗 Bắt đầu di chuyển! Khách hàng có thể theo dõi vị trí của bạn.'),
              backgroundColor: Color(0xFFE67E22),
            ),
          );
        },
        icon: const Icon(Icons.directions_car_rounded, color: Colors.white),
        label: const Text(
          'Bắt đầu di chuyển đến nhà khách',
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: const Color(0xFFE67E22),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildEnRouteBanner(
      BuildContext context, WidgetRef ref, MockBooking booking) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3E0), Color(0xFFFFF8F0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFE67E22).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.navigation_rounded,
                  color: Color(0xFFE67E22), size: 20),
              SizedBox(width: 8),
              Text(
                'Đang trên đường đến',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE67E22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Khách hàng đang theo dõi vị trí của bạn trực tiếp.\nHãy check-in khi đến nơi (trong bán kính 50m).',
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ref.read(shiftsProvider.notifier).checkIn(booking.id);
                context.pushReplacement('/shifts/${booking.id}/active');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        '📍 Đã GPS check-in! Bắt đầu thực hiện ca chăm sóc.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              icon: const Icon(Icons.my_location_rounded, size: 18),
              label: const Text('GPS Check-in tại địa điểm',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoToActiveShiftButton(BuildContext context, String bookingId) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          context.pushReplacement('/shifts/$bookingId/active');
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: AppColors.success,
        ),
        child: const Text('Vào ca đang diễn ra',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      ),
    );
  }

  Widget _buildCompletedShiftCard(MockBooking booking) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.success),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 24),
              SizedBox(width: 8),
              Text(
                'Ca làm việc đã hoàn thành',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Thu nhập của bạn:',
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
              Text(
                '+ ${formatCurrency(booking.caregiverEarning)} ₫',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
