import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/widgets/app_widgets.dart';

/// Trạng thái ca không có tọa độ địa điểm.
class ShiftMapNoCoordinates extends StatelessWidget {
  final VoidCallback onOpenGoogleMaps;

  const ShiftMapNoCoordinates({
    super.key,
    required this.onOpenGoogleMaps,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AppEmptyState(
            icon: Icons.location_off_outlined,
            title: 'Chưa có tọa độ địa điểm',
            message: 'Bạn vẫn có thể mở địa chỉ khách hàng bằng Google Maps.',
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
