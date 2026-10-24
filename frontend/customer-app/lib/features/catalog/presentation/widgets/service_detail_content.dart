import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_checklist_item_model.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:caresitter_customer/features/catalog/presentation/models/service_detail_profile.dart';
import 'package:caresitter_customer/features/catalog/presentation/widgets/service_booking_bar.dart';
import 'package:caresitter_customer/features/catalog/presentation/widgets/service_detail_sections.dart';
import 'package:flutter/material.dart';

class ServiceDetailContent extends StatelessWidget {
  const ServiceDetailContent({
    super.key,
    required this.service,
    required this.checklistItems,
    required this.checklistLoading,
    required this.onBack,
    required this.onShare,
    required this.onBook,
    required this.onRetryChecklist,
    this.checklistError,
  });

  final ServiceModel service;
  final List<ServiceChecklistItemModel> checklistItems;
  final bool checklistLoading;
  final String? checklistError;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onBook;
  final VoidCallback onRetryChecklist;

  @override
  Widget build(BuildContext context) {
    final profile = ServiceDetailProfile.forCode(service.code);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _ServiceDetailHero(
            profile: profile,
            onBack: onBack,
            onShare: onShare,
          ),
          SliverToBoxAdapter(
            child: _ServiceDetailBody(
              service: service,
              profile: profile,
              checklistItems: checklistItems,
              checklistLoading: checklistLoading,
              checklistError: checklistError,
              onRetryChecklist: onRetryChecklist,
            ),
          ),
        ],
      ),
      bottomNavigationBar: ServiceBookingBar(
        service: service,
        onBook: onBook,
      ),
    );
  }
}

class _ServiceDetailHero extends StatelessWidget {
  const _ServiceDetailHero({
    required this.profile,
    required this.onBack,
    required this.onShare,
  });

  final ServiceDetailProfile profile;
  final VoidCallback onBack;
  final VoidCallback onShare;

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
            onPressed: onBack,
          ),
        ),
        title: const _HeroTitle(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: _HeaderIconButton(
              tooltip: 'Chia sẻ dịch vụ',
              onPressed: onShare,
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

class _ServiceDetailBody extends StatelessWidget {
  const _ServiceDetailBody({
    required this.service,
    required this.profile,
    required this.checklistItems,
    required this.checklistLoading,
    required this.checklistError,
    required this.onRetryChecklist,
  });

  final ServiceModel service;
  final ServiceDetailProfile profile;
  final List<ServiceChecklistItemModel> checklistItems;
  final bool checklistLoading;
  final String? checklistError;
  final VoidCallback onRetryChecklist;

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
            child: ServiceDetailSections(
              service: service,
              profile: profile,
              checklistItems: checklistItems,
              checklistLoading: checklistLoading,
              checklistError: checklistError,
              onRetryChecklist: onRetryChecklist,
            ),
          ),
        ),
      );
}
