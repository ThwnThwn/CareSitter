import 'package:caresitter_customer/features/home/presentation/widgets/home_hover_button.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class HomeHeroBookingButton extends StatelessWidget {
  const HomeHeroBookingButton(
      {super.key, required this.isNarrow, required this.callbackAction1});
  final bool isNarrow;
  final void Function() callbackAction1;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: HomeHoverButton(
          onTap: callbackAction1,
          child: Container(
            key: const Key('home-book-now-cta'),
            padding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 9 : AppSpacing.inset,
              vertical: isNarrow ? 9 : 11,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Đặt lịch ngay',
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isNarrow ? 10 : 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ],
            ),
          ),
        ),
      );
}
