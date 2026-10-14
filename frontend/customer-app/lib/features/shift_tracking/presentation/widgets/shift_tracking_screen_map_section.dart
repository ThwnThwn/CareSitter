import 'package:caresitter_customer/features/shift_tracking/presentation/controllers/shift_tracking_state.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/live_caregiver_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ShiftTrackingScreenMapSection extends StatelessWidget {
  const ShiftTrackingScreenMapSection(
      {super.key, required this.bk, required this.location});
  final BookingModel bk;
  final ShiftTrackingState location;
  @override
  Widget build(BuildContext context) {
    final lat = bk.addressLatitude;
    final lng = bk.addressLongitude;
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      return Container(
        color: AppColors.surfaceVariant,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: const Text('Chưa có tọa độ địa chỉ để hiển thị bản đồ.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    final enRoute = bk.status == 'caregiver_en_route';
    final stale = location.stale;
    return SizedBox(
      height: enRoute ? 320 : 260,
      child: LiveCaregiverMap(
        key: ValueKey(bk.id),
        destination: LatLng(lat, lng),
        caregiverPosition: enRoute
            ? (location.latitude == null
                ? null
                : LatLng(location.latitude!, location.longitude!))
            : null,
        heading: enRoute ? location.heading : null,
        stale: stale,
        locationLabel: enRoute ? location.label : 'Địa chỉ chăm sóc',
        addressLabel: bk.address,
      ),
    );
  }
}
