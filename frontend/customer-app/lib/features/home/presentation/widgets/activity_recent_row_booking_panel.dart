import 'package:caresitter_customer/core/widgets/caregiver_avatar.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ActivityRecentRowBookingPanel extends StatelessWidget {
  const ActivityRecentRowBookingPanel({super.key, required this.booking});
  final BookingModel booking;

  @override
  Widget build(BuildContext context) => CaregiverAvatar(
        radius: 22,
        avatarUrl: booking.caregiverAvatar,
        initials: booking.caregiverInitials,
      );
}
