import 'package:caregiver_app/features/shifts/presentation/widgets/map/shift_map_distance_summary.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/map/shift_map_location_status.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/map/shift_map_address.dart';
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
          ShiftMapDistanceSummary(distanceLabel: distanceLabel),
          switch (status) {
            LocationLoading() => const Padding(
                padding: EdgeInsets.only(top: AppSpacing.control),
                child: LinearProgressIndicator(),
              ),
            LocationFailed(:final message) => ShiftMapLocationStatus(
                message: message, onRetryLocation: onRetryLocation),
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
          ShiftMapAddress(address: address),
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
