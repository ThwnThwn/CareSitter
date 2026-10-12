import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ActivityActiveCardBookingRow extends StatelessWidget {
  const ActivityActiveCardBookingRow({super.key, required this.booking});
  final BookingModel booking;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          // Pulsing dot indicator
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🟢', style: TextStyle(fontSize: AppFontSizes.s22)),
            ),
          ),
          const SizedBox(width: AppSpacing.inset),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ca đang diễn ra',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: AppFontSizes.s12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.micro),
                Text(
                  booking.caregiverName ?? 'Người chăm sóc',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppFontSizes.s17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Cho: ${booking.beneficiaryName ?? "Người thân"}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: AppFontSizes.s13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.compact),
            ),
            child: const Icon(Icons.chevron_right_rounded,
                color: Colors.white, size: 22),
          ),
        ],
      );
}
