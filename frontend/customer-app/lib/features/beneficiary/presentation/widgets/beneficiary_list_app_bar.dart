import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';

class BeneficiaryListAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  const BeneficiaryListAppBar({super.key, required this.beneficiaries});
  final List<BeneficiaryModel> beneficiaries;
  @override
  Widget build(BuildContext context) => AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hồ sơ chăm sóc',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFontSizes.s18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            if (beneficiaries.isNotEmpty)
              Text(
                '${beneficiaries.length} hồ sơ đang quản lý',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppFontSizes.s12,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: IconButton(
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_add_outlined,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              onPressed: () => context.push('/beneficiaries/create'),
            ),
          ),
        ],
      );
}
