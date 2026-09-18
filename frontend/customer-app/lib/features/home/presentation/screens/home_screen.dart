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

    // Tìm ca đang diễn ra (nếu có)
    final liveBooking = bookings.where((b) {
      final s = b.status.toLowerCase();
      return s == 'in_progress' ||
          s == 'caregiver_en_route' ||
          s == 'confirmed';
    }).firstOrNull;

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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  _buildHeroBanner(context),
                  if (liveBooking != null) ...[
                    const SizedBox(height: 12),
                    _buildLiveSessionCard(liveBooking, context),
                  ],
                  const SizedBox(height: 20),
                  _buildServicesSection(context),
                  const SizedBox(height: 24),
                  _buildCaregiverSection(context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
                    const Text('👋', style: TextStyle(fontSize: 16)),
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
    final isActive = booking.status == 'in_progress' ||
        booking.status == 'caregiver_en_route';
    return GestureDetector(
      onTap: () => context.push('/bookings/${booking.id}/tracking'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(
              color: isActive ? AppColors.primary : AppColors.secondary,
              width: 4,
            ),
          ),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.secondary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isActive ? 'Ca đang diễn ra hôm nay' : 'Ca sắp diễn ra hôm nay',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              booking.time,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _formatCurrency(booking.totalPrice),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 16, color: AppColors.textHint),
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

                return SizedBox(
                  height: 132,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
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

    return BouncingCard(
      onTap: () => context.push('/booking/new?serviceId=$serviceId'),
      child: Container(
        width: 138,
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
                return SizedBox(
                  height: 220,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
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
    return GestureDetector(
      onTap: () => context.push('/caregivers/${c.id}'),
      child: Container(
        width: 180,
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
        )} ₫';
  }

  // ── Hero Banner ────────────────────────────────────────────────────────────
  Widget _buildHeroBanner(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 360;
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
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 11 : 12,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
    final callToAction = GestureDetector(
      onTap: () => context.push('/booking/new'),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 10 : 18,
          vertical: 11,
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
              style: TextStyle(
                color: Colors.white,
                fontSize: isCompact ? 11 : 13,
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
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          // Background image
          SizedBox(
            height: isCompact ? 480 : 320,
            width: double.infinity,
            child: CachedNetworkImage(
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
              padding: EdgeInsets.all(isCompact ? 16 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge pill
                  Container(
                    width: isCompact ? double.infinity : null,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize:
                          isCompact ? MainAxisSize.max : MainAxisSize.min,
                      children: const [
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
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 21 : 26,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    'Người bạn đồng hành tận tâm hỗ trợ sinh hoạt, trò chuyện & chăm sóc Cha Mẹ chu đáo khi bạn bận rộn.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 11 : 13,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: isCompact ? 10 : 16),

                  // Stats + CTA row
                  if (isCompact)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        stats,
                        const SizedBox(height: 8),
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
                        callToAction,
                      ],
                    ),
                  SizedBox(height: isCompact ? 10 : 16),

                  // Search bar
                  GestureDetector(
                    onTap: () => context.push('/caregivers'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded,
                              color: Color(0xFFB0B8C1), size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Tìm người chăm sóc người già, địa chỉ...',
                              style: TextStyle(
                                color: Color(0xFFB0B8C1),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.tune_rounded,
                                color: AppColors.textSecondary, size: 16),
                          ),
                        ],
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
}

class _ServiceAccent {
  final Color color;
  final Color background;

  const _ServiceAccent(this.color, this.background);
}
