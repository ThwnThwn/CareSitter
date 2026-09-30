import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/custom_animations.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';
import 'package:caresitter_customer/features/caregiver/presentation/controllers/caregiver_controller.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/service_controller.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:caresitter_customer/features/home/presentation/controllers/notifications_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _caregiverSearchController = TextEditingController();

  @override
  void dispose() {
    _caregiverSearchController.dispose();
    super.dispose();
  }

  void _openCaregiverSearch([String? value]) {
    final query = (value ?? _caregiverSearchController.text).trim();
    final location = Uri(
      path: '/caregivers',
      queryParameters: query.isEmpty ? null : {'q': query},
    ).toString();
    context.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(bookingStoreProvider);
    final profile = ref.watch(profileStoreProvider);
    final unreadCount = ref
            .watch(notificationsProvider)
            .valueOrNull
            ?.where((notification) => !notification.isRead)
            .length ??
        0;
    final topPadding = MediaQuery.of(context).padding.top;

    // Chỉ hiện booking thật từ store: ưu tiên ca đang diễn ra,
    // nếu không có thì lấy ca hợp lệ gần nhất trong tương lai.
    final featuredBooking = _selectFeaturedBooking(bookings, DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, profile, topPadding, unreadCount),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  _buildHeroBanner(context),
                  if (featuredBooking != null) ...[
                    const SizedBox(height: 12),
                    _buildLiveSessionCard(featuredBooking, context),
                  ],
                  const SizedBox(height: 20),
                  _buildPromotionsSection(context),
                  const SizedBox(height: 24),
                  _buildServicesSection(context),
                  const SizedBox(height: 24),
                  _buildRecentlyBookedSection(context, bookings),
                  const SizedBox(height: 24),
                  _buildUpcomingAppointmentsSection(context, bookings),
                  const SizedBox(height: 24),
                  _buildCaregiverSection(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  BookingModel? _selectFeaturedBooking(
    List<BookingModel> bookings,
    DateTime now,
  ) {
    final ongoing = bookings
        .where((booking) => booking.presentationStatusAt(now) == 'in_progress')
        .toList()
      ..sort((a, b) => b.scheduledStart.compareTo(a.scheduledStart));
    if (ongoing.isNotEmpty) return ongoing.first;

    const upcomingStatuses = {
      'confirmed',
      'caregiver_accepted',
      'caregiver_en_route',
    };
    final upcoming = bookings.where((booking) {
      final status = booking.presentationStatusAt(now);
      return upcomingStatuses.contains(status) &&
          booking.scheduledEnd.isAfter(now);
    }).toList()
      ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));

    return upcoming.isEmpty ? null : upcoming.first;
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, UserProfile profile,
      double topPadding, int unreadCount) {
    final avatarUrl = profile.avatarUrl?.trim() ?? '';
    ImageProvider? avatarImage;
    if (avatarUrl.startsWith('http')) {
      avatarImage =
          ResizeImage(CachedNetworkImageProvider(avatarUrl), width: 192);
    }
    final initials = profile.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .map((String p) => p[0].toUpperCase())
        .take(2)
        .join();

    // Greeting theo giờ
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Chào buổi sáng,'
        : hour < 18
            ? 'Chào buổi chiều,'
            : 'Chào buổi tối,';

    return Container(
      color: AppColors.background,
      padding: EdgeInsets.only(
        top: topPadding + 12,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          GestureDetector(
            onTap: () => context.push('/settings'),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primaryContainer,
              backgroundImage: avatarImage,
              child: avatarImage != null
                  ? null
                  : Text(
                      initials.isNotEmpty ? initials : 'U',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile.name.isNotEmpty ? profile.name : 'Bạn',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const WavingHand(),
                  ],
                ),
              ],
            ),
          ),

          // Search icon
          GestureDetector(
            onTap: () => context.push('/catalog'),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.search_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Bell icon
          GestureDetector(
            onTap: () => context.push('/notifications'),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE74C3C),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Live Session Card ───────────────────────────────────────────────────────
  Widget _buildLiveSessionCard(BookingModel booking, BuildContext context) {
    final status = booking.presentationStatusAt(DateTime.now());
    final isOngoing = status == 'in_progress';
    final isTracking = isOngoing || status == 'caregiver_en_route';
    final now = DateTime.now();
    final isToday = booking.scheduledStart.year == now.year &&
        booking.scheduledStart.month == now.month &&
        booking.scheduledStart.day == now.day;
    final caregiverName = booking.caregiverName?.trim();
    final schedule = booking.time.replaceAll(' – ', ' - ');
    final sessionDetail = caregiverName == null || caregiverName.isEmpty
        ? schedule
        : '$schedule ($caregiverName)';
    final statusLabel = switch (status) {
      'in_progress' => 'Đang diễn ra',
      'caregiver_en_route' => 'Đang di chuyển',
      'confirmed' || 'caregiver_accepted' => 'Sắp diễn ra',
      _ => 'Sắp diễn ra',
    };
    final title = isOngoing
        ? 'Ca đang diễn ra hôm nay'
        : isToday
            ? 'Ca sắp diễn ra hôm nay'
            : 'Ca sắp tới';
    final accentColor = isOngoing ? AppColors.primary : AppColors.secondary;

    return GestureDetector(
      onTap: () => context.push(
        isTracking
            ? '/bookings/${booking.id}/tracking'
            : '/bookings/${booking.id}',
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isOngoing ? const Color(0xFFF1FBF7) : const Color(0xFFFFFBF3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 12,
                        color: accentColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          sessionDetail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatCurrency(booking.totalPrice),
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }

  // ── Promotions Section ────────────────────────────────────────────────────
  Widget _buildPromotionsSection(BuildContext context) {
    final promos = [
      (
        title: 'Ưu đãi khách mới',
        subtitle: 'Giảm 20% đơn đầu tiên',
        hsd: 'HSD: 31/10/2026',
        badge: 'Giảm 20%',
        bg: const Color(0xFFE8F7F0),
        accent: AppColors.primary,
        borderColor: AppColors.primary,
        icon: '🎁',
      ),
      (
        title: 'Đặt lịch cuối tuần',
        subtitle: 'Tiết kiệm 50.000đ',
        hsd: 'HSD: 05/10/2026',
        badge: 'Giảm 50k',
        bg: const Color(0xFFFEF7EC),
        accent: const Color(0xFFE67E22),
        borderColor: const Color(0xFFE67E22),
        icon: '🌟',
      ),
      (
        title: 'Giới thiệu bạn bè',
        subtitle: 'Nhận 100.000đ tín dụng',
        hsd: 'Không giới hạn',
        badge: '+100k',
        bg: const Color(0xFFEDE7F6),
        accent: const Color(0xFF7B1FA2),
        borderColor: const Color(0xFF7B1FA2),
        icon: '👥',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Ưu đãi & Khuyến mãi',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {},
              child: const Text(
                'Xem tất cả',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          child: IntrinsicHeight(
            child: Row(
              children: [
                for (var i = 0; i < promos.length; i++) ...[
                  _buildPromoCard(promos[i]),
                  if (i != promos.length - 1) const SizedBox(width: 10),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPromoCard(
    ({
      String title,
      String subtitle,
      String hsd,
      String badge,
      Color bg,
      Color accent,
      Color borderColor,
      String icon
    }) promo,
  ) {
    final textScale =
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4).toDouble();

    return Container(
      width: 170 * textScale,
      constraints: const BoxConstraints(minHeight: 114),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: promo.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: promo.borderColor.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(promo.icon, style: const TextStyle(fontSize: 16)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: promo.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  promo.badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            promo.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            promo.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: promo.accent,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Text(
                  promo.hsd,
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 9,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: promo.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Dùng ngay',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Recently Booked Section ─────────────────────────────────────────────────
  Widget _buildRecentlyBookedSection(
      BuildContext context, List<BookingModel> bookings) {
    // Lọc những booking đã hoàn thành, lấy caregiver unique gần nhất
    final completed = bookings
        .where((b) =>
            b.presentationStatusAt(DateTime.now()) == 'completed' ||
            b.presentationStatusAt(DateTime.now()) == 'caregiver_completed')
        .toList()
      ..sort((a, b) => b.scheduledStart.compareTo(a.scheduledStart));

    // Deduplicate theo caregiverId
    final seen = <String>{};
    final unique = completed
        .where((b) {
          if (b.caregiverId == null) return false;
          return seen.add(b.caregiverId!);
        })
        .take(5)
        .toList();

    if (unique.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Đã đặt gần đây',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => context.push('/bookings'),
              child: const Text(
                'Xem thêm',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          child: IntrinsicHeight(
            child: Row(
              children: [
                for (var i = 0; i < unique.length; i++) ...[
                  _buildRebookCard(unique[i], context),
                  if (i != unique.length - 1) const SizedBox(width: 12),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRebookCard(BookingModel booking, BuildContext context) {
    final name = booking.caregiverName?.trim() ?? 'Chăm sóc viên';
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase())
        .take(2)
        .join();
    final serviceId = Uri.encodeComponent(booking.serviceTypeId);

    final textScale =
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3).toDouble();

    return Container(
      width: 160 * textScale,
      constraints: const BoxConstraints(minHeight: 164),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryContainer,
                child: Text(
                  initials.isNotEmpty ? initials : 'CV',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.verified_rounded,
                  color: AppColors.primary, size: 14),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              booking.serviceName ?? 'Chăm sóc',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => context.push(
              '/booking/new?serviceId=$serviceId&caregiverId=${booking.caregiverId ?? ""}',
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Đặt lại',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Upcoming Appointments Section ───────────────────────────────────────────
  Widget _buildUpcomingAppointmentsSection(
      BuildContext context, List<BookingModel> bookings) {
    final now = DateTime.now();
    const upcomingStatuses = {
      'confirmed',
      'caregiver_accepted',
      'caregiver_en_route',
      'in_progress',
    };
    final upcoming = bookings
        .where((b) =>
            upcomingStatuses.contains(b.presentationStatusAt(now)) &&
            b.scheduledEnd.isAfter(now))
        .toList()
      ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));

    final preview = upcoming.take(2).toList();
    if (preview.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Lịch hẹn gần đây',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => context.push('/bookings'),
              child: const Text(
                'Xem tất cả',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Column(
          children: [
            for (var i = 0; i < preview.length; i++) ...[
              _buildAppointmentCard(preview[i], now, context),
              if (i != preview.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildAppointmentCard(
      BookingModel booking, DateTime now, BuildContext context) {
    final status = booking.presentationStatusAt(now);
    final isOngoing = status == 'in_progress' || status == 'caregiver_en_route';
    final statusLabel = isOngoing ? 'Đang diễn ra' : 'Sắp diễn ra';
    final statusColor = isOngoing ? AppColors.primary : const Color(0xFFE67E22);
    final statusBg =
        isOngoing ? const Color(0xFFE8F7F0) : const Color(0xFFFEF7EC);
    final caregiverName = booking.caregiverName?.trim() ?? 'Chăm sóc viên';
    final initials = caregiverName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase())
        .take(2)
        .join();

    // Format date
    const weekdays = [
      'Thứ 2',
      'Thứ 3',
      'Thứ 4',
      'Thứ 5',
      'Thứ 6',
      'Thứ 7',
      'CN'
    ];
    final dt = booking.scheduledStart;
    final dayLabel =
        dt.year == now.year && dt.month == now.month && dt.day == now.day
            ? 'Hôm nay'
            : weekdays[dt.weekday - 1];
    final dateStr =
        '$dayLabel, ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

    return GestureDetector(
      onTap: () => context.push(
        isOngoing
            ? '/bookings/${booking.id}/tracking'
            : '/bookings/${booking.id}',
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primaryContainer,
              child: Text(
                initials.isNotEmpty ? initials : 'CV',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    caregiverName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$dateStr · ${booking.time}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (booking.serviceName != null) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        booking.serviceName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.textHint,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Services Section ────────────────────────────────────────────────────────
  Widget _buildServicesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Dịch vụ nổi bật',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => context.push('/catalog'),
              child: const Text(
                'Tất cả',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Consumer(
          builder: (context, ref, _) {
            final servicesAsync = ref.watch(serviceStoreProvider);
            return servicesAsync.when(
              loading: () => const SizedBox(
                height: 128,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (services) {
                final featured = services;
                if (featured.isEmpty) {
                  return const SizedBox.shrink();
                }

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        for (var i = 0; i < featured.length; i++) ...[
                          _buildServiceCard(featured[i], _serviceAccent(i)),
                          if (i != featured.length - 1)
                            const SizedBox(width: 10),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildServiceCard(ServiceModel service, _ServiceAccent accent) {
    final serviceId = Uri.encodeComponent(service.id);
    final textScale =
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3).toDouble();

    return BouncingCard(
      onTap: () => context.push('/booking/new?serviceId=$serviceId'),
      child: Container(
        width: 138 * textScale,
        constraints: const BoxConstraints(minHeight: 132),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accent.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent.color.withValues(alpha: 0.14),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  service.icon,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              service.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const Spacer(),
            if (service.baseHourlyPrice > 0)
              Text(
                '${_formatVnd(service.baseHourlyPrice)}/giờ',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              Text(
                '${service.defaultDurationMinutes} phút',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  _ServiceAccent _serviceAccent(int index) {
    const accents = [
      _ServiceAccent(AppColors.primary, AppColors.primaryContainer),
      _ServiceAccent(Color(0xFFE67E22), Color(0xFFFFF3E0)),
      _ServiceAccent(Color(0xFF1976D2), Color(0xFFE3F0FC)),
      _ServiceAccent(Color(0xFF7B1FA2), Color(0xFFF3E5F5)),
      _ServiceAccent(Color(0xFF00897B), Color(0xFFE0F2F1)),
      _ServiceAccent(Color(0xFF5C6BC0), Color(0xFFEDE7F6)),
    ];
    return accents[index % accents.length];
  }

  String _formatVnd(int amount) {
    if (amount == 0) return 'Liên hệ';
    final s = amount.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '$bufđ';
  }

  // ── Caregiver Section ───────────────────────────────────────────────────────
  Widget _buildCaregiverSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Chăm sóc viên gần bạn',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                  Text('📍', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => context.go('/caregivers'),
              child: const Text(
                'Xem thêm',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Consumer(
          builder: (context, ref, _) {
            final caregiverAsync = ref.watch(caregiverStoreProvider);
            return caregiverAsync.when(
              loading: () => const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (caregivers) {
                if (caregivers.isEmpty) {
                  return _buildCaregiverEmptyState(context);
                }
                final preview = caregivers.take(5).toList();
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        for (var i = 0; i < preview.length; i++) ...[
                          _buildCaregiverCard(preview[i], context),
                          if (i != preview.length - 1)
                            const SizedBox(width: 12),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildCaregiverCard(CaregiverModel c, BuildContext context) {
    final textScale =
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3).toDouble();

    return GestureDetector(
      onTap: () => context.push('/caregivers/${c.id}'),
      child: Container(
        width: 180 * textScale,
        constraints: const BoxConstraints(minHeight: 220),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primaryContainer,
                  child: Text(
                    c.initials,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                if (c.isOnline)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    c.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(Icons.verified_rounded,
                    color: AppColors.primary, size: 14),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.star_rounded,
                    color: Color(0xFFF5A623), size: 13),
                const SizedBox(width: 2),
                Text(
                  c.ratingAvg.toStringAsFixed(1),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  ' (${c.ratingCount})',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (c.skills.isNotEmpty) ...[
              Row(
                children: [
                  Flexible(
                    child: _buildSkillChip(c.skills.first),
                  ),
                  if (c.skills.length > 1) ...[
                    const SizedBox(width: 4),
                    _buildSkillChip('+${c.skills.length - 1}'),
                  ],
                ],
              ),
              const SizedBox(height: 8),
            ],
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Chi tiết',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCaregiverEmptyState(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/caregivers'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          children: [
            Icon(Icons.people_alt_outlined,
                color: AppColors.textHint, size: 36),
            SizedBox(height: 8),
            Text(
              'Chưa có chăm sóc viên trong khu vực',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // Helpers
  String _formatCurrency(double amount) {
    return '${amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        )}đ';
  }

  // ── Hero Banner ────────────────────────────────────────────────────────────
  Widget _buildHeroBanner(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 360;
    final textScale =
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8).toDouble();
    final heroHeight = (isNarrow ? 352.0 : 320.0) + ((textScale - 1) * 150);
    final stats = Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF4ADE80),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Hơn 250+ điều dưỡng & hộ lý\ncao tuổi sẵn sàng',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: isNarrow ? 10 : 12,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
    final callToAction = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: GestureDetector(
        onTap: () => context.push('/booking/new'),
        child: Container(
          key: const Key('home-book-now-cta'),
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 9 : 14,
            vertical: isNarrow ? 9 : 11,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Đặt lịch ngay',
                maxLines: 1,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isNarrow ? 10 : 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
    return SizedBox(
      key: const Key('home-hero-banner'),
      height: heroHeight,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            CachedNetworkImage(
              imageUrl:
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuB_gclqxTQn4Hcbz-83_gEg_MI4goQwj5nYiQZUd0zrWDfoybrs5j468EvYpccjQIJJFrVTI67wuoh7Z0NRIGF9MxbDKSyHNoKOlk8yxNHqzA_mqeKF7jbE0KUjwdrUuQMtcP4g5I-YO-UoQ_iiLGbRsTCfz0c2CEvq8BKN0pgJWk0gyVm9-tgZPvsg7bkPlycqYWLBLVb3r6bsGe--8-MHnPdrZh43tjpZrrx2BFVCpqArNmmv3QK9',
              memCacheWidth: 1200,
              fadeInDuration: Duration.zero,
              placeholder: (_, __) =>
                  const ColoredBox(color: AppColors.primaryContainer),
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                color: AppColors.primaryContainer,
                child: const Icon(Icons.elderly_woman_rounded,
                    size: 80, color: AppColors.primary),
              ),
            ),

            // Gradient overlay (bottom-heavy dark)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.75),
                    ],
                    stops: const [0.3, 1.0],
                  ),
                ),
              ),
            ),

            // Content
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(isNarrow ? 14 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('⭐', style: TextStyle(fontSize: 13)),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Đồng hành tin cậy cùng Cha Mẹ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Headline
                    Text(
                      'Trao gửi yêu thương,\nan tâm mỗi ngày',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isNarrow ? 20 : 26,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Description
                    Text(
                      'Người bạn đồng hành tận tâm hỗ trợ sinh hoạt, trò chuyện & chăm sóc Cha Mẹ chu đáo khi bạn bận rộn.',
                      maxLines: isNarrow ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isNarrow ? 10.5 : 13,
                        height: isNarrow ? 1.4 : 1.5,
                      ),
                    ),
                    SizedBox(height: isNarrow ? 10 : 16),

                    // Stats + CTA row
                    if (isNarrow)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          stats,
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: callToAction,
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(child: stats),
                          const SizedBox(width: 8),
                          callToAction,
                        ],
                      ),
                    SizedBox(height: isNarrow ? 10 : 16),

                    // Search caregivers by name, skill or service location.
                    SizedBox(
                      height: isNarrow ? 44 : 48,
                      child: TextField(
                        controller: _caregiverSearchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _openCaregiverSearch,
                        onTapOutside: (_) =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Tìm người chăm sóc, kỹ năng, địa chỉ...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF6E8989),
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          suffixIcon: IconButton(
                            tooltip: 'Mở bộ lọc chăm sóc viên',
                            onPressed: _openCaregiverSearch,
                            icon: const Icon(
                              Icons.tune_rounded,
                              color: AppColors.textSecondary,
                              size: 18,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 13),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primaryLight,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceAccent {
  final Color color;
  final Color background;

  const _ServiceAccent(this.color, this.background);
}
