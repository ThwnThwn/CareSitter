import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../booking/application/booking_store.dart';
import '../../../core/presentation/widgets/fade_slide_staggered.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingStoreProvider);

    final active = bookings
        .where((b) =>
            b.status == 'caregiver_en_route' ||
            b.status == 'in_progress' ||
            b.status == 'checkout_pending_review')
        .toList();

    final recent = bookings
        .where((b) =>
            b.status == 'completed' ||
            b.status == 'cancelled' ||
            b.status == 'confirmed' ||
            b.status == 'pending')
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F8F4),
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────
          SliverAppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            pinned: true,
            title: const Text(
              'Hoạt động',
              style: TextStyle(
                color: Color(0xFF1A2E2E),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () => context.go('/bookings'),
                icon: const Icon(Icons.history_rounded,
                    color: AppColors.primary, size: 18),
                label: const Text(
                  'Lịch sử',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Active shift section ─────────────────
                if (active.isNotEmpty)
                  FadeSlideStaggered(
                    index: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Đang diễn ra'),
                        const SizedBox(height: 10),
                        ...active.map((b) => _buildActiveCard(b, context)),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),

                // ── Recent section ───────────────────────
                if (recent.isNotEmpty)
                  FadeSlideStaggered(
                    index: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Gần đây'),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            children: List.generate(recent.length, (i) {
                              final b = recent[i];
                              final isLast = i == recent.length - 1;
                              return Column(
                                key: ValueKey('recent_${b.id}'),
                                children: [
                                  _buildRecentRow(b, context),
                                  if (!isLast)
                                    const Divider(
                                        height: 1,
                                        indent: 64,
                                        endIndent: 16,
                                        color: Color(0xFFECF5F5)),
                                ],
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Xem lịch sử link
                        Center(
                          child: TextButton.icon(
                            onPressed: () => context.push('/bookings'),
                            icon: const Text(
                              'Xem lịch sử',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            label: const Icon(Icons.arrow_forward_rounded,
                                color: AppColors.primary, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (active.isEmpty && recent.isEmpty)
                  FadeSlideStaggered(
                    index: 0,
                    child: _buildEmptyState(context),
                  ),

                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF1A2E2E),
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  // ── Active shift card (nổi bật, full card) ──────────────────
  Widget _buildActiveCard(BookingModel booking, BuildContext context) {
    return GestureDetector(
      key: ValueKey('active_${booking.id}'),
      onTap: () => context.push('/bookings/${booking.id}/tracking'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFF27AE60)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF27AE60).withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Pulsing dot indicator
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('🟢', style: TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ca đang diễn ra',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        booking.caregiverName ?? 'Người chăm sóc',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Cho: ${booking.beneficiaryName ?? "Người thân"}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.82),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chevron_right_rounded,
                      color: Colors.white, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Info row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    booking.time,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.home_repair_service_outlined,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      booking.serviceName ?? 'Dịch vụ chăm sóc',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.88),
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Theo dõi button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    context.push('/bookings/${booking.id}/tracking'),
                icon: const Icon(Icons.location_on_rounded, size: 18),
                label: const Text('Theo dõi ca chăm sóc'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recent booking row (Grab style) ─────────────────────────
  Widget _buildRecentRow(BookingModel booking, BuildContext context) {
    final statusConfig = _getStatusConfig(booking.status);
    final isCancelled = booking.status == 'cancelled';

    return GestureDetector(
      onTap: () => context.push('/bookings/${booking.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  booking.caregiverAvatar ?? booking.caregiverInitials,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isCancelled)
                    const Text(
                      'Đã huỷ',
                      style: TextStyle(
                        color: Color(0xFFE74C3C),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text(
                    booking.caregiverName ?? 'Người chăm sóc',
                    style: TextStyle(
                      color: isCancelled
                          ? const Color(0xFF5A7272)
                          : const Color(0xFF1A2E2E),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${booking.serviceName ?? "Dịch vụ chăm sóc"} • Cho: ${booking.beneficiaryName ?? "Người thân"}',
                    style:
                        const TextStyle(color: Color(0xFF5A7272), fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  Text(
                    '${booking.time} • ${booking.date}',
                    style:
                        const TextStyle(color: Color(0xFF9FBABA), fontSize: 11),
                  ),
                  if (!isCancelled && booking.status == 'completed') ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => context.push('/booking/new'),
                      child: const Text(
                        'Đặt lại →',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Price + status badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCurrency(booking.totalPrice),
                  style: const TextStyle(
                    color: Color(0xFF1A2E2E),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusConfig['bg'] as Color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusConfig['shortLabel'] as String,
                    style: TextStyle(
                      color: statusConfig['color'] as Color,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.track_changes_rounded,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'Chưa có ca chăm sóc nào',
              style: TextStyle(
                color: Color(0xFF5A7272),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Đặt lịch ngay để bắt đầu theo dõi\nca chăm sóc cho người thân.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9FBABA), fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/booking/new'),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Đặt lịch ngay'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
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
          'shortLabel': 'Đang diễn ra',
          'color': AppColors.primary,
          'bg': AppColors.primaryContainer,
        };
      case 'confirmed':
        return {
          'shortLabel': 'Đã xác nhận',
          'color': const Color(0xFFE67E22),
          'bg': const Color(0xFFFFF3DC),
        };
      case 'pending':
        return {
          'shortLabel': 'Chờ xác nhận',
          'color': const Color(0xFF7F8C8D),
          'bg': const Color(0xFFF4F6F6),
        };
      case 'completed':
        return {
          'shortLabel': 'Hoàn thành',
          'color': const Color(0xFF2980B9),
          'bg': const Color(0xFFEBF5FB),
        };
      case 'cancelled':
        return {
          'shortLabel': 'Đã huỷ',
          'color': const Color(0xFFE74C3C),
          'bg': const Color(0xFFFDEDEC),
        };
      default:
        return {
          'shortLabel': status,
          'color': AppColors.textSecondary,
          'bg': AppColors.surface,
        };
    }
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1).replaceAll('.', ',')}M ₫';
    }
    return '${amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        )} ₫';
  }
}
