import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/booking_store.dart';

import '../../../../core/presentation/widgets/fade_slide_staggered.dart';

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
    final topPadding = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Flat header theo Stitch ──
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              top: topPadding + 16,
              left: 20,
              right: 16,
              bottom: 0,
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Quản lý Lịch hẹn',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/notifications'),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.background,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_outlined,
                          color: AppColors.textSecondary,
                          size: 22,
                        ),
                      ),
                      const Positioned(
                        right: 6,
                        top: 6,
                        child: CircleAvatar(
                          radius: 4,
                          backgroundColor: Color(0xFFE74C3C),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Tabs ──
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textHint,
              labelStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              unselectedLabelStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
              tabs: const [
                Tab(text: 'Sắp tới'),
                Tab(text: 'Hoàn tất'),
                Tab(text: 'Đã hủy'),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8F2EC)),
          // ── Content ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBookingList([
                  'draft',
                  'pending',
                  'pending_payment',
                  'confirmed',
                  'caregiver_accepted',
                  'caregiver_en_route',
                  'in_progress',
                  'checkout_pending_review',
                  'crisis',
                ]),
                _buildBookingList(['completed']),
                _buildBookingList(['cancelled', 'disputed', 'refunded']),
              ],
            ),
          ),
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
      itemBuilder: (context, index) => FadeSlideStaggered(
        index: index,
        child: _buildBookingCard(filtered[index]),
      ),
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

  Widget _buildBookingCard(BookingModel booking) {
    final statusConfig = _getStatusConfig(booking.status);
    final borderColor = statusConfig['color'] as Color;

    return GestureDetector(
      onTap: () => context.push('/bookings/${booking.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: AppShadows.card,
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Row 1: Status pill + Price ──
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (statusConfig['bg'] as Color),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusConfig['label'] as String,
                          style: TextStyle(
                              color: borderColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatCurrencyFull(booking.totalPrice),
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Row 2: Date / Time / Address ──
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 5),
                      Text(booking.date,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time_outlined,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 5),
                      Text('${booking.time} (${booking.duration})',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          booking.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFE8F2EC)),
                  const SizedBox(height: 10),

                  // ── Row 3: Caregiver ──
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primaryContainer,
                        child: Text(
                          booking.caregiverAvatar ?? booking.caregiverInitials,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    booking.caregiverName ?? 'Người chăm sóc',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.verified_rounded,
                                    color: AppColors.primary, size: 12),
                              ],
                            ),
                            Text(
                              booking.serviceName ?? 'Dịch vụ chăm sóc',
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      // Action buttons
                      if (booking.status == 'confirmed' ||
                          booking.status == 'pending') ...[
                        _ActionIconButton(
                          icon: Icons.call_outlined,
                          onTap: () {},
                        ),
                        const SizedBox(width: 6),
                        _ActionIconButton(
                          icon: Icons.chat_bubble_outline_rounded,
                          onTap: () {},
                        ),
                      ],
                    ],
                  ),

                  // ── Cancel button ──
                  if (booking.status == 'confirmed' ||
                      booking.status == 'pending') ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () =>
                            context.push('/bookings/${booking.id}'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE74C3C),
                          side: const BorderSide(
                              color: Color(0xFFE74C3C), width: 1),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('Hủy lịch hẹn',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],

                  // ── Review button ──
                  if (booking.status == 'completed' && !booking.isReviewed) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            context.push('/bookings/${booking.id}/review'),
                        icon: const Icon(Icons.star_outline, size: 15),
                        label: const Text('Đánh giá dịch vụ'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          minimumSize: Size.zero,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'in_progress':
        return {
          'label': 'Sắp diễn ra',
          'color': AppColors.primary,
          'bg': AppColors.primaryContainer,
        };
      case 'checkout_pending_review':
        return {
          'label': 'Chờ xác nhận',
          'color': const Color(0xFF8E44AD),
          'bg': const Color(0xFFF4ECF7),
        };
      case 'disputed':
        return {
          'label': 'Đang xử lý',
          'color': const Color(0xFFE67E22),
          'bg': const Color(0xFFFEF5E7),
        };
      case 'confirmed':
      case 'caregiver_accepted':
        return {
          'label': 'Đã xác nhận',
          'color': const Color(0xFF2980B9),
          'bg': const Color(0xFFEBF5FB),
        };
      case 'pending':
        return {
          'label': 'Chờ xác nhận',
          'color': const Color(0xFFF39C12),
          'bg': const Color(0xFFFFF8E6),
        };
      case 'pending_payment':
        return {
          'label': 'Chờ thanh toán',
          'color': const Color(0xFFF39C12),
          'bg': const Color(0xFFFFF8E6),
        };
      case 'completed':
        return {
          'label': 'Hoàn thành',
          'color': AppColors.textSecondary,
          'bg': AppColors.surface,
        };
      case 'cancelled':
        return {
          'label': 'Đã huỷ',
          'color': const Color(0xFFE74C3C),
          'bg': const Color(0xFFFDEDEC),
        };
      default:
        return {
          'label': status,
          'color': AppColors.textSecondary,
          'bg': AppColors.surface,
        };
    }
  }

  String _formatCurrencyFull(double amount) {
    final s = amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return '$sđ';
  }
}

// ── Action icon button ─────────────────────────────────────────────────────
class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ActionIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
          color: Colors.white,
        ),
        child: Icon(icon, color: AppColors.primary, size: 18),
      ),
    );
  }
}
