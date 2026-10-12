import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';

class LocationSelectorContent extends StatelessWidget {
  const LocationSelectorContent(
      {super.key,
      required this.loading,
      required this.failed,
      this.selectedId,
      this.shortAddress});
  final bool loading, failed;
  final String? selectedId, shortAddress;
  @override
  Widget build(BuildContext context) => Row(children: [
        const Icon(Icons.location_on_outlined,
            color: AppColors.primary, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                loading
                    ? 'Đang tải địa chỉ...'
                    : failed
                        ? 'Chưa tải được địa chỉ'
                        : selectedId == null
                            ? 'Chọn địa chỉ chăm sóc'
                            : 'Địa chỉ chăm sóc',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: AppFontSizes.s13,
                    fontWeight: FontWeight.w600)),
            if (!loading && !failed) ...[
              const SizedBox(height: AppSpacing.tiny),
              Text(shortAddress ?? 'Chọn địa chỉ có tọa độ để tìm người ở gần.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppFontSizes.s12,
                      height: 1.4)),
            ],
          ],
        )),
        const SizedBox(width: AppSpacing.sm),
        if (loading)
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
        else
          Text(
              failed
                  ? 'Thử lại'
                  : selectedId == null
                      ? 'Chọn'
                      : 'Đổi',
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: AppFontSizes.s13,
                  fontWeight: FontWeight.w600)),
      ]);
}
