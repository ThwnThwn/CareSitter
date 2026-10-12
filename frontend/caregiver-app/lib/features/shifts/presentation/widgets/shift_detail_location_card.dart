import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';

class ShiftDetailLocationCard extends StatelessWidget {
  const ShiftDetailLocationCard(
      {super.key,
      required this.destinationFor,
      required this.booking,
      required this.buildMapUnavailablePreview,
      required this.buildMapPreview,
      required this.openMap});
  final LatLng? Function(ShiftModel) destinationFor;
  final ShiftModel booking;
  final Widget Function() buildMapUnavailablePreview;
  final Widget Function(BuildContext, ShiftModel, LatLng) buildMapPreview;
  final void Function(BuildContext, ShiftModel) openMap;
  @override
  Widget build(BuildContext context) {
    final destination = destinationFor(booking);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.s15),
                topRight: Radius.circular(AppRadius.s15)),
            child: destination == null
                ? buildMapUnavailablePreview()
                : buildMapPreview(context, booking, destination),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.inset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.tight),
                    Expanded(
                      child: Text(booking.address,
                          style: const TextStyle(
                              fontSize: AppFontSizes.s13,
                              color: AppColors.textPrimary,
                              height: 1.4)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.control),
                GestureDetector(
                  onTap: () => openMap(context, booking),
                  child: const Row(
                    children: [
                      Icon(Icons.directions_rounded,
                          size: 16, color: AppColors.primary),
                      SizedBox(width: AppSpacing.tight),
                      Expanded(
                          child: Text('Xem chỉ đường trên bản đồ',
                              style: TextStyle(
                                  fontSize: AppFontSizes.s13,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600))),
                      Icon(Icons.chevron_right_rounded,
                          size: 16, color: AppColors.primary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
