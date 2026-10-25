import 'booking_detail_screen_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BookingEnRouteActions extends StatelessWidget {
  const BookingEnRouteActions({
    super.key,
    required this.onTrack,
    required this.cancelButton,
  });
  final void Function() onTrack;
  final Widget cancelButton;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BookingDetailScreenStatusBanner(
                message:
                    'Caregiver đang trên đường đến. Chờ caregiver GPS check-in tại địa điểm.'),
            const SizedBox(height: AppSpacing.control),
            ElevatedButton.icon(
              onPressed: onTrack,
              icon: const Icon(Icons.my_location_rounded),
              label: const Text('Xem vị trí trực tiếp'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor: AppColors.warning,
              ),
            ),
            const SizedBox(height: AppSpacing.control),
            cancelButton,
          ]);
}
