import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/service_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(serviceStoreProvider);
    return services.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _ServiceDetailError(
        onRetry: () => ref.read(serviceStoreProvider.notifier).refresh(),
      ),
      data: (items) {
        final service = items.where((item) => item.id == serviceId).firstOrNull;
        if (service == null) {
          return const _ServiceDetailNotFound();
        }
        return _ServiceDetailContent(service: service);
      },
    );
  }
}

class _ServiceDetailContent extends StatelessWidget {
  const _ServiceDetailContent({required this.service});

  final ServiceModel service;

  @override
  Widget build(BuildContext context) {
    final profile = _ServiceProfile.forCode(service.code);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 270,
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            surfaceTintColor: Colors.transparent,
            leadingWidth: 64,
            leading: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: _HeaderIconButton(
                tooltip: 'Quay lại',
                icon: Icons.arrow_back_rounded,
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(AppRoutes.catalog),
              ),
            ),
            title: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.compact,
                vertical: AppSpacing.tight,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: const Text(
                'Chi tiết dịch vụ',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: _HeaderIconButton(
                  tooltip: 'Chia sẻ dịch vụ',
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã sẵn sàng để chia sẻ dịch vụ.'),
                    ),
                  ),
                  icon: Icons.ios_share_rounded,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    profile.imageAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: AppColors.primaryContainer,
                      child: Icon(
                        Icons.volunteer_activism_rounded,
                        size: 72,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xA6000000)],
                        stops: [0.45, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    bottom: AppSpacing.md,
                    child: Text(
                      profile.heroLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                    120 + bottomInset,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _ServiceTypeBadge(),
                      const SizedBox(height: AppSpacing.compact),
                      Text(
                        service.name,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        service.description?.trim().isNotEmpty == true
                            ? service.description!.trim()
                            : profile.summary,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.55,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ServiceFacts(service: service),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Một ca chăm sóc diễn ra như thế nào?',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Lịch trình được thống nhất với gia đình và linh hoạt theo nhu cầu thực tế.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ...profile.timeline.indexed.map(
                        (entry) => _TimelineItem(
                          item: entry.$2,
                          isLast: entry.$1 == profile.timeline.length - 1,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _IncludedTasks(tasks: profile.tasks),
                      const SizedBox(height: AppSpacing.lg),
                      const _SafetyCommitment(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BookingBar(service: service),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Center(
        child: Material(
          color: AppColors.surface.withValues(alpha: 0.94),
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            icon: Icon(icon, color: AppColors.textPrimary),
          ),
        ),
      );
}

class _ServiceTypeBadge extends StatelessWidget {
  const _ServiceTypeBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.compact,
          vertical: AppSpacing.tight,
        ),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: const Text(
          'Chăm sóc phi y tế tại nhà',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );
}

class _ServiceFacts extends StatelessWidget {
  const _ServiceFacts({required this.service});

  final ServiceModel service;

  @override
  Widget build(BuildContext context) {
    final hours = service.defaultDurationMinutes / 60;
    final duration = hours == hours.roundToDouble()
        ? '${hours.toInt()} giờ'
        : '${service.defaultDurationMinutes} phút';
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _FactChip(icon: Icons.schedule_rounded, label: 'Ca từ $duration'),
        const _FactChip(
          icon: Icons.verified_user_outlined,
          label: 'Caregiver đã xác minh',
        ),
        const _FactChip(
          icon: Icons.receipt_long_outlined,
          label: 'Có nhật ký chăm sóc',
        ),
      ],
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.compact,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: AppColors.primary),
            const SizedBox(width: AppSpacing.tight),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.item, required this.isLast});

  final _TimelineEntry item;
  final bool isLast;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 36,
              child: Column(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryContainer,
                    ),
                    child: Icon(item.icon, size: 17, color: AppColors.primary),
                  ),
                  if (!isLast)
                    const Expanded(
                      child: VerticalDivider(
                        color: AppColors.border,
                        thickness: 1.5,
                        width: 1.5,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.compact),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      item.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
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

class _IncludedTasks extends StatelessWidget {
  const _IncludedTasks({required this.tasks});

  final List<String> tasks;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Công việc có trong gói',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSpacing.compact),
              ...tasks.map(
                (task) => Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.tight),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.control),
                      Expanded(
                        child: Text(
                          task,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    height: 1.45,
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

class _SafetyCommitment extends StatelessWidget {
  const _SafetyCommitment();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Cam kết CareSitter',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.compact),
            const Text(
              'Caregiver được xác minh hồ sơ • Giá và phạm vi công việc minh bạch • Gia đình theo dõi nhật ký ca chăm sóc.',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Dịch vụ không thay thế khám, chẩn đoán, điều trị hoặc thực hiện thủ thuật y tế.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
}

class _BookingBar extends StatelessWidget {
  const _BookingBar({required this.service});

  final ServiceModel service;

  @override
  Widget build(BuildContext context) {
    final price = service.baseHourlyPrice > 0
        ? '${NumberFormat.decimalPattern('vi').format(service.baseHourlyPrice)}đ/giờ'
        : 'Xem giá khi đặt lịch';
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.compact,
            AppSpacing.md,
            AppSpacing.compact,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chi phí từ',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.micro),
                    Text(
                      price,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                width: 172,
                child: FilledButton.icon(
                  onPressed: () => context.push(
                    AppRoutes.bookingNewWith(serviceId: service.id),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  label: const Text('Đặt lịch ngay'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceDetailError extends StatelessWidget {
  const _ServiceDetailError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Chi tiết dịch vụ')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 48),
                const SizedBox(height: AppSpacing.md),
                const Text('Chưa tải được thông tin dịch vụ.'),
                const SizedBox(height: AppSpacing.md),
                FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
              ],
            ),
          ),
        ),
      );
}

class _ServiceDetailNotFound extends StatelessWidget {
  const _ServiceDetailNotFound();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Chi tiết dịch vụ')),
        body: const Center(child: Text('Không tìm thấy dịch vụ này.')),
      );
}

class _TimelineEntry {
  const _TimelineEntry(this.icon, this.title, this.description);

  final IconData icon;
  final String title;
  final String description;
}

class _ServiceProfile {
  const _ServiceProfile({
    required this.imageAsset,
    required this.heroLabel,
    required this.summary,
    required this.timeline,
    required this.tasks,
  });

  final String imageAsset;
  final String heroLabel;
  final String summary;
  final List<_TimelineEntry> timeline;
  final List<String> tasks;

  static _ServiceProfile forCode(String code) {
    final value = code.toUpperCase();
    if (value.contains('COMPANION') || value.contains('DONGHANH')) {
      return const _ServiceProfile(
        imageAsset: 'assets/images/service-companion.jpg',
        heroLabel: 'Trò chuyện, sẻ chia và đồng hành mỗi ngày',
        summary:
            'Một người bạn tận tâm cùng người thân trò chuyện, giải trí và duy trì nhịp sinh hoạt quen thuộc.',
        timeline: [
          _TimelineEntry(
              Icons.waving_hand_outlined,
              'Chào hỏi và thống nhất hoạt động',
              'Caregiver đọc ghi chú, hỏi thăm và cùng người được chăm sóc chọn hoạt động phù hợp.'),
          _TimelineEntry(
              Icons.forum_outlined,
              'Trò chuyện và hoạt động yêu thích',
              'Đọc sách, nghe nhạc, chơi trò chơi nhẹ hoặc cùng xem lại ảnh gia đình.'),
          _TimelineEntry(
              Icons.directions_walk_rounded,
              'Vận động nhẹ và nghỉ ngơi',
              'Đi lại nhẹ nhàng trong phạm vi an toàn theo khả năng và mong muốn.'),
          _TimelineEntry(Icons.fact_check_outlined, 'Bàn giao cuối ca',
              'Ghi lại các hoạt động đã thực hiện và cập nhật cho gia đình.'),
        ],
        tasks: [
          'Xác nhận ghi chú chăm sóc',
          'Trò chuyện và bầu bạn',
          'Hỗ trợ hoạt động giải trí nhẹ',
          'Nhắc lịch sinh hoạt do gia đình cung cấp',
          'Bàn giao cuối ca'
        ],
      );
    }
    if (value.contains('NIGHT') || value.contains('DEM')) {
      return const _ServiceProfile(
        imageAsset: 'assets/images/service-night.jpg',
        heroLabel: 'Có người đồng hành an tâm trong khung giờ tối',
        summary:
            'Hỗ trợ sinh hoạt buổi tối, giữ không gian an toàn và cập nhật kịp thời cho gia đình.',
        timeline: [
          _TimelineEntry(
              Icons.nights_stay_outlined,
              'Nhận ca và kiểm tra không gian',
              'Đối chiếu ghi chú, lối đi, ánh sáng và các vật dụng cần thiết.'),
          _TimelineEntry(
              Icons.dinner_dining_outlined,
              'Hỗ trợ sinh hoạt buổi tối',
              'Chuẩn bị đồ uống hoặc bữa nhẹ và hỗ trợ các hoạt động cá nhân đã thống nhất.'),
          _TimelineEntry(
              Icons.notifications_active_outlined,
              'Nhắc lịch và quan sát an toàn',
              'Nhắc lịch do gia đình cung cấp và hỗ trợ khi người thân cần di chuyển.'),
          _TimelineEntry(Icons.fact_check_outlined, 'Bàn giao cuối ca',
              'Cập nhật tình hình, công việc đã hoàn thành và các lưu ý phát sinh.'),
        ],
        tasks: [
          'Xác nhận ghi chú ca tối',
          'Hỗ trợ sinh hoạt cá nhân',
          'Chuẩn bị đồ uống hoặc bữa nhẹ',
          'Nhắc lịch sinh hoạt',
          'Bàn giao cuối ca'
        ],
      );
    }
    if (value.contains('DAY')) {
      return const _ServiceProfile(
        imageAsset: 'assets/images/service-day.jpg',
        heroLabel: 'Hỗ trợ trọn buổi với lịch trình linh hoạt',
        summary:
            'Đồng hành nhiều giờ với các hoạt động sinh hoạt, bữa ăn và vận động nhẹ theo thỏa thuận.',
        timeline: [
          _TimelineEntry(
              Icons.assignment_outlined,
              'Bắt đầu ca và rà soát kế hoạch',
              'Xác nhận phạm vi công việc, ưu tiên trong ngày và thông tin liên hệ của gia đình.'),
          _TimelineEntry(Icons.home_outlined, 'Hỗ trợ sinh hoạt tại nhà',
              'Hỗ trợ vệ sinh cá nhân, thay đồ và sắp xếp không gian sinh hoạt gọn gàng.'),
          _TimelineEntry(Icons.restaurant_outlined, 'Chuẩn bị bữa ăn',
              'Chuẩn bị món ăn theo nguyên liệu, khẩu vị và hướng dẫn gia đình cung cấp.'),
          _TimelineEntry(Icons.fact_check_outlined, 'Tổng kết và bàn giao',
              'Hoàn tất checklist, ghi nhật ký và trao đổi lại với gia đình.'),
        ],
        tasks: [
          'Xác nhận kế hoạch chăm sóc',
          'Hỗ trợ vệ sinh và thay đồ',
          'Chuẩn bị bữa ăn hoặc đồ uống',
          'Đồng hành vận động nhẹ',
          'Bàn giao cuối ca'
        ],
      );
    }
    return const _ServiceProfile(
      imageAsset: 'assets/images/service-essential.jpg',
      heroLabel: 'Hỗ trợ các nhu cầu sinh hoạt thiết yếu',
      summary:
          'Hỗ trợ chu đáo các hoạt động thường ngày để người thân sinh hoạt thuận tiện và an toàn hơn.',
      timeline: [
        _TimelineEntry(Icons.assignment_outlined, 'Xác nhận ghi chú chăm sóc',
            'Caregiver đọc lại phạm vi hỗ trợ và các lưu ý do gia đình cung cấp.'),
        _TimelineEntry(
            Icons.accessibility_new_rounded,
            'Hỗ trợ sinh hoạt cá nhân',
            'Hỗ trợ vệ sinh, thay đồ và di chuyển trong phạm vi đã thống nhất.'),
        _TimelineEntry(
            Icons.restaurant_outlined,
            'Chuẩn bị bữa ăn hoặc đồ uống',
            'Chuẩn bị theo nguyên liệu và hướng dẫn do gia đình cung cấp.'),
        _TimelineEntry(Icons.fact_check_outlined, 'Bàn giao cuối ca',
            'Ghi nhận công việc đã hoàn thành và cập nhật cho gia đình.'),
      ],
      tasks: [
        'Xác nhận ghi chú chăm sóc',
        'Hỗ trợ vệ sinh và thay đồ',
        'Chuẩn bị bữa ăn hoặc đồ uống',
        'Nhắc lịch sinh hoạt',
        'Bàn giao cuối ca'
      ],
    );
  }
}
