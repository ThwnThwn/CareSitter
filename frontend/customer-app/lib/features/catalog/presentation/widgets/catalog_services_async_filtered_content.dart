import 'package:caresitter_customer/features/catalog/presentation/widgets/catalog_services_async_filter_services_content.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';
import 'package:caresitter_customer/features/catalog/presentation/models/catalog_service_filter.dart';

class CatalogServicesAsyncFilteredContent extends StatelessWidget {
  const CatalogServicesAsyncFilteredContent(
      {super.key,
      required this.buildSearchBar,
      required this.buildBanner,
      required this.servicesAsync,
      required this.selectedFilter,
      required this.onFilterChanged,
      required this.filtered,
      required this.buildServiceCard});
  final Widget Function() buildSearchBar;
  final Widget Function() buildBanner;
  final AsyncValue<List<ServiceModel>> servicesAsync;
  final CatalogServiceFilter selectedFilter;
  final ValueChanged<CatalogServiceFilter> onFilterChanged;
  final List<ServiceModel> Function(List<ServiceModel>) filtered;
  final Widget Function(ServiceModel, int, BuildContext) buildServiceCard;

  @override
  Widget build(BuildContext context) => CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          const SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0.5,
            shadowColor: AppColors.shadow,
            title: Text(
              'Danh mục dịch vụ',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFontSizes.s18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            centerTitle: true,
            leading: AppBackButton(fallbackRoute: AppRoutes.home),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.compact, AppSpacing.md, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Search Bar ─────────────────────────────────────────────
                FadeSlideStaggered(
                  index: 0,
                  child: buildSearchBar(),
                ),
                const SizedBox(height: AppSpacing.inset),

                // ── Banner ─────────────────────────────────────────────────
                FadeSlideStaggered(
                  index: 1,
                  child: buildBanner(),
                ),
                const SizedBox(height: 22),

                // ── Section Title ──────────────────────────────────────────
                const FadeSlideStaggered(
                  index: 2,
                  child: _CatalogSectionIntro(),
                ),
                const SizedBox(height: AppSpacing.compact),

                // ── Service List ───────────────────────────────────────────
                CatalogServicesAsyncFilterServicesContent(
                    servicesAsync: servicesAsync,
                    selectedFilter: selectedFilter,
                    onFilterChanged: onFilterChanged,
                    filterServices: filtered,
                    buildServiceCard: buildServiceCard),
              ]),
            ),
          ),
        ],
      );
}

class _CatalogSectionIntro extends StatelessWidget {
  const _CatalogSectionIntro();

  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dịch vụ chăm sóc tại nhà',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppFontSizes.s17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'Chọn gói phi y tế phù hợp với thời gian và nhu cầu của gia đình.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFontSizes.s12,
              height: 1.4,
            ),
          ),
        ],
      );
}
