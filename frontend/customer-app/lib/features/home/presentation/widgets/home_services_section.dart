import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_hover_button.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/service_controller.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import '../models/home_service_accent.dart';

class HomeServicesSection extends StatelessWidget {
  const HomeServicesSection({
    super.key,
    required this.buildServiceCard,
    required this.serviceAccent,
  });

  final Widget Function(ServiceModel, HomeServiceAccent) buildServiceCard;
  final HomeServiceAccent Function(int) serviceAccent;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FeaturedServicesHeader(
            onViewAll: () => context.push(AppRoutes.catalog),
          ),
          const SizedBox(height: AppSpacing.inset),
          _FeaturedServicesContent(
            buildServiceCard: buildServiceCard,
            serviceAccent: serviceAccent,
          ),
        ],
      );
}

class _FeaturedServicesHeader extends ConsumerWidget {
  const _FeaturedServicesHeader({required this.onViewAll});

  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(serviceStoreProvider);
    final subtitle = servicesAsync.when(
      data: (services) => services.isEmpty
          ? 'Khám phá các gói chăm sóc tại nhà'
          : '${services.length} gói chăm sóc tại nhà dành cho gia đình',
      loading: () => 'Đang tải các gói chăm sóc',
      error: (_, __) => 'Khám phá các gói chăm sóc tại nhà',
    );

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dịch vụ nổi bật',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppFontSizes.s17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppFontSizes.s11,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        HomeHoverButton(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: onViewAll,
          child: const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tất cả',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: AppFontSizes.s13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: AppSpacing.micro),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FeaturedServicesContent extends ConsumerWidget {
  const _FeaturedServicesContent({
    required this.buildServiceCard,
    required this.serviceAccent,
  });

  final Widget Function(ServiceModel, HomeServiceAccent) buildServiceCard;
  final HomeServiceAccent Function(int) serviceAccent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(serviceStoreProvider);
    return servicesAsync.when(
      loading: () => const _FeaturedServicesSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
      data: (services) {
        if (services.isEmpty) return const SizedBox.shrink();
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          child: IntrinsicHeight(
            child: Row(
              children: [
                for (var i = 0; i < services.length; i++) ...[
                  buildServiceCard(services[i], serviceAccent(i)),
                  if (i != services.length - 1)
                    const SizedBox(width: AppSpacing.control),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FeaturedServicesSkeleton extends StatelessWidget {
  const _FeaturedServicesSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(
          3,
          (index) => Padding(
            padding: EdgeInsets.only(
              right: index == 2 ? 0 : AppSpacing.control,
            ),
            child: Container(
              width: 156,
              height: 210,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
