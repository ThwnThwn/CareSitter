import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

/// SliverAppBar với gradient cho màn hình báo cáo ca.
class ReportSliverAppBar extends StatelessWidget {
  final String beneficiaryName;
  final String bookingId;

  const ReportSliverAppBar({
    super.key,
    required this.beneficiaryName,
    required this.bookingId,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 160,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      title: const Text(
        'Báo cáo khách hàng',
        style: TextStyle(
          color: Colors.white,
          fontSize: AppFontSizes.s18,
          fontWeight: FontWeight.w700,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.heroGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.section,
                  AppSpacing.s56, AppSpacing.section, AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Chăm sóc $beneficiaryName',
                    style: const TextStyle(
                      fontSize: AppFontSizes.s20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Ca #$bookingId • ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: TextStyle(
                      fontSize: AppFontSizes.s13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
