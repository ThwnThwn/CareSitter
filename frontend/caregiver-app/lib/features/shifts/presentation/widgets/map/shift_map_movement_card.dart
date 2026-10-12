import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/widgets/app_widgets.dart';

/// Trạng thái định vị phục vụ hiển thị thẻ di chuyển.
sealed class LocationStatus {
  const LocationStatus();
}

class LocationLoading extends LocationStatus {
  const LocationLoading();
}

class LocationReady extends LocationStatus {
  const LocationReady();
}

class LocationFailed extends LocationStatus {
  final String message;
  const LocationFailed(this.message);
}

/// Card nổi ở đáy bản đồ hiển thị thông tin di chuyển, khoảng cách và nút chỉ đường.
class ShiftMapMovementCard extends StatelessWidget {
  final String beneficiaryName;
  final String address;
  final String? distanceLabel;
  final LocationStatus status;
  final VoidCallback onRetryLocation;
  final VoidCallback onOpenGoogleMaps;

  const ShiftMapMovementCard({
    super.key,
    required this.beneficiaryName,
    required this.address,
    required this.status,
    required this.onRetryLocation,
    required this.onOpenGoogleMaps,
    this.distanceLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.section),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.directions_car_rounded,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text(
                  'Thông tin di chuyển',
                  style: TextStyle(
                    fontSize: AppFontSizes.s16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (distanceLabel != null)
                Flexible(
                  child: Text(
                    distanceLabel!,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: AppFontSizes.s12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          switch (status) {
            LocationLoading() => const Padding(
                padding: EdgeInsets.only(top: AppSpacing.control),
                child: LinearProgressIndicator(),
              ),
            LocationFailed(:final message) => Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(
                          fontSize: AppFontSizes.s12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onRetryLocation,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            LocationReady() => const SizedBox.shrink(),
          },
          const SizedBox(height: AppSpacing.md),
          Text(
            'Khách hàng: $beneficiaryName',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: AppFontSizes.s14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            address,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: AppFontSizes.s13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          AppButton(
            label: 'Mở Google Maps',
            icon: Icons.navigation_outlined,
            onPressed: onOpenGoogleMaps,
          ),
        ],
      ),
    );
  }
}
