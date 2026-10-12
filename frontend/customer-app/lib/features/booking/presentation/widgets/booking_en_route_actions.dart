import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class BookingEnRouteActions extends StatelessWidget {
  const BookingEnRouteActions(
      {super.key,
      required this.buildStatusBanner,
      required this.action3,
      required this.buildCancelButton,
      required this.ref,
      required this.booking});
  final Widget Function(String) buildStatusBanner;
  final void Function() action3;
  final Widget Function(BuildContext, WidgetRef, BookingModel)
      buildCancelButton;
  final WidgetRef ref;
  final BookingModel booking;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildStatusBanner(
                'Caregiver đang trên đường đến. Chờ caregiver GPS check-in tại địa điểm.'),
            const SizedBox(height: AppSpacing.control),
            ElevatedButton.icon(
              onPressed: action3,
              icon: const Icon(Icons.my_location_rounded),
              label: const Text('Xem vị trí trực tiếp 🚗'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor: AppColors.warning,
              ),
            ),
            const SizedBox(height: AppSpacing.control),
            buildCancelButton(context, ref, booking),
          ]);
}
