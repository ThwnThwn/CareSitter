import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';

class SavedAddressesScreenAddressHeader extends StatelessWidget {
  const SavedAddressesScreenAddressHeader(
      {super.key,
      required this.address,
      required this.isSelected,
      required this.isDefault});
  final AddressModel address;
  final bool isSelected;
  final bool isDefault;
  @override
  Widget build(BuildContext context) {
    final title = Text(
      address.displayLabel,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: AppFontSizes.s15,
        color: isSelected ? AppColors.primary : AppColors.textPrimary,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        title,
        if (isDefault)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.tight, vertical: AppSpacing.micro),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: const Text(
              'Mặc định',
              style: TextStyle(
                fontSize: AppFontSizes.s10,
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (isSelected)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.tight, vertical: AppSpacing.micro),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: const Text(
              'Đang chọn',
              style: TextStyle(
                fontSize: AppFontSizes.s10,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (!address.isVerified)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.tight, vertical: AppSpacing.micro),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: const Text(
              'Chưa xác minh',
              style: TextStyle(
                fontSize: AppFontSizes.s10,
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
