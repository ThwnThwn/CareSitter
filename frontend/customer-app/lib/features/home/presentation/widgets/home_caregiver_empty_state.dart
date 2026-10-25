import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_hover_button.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class HomeCaregiverEmptyState extends StatelessWidget {
  const HomeCaregiverEmptyState({super.key, required this.hasLocation});
  final bool hasLocation;
  @override
  Widget build(BuildContext context) {
    return HomeHoverButton(
      onTap: () => context.go(AppRoutes.caregivers),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.section),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.people_alt_outlined,
                color: AppColors.textHint, size: 36),
            const SizedBox(height: AppSpacing.sm),
            Text(
              hasLocation
                  ? 'Chưa có chăm sóc viên phục vụ địa chỉ này'
                  : 'Chọn địa chỉ chăm sóc để xem người ở gần',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: AppFontSizes.s14),
            ),
          ],
        ),
      ),
    );
  }
}
