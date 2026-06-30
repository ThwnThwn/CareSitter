import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/mock/mock_data.dart';
import '../../application/booking_store.dart';

class BookingListScreen extends ConsumerStatefulWidget {
  const BookingListScreen({super.key});

  @override
  ConsumerState<BookingListScreen> createState() => _BookingListScreenState();
}

class _BookingListScreenState extends ConsumerState<BookingListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'Lịch hẹn của tôi',
          style: TextStyle(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Sắp tới'),
            Tab(text: 'Đang diễn ra'),
            Tab(text: 'Hoàn thành'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => context.push('/booking/new'),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookingList(['confirmed', 'pending']),
          _buildBookingList(['in_progress', 'checkout_requested', 'disputed']),
          _buildBookingList(['completed', 'cancelled']),
        ],
      ),
    );
  }

  Widget _buildBookingList(List<String> statuses) {
    final bookings = ref.watch(bookingStoreProvider);
    final filtered =
        bookings.where((b) => statuses.contains(b.status)).toList();

    if (filtered.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildBookingCard(filtered[index]),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(Icons.calendar_today_outlined,
                color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chưa có lịch hẹn',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nhấn + để đặt lịch chăm sóc mới',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/booking/new'),
            icon: const Icon(Icons.add),
            label: const Text('Đặt lịch ngay'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(MockBooking booking) {
    final statusConfig = _getStatusConfig(booking.status);

    return GestureDetector(
      onTap: () => context.push('/bookings/${booking.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    booking.caregiverAvatar,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.caregiverName,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
                      Text(
                        booking.serviceName,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusConfig['bg'] as Color,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusConfig['label'] as String,
                        style: TextStyle(
                            color: statusConfig['color'] as Color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_formatCurrency(booking.totalPrice)}đ',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _infoRow(Icons.person_outline, 'Người được chăm sóc',
                      booking.beneficiaryName),
                  const SizedBox(height: 6),
                  _infoRow(Icons.calendar_today_outlined, 'Ngày', booking.date),
                  const SizedBox(height: 6),
                  _infoRow(Icons.access_time_outlined, 'Giờ',
                      '${booking.time} (${booking.duration})'),
                  const SizedBox(height: 6),
                  _infoRow(
                      Icons.location_on_outlined, 'Địa chỉ', booking.address),
                ],
              ),
            ),
            if (booking.status == 'completed' && !booking.isReviewed) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.push('/bookings/${booking.id}/review'),
                  icon: const Icon(Icons.star_outline, size: 16),
                  label: const Text('Đánh giá dịch vụ'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ] else if (booking.status == 'completed' && booking.isReviewed) ...[
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 16, color: AppColors.success),
                  SizedBox(width: 6),
                  Text('Đã đánh giá',
                      style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text('$label: ',
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'in_progress':
        return {
          'label': '🟢 Đang diễn ra',
          'color': const Color(0xFF27AE60),
          'bg': const Color(0xFFE8F8F0)
        };
      case 'checkout_requested':
        return {
          'label': '🟣 Chờ bạn hoàn tất',
          'color': const Color(0xFF8E44AD),
          'bg': const Color(0xFFF4ECF7)
        };
      case 'disputed':
        return {
          'label': '⚠️ Đang xử lý',
          'color': const Color(0xFFE67E22),
          'bg': const Color(0xFFFEF5E7)
        };
      case 'confirmed':
        return {
          'label': '🔵 Đã xác nhận',
          'color': const Color(0xFF2980B9),
          'bg': const Color(0xFFEBF5FB)
        };
      case 'pending':
        return {
          'label': '🟡 Chờ xác nhận',
          'color': const Color(0xFFF39C12),
          'bg': const Color(0xFFFEF9E7)
        };
      case 'completed':
        return {
          'label': '✅ Hoàn thành',
          'color': AppColors.textSecondary,
          'bg': AppColors.surface
        };
      case 'cancelled':
        return {
          'label': '❌ Đã huỷ',
          'color': const Color(0xFFE74C3C),
          'bg': const Color(0xFFFDEDEC)
        };
      default:
        return {
          'label': status,
          'color': AppColors.textSecondary,
          'bg': AppColors.surface
        };
    }
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    return amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }
}
