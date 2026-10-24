import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:caresitter_customer/features/catalog/presentation/models/service_detail_profile.dart';
import 'package:caresitter_customer/features/catalog/presentation/widgets/service_booking_bar.dart';
import 'package:caresitter_customer/features/catalog/presentation/widgets/service_detail_sections.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ServiceDetailContent extends StatelessWidget {
  const ServiceDetailContent({super.key, required this.service});

  final ServiceModel service;

  @override
  Widget build(BuildContext context) {
    final profile = ServiceDetailProfile.forCode(service.code);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          ServiceDetailHero(profile: profile),
          SliverToBoxAdapter(
            child: ServiceDetailBody(service: service, profile: profile),
          ),
        ],
      ),
      bottomNavigationBar: ServiceBookingBar(service: service),
    );
  }
}

class ServiceDetailHero extends StatelessWidget {
  const ServiceDetailHero({super.key, required this.profile});

  final ServiceDetailProfile profile;

  @override
  Widget build(BuildContext context) => SliverAppBar(
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
        title: const _HeroTitle(),
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
          background: _HeroImage(profile: profile),
        ),
      );
}

class _HeroTitle extends StatelessWidget {
  const _HeroTitle();

  @override
  Widget build(BuildContext context) => Container(
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
      );
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.profile});

  final ServiceDetailProfile profile;

  @override
  Widget build(BuildContext context) => Stack(
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
      );
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

class ServiceDetailBody extends StatelessWidget {
  const ServiceDetailBody({
    super.key,
    required this.service,
    required this.profile,
  });

  final ServiceModel service;
  final ServiceDetailProfile profile;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              120 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ServiceTypeBadge(),
                const SizedBox(height: AppSpacing.compact),
                _ServiceIntroduction(service: service, profile: profile),
                const SizedBox(height: AppSpacing.md),
                ServiceFacts(service: service),
                const SizedBox(height: AppSpacing.xl),
                const _TimelineHeading(),
                const SizedBox(height: AppSpacing.md),
                ServiceTimeline(items: profile.timeline),
                const SizedBox(height: AppSpacing.lg),
                IncludedTasks(tasks: profile.tasks),
                const SizedBox(height: AppSpacing.lg),
                const SafetyCommitment(),
              ],
            ),
          ),
        ),
      );
}

class _ServiceIntroduction extends StatelessWidget {
  const _ServiceIntroduction({required this.service, required this.profile});

  final ServiceModel service;
  final ServiceDetailProfile profile;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            service.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
        ],
      );
}

class _TimelineHeading extends StatelessWidget {
  const _TimelineHeading();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
        ],
      );
}
