import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'shift_detail_map_preview.dart';
import 'shift_detail_map_unavailable.dart';
import 'package:latlong2/latlong.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';

class ShiftDetailLocationCard extends StatelessWidget {
  const ShiftDetailLocationCard({super.key, required this.booking});
  final ShiftModel booking;

  LatLng? get destination {
    final latitude = booking.addressLatitude;
    final longitude = booking.addressLongitude;
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return null;
    }
    return LatLng(latitude, longitude);
  }

  void _openMap(BuildContext context, ShiftModel booking) {
    context.push('/shifts/${booking.id}/map', extra: {
      'beneficiaryName': booking.beneficiaryName,
      'address': booking.address,
      'addressLatitude': booking.addressLatitude,
      'addressLongitude': booking.addressLongitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    final target = destination;
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
            child: target == null
                ? const ShiftDetailMapUnavailable()
                : ShiftDetailMapPreview(
                    destination: target, booking: booking, openMap: _openMap),
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
                  onTap: () => _openMap(context, booking),
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
