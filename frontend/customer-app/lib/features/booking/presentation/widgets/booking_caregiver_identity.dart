import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class BookingCaregiverIdentity extends StatelessWidget {
  const BookingCaregiverIdentity(
      {super.key,
      required this.avatarUrl,
      required this.buildCaregiverInitials,
      required this.booking,
      required this.caregiverName});
  final String? avatarUrl;
  final Widget Function(BookingModel) buildCaregiverInitials;
  final BookingModel booking;
  final String caregiverName;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar with verified badge (matching Stitch)
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: avatarUrl?.startsWith('http') == true
                    ? Image.network(
                        avatarUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            buildCaregiverInitials(booking),
                      )
                    : buildCaregiverInitials(booking),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.inset),
          // Name, title, and badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caregiverName,
                  style: const TextStyle(
                    fontSize: AppFontSizes.s17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.micro),
                const Text(
                  'Chăm sóc viên CareSitter',
                  style: TextStyle(
                    fontSize: AppFontSizes.s13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.tight),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (booking.caregiverName == null)
                      const Text(
                        'Thông tin hồ sơ đang cập nhật',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppFontSizes.s11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
}
