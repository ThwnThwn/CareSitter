import 'package:caresitter_customer/features/home/presentation/widgets/home_rebook_card_content.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';

class HomeRebookCard extends StatelessWidget {
  const HomeRebookCard({super.key, required this.booking});
  final BookingModel booking;
  @override
  Widget build(BuildContext context) {
    final name = booking.caregiverName?.trim() ?? 'Chăm sóc viên';
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase())
        .take(2)
        .join();
    final textScale =
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3).toDouble();

    return Container(
      width: 160 * textScale,
      constraints: const BoxConstraints(minHeight: 164),
      padding: const EdgeInsets.all(AppSpacing.inset),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: AppShadows.card,
      ),
      child: HomeRebookCardContent(
          initials: initials,
          name: name,
          booking: booking,
          callbackAction1: () => context.push(
            AppRoutes.bookingNewWith(
              serviceId: booking.serviceTypeId,
            ),
          )),
    );
  }
}
