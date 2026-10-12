import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_hover_button.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class HomeNearbyCaregiverHeader extends StatelessWidget {
  const HomeNearbyCaregiverHeader({super.key, required this.callbackAction1});
  final void Function() callbackAction1;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Chăm sóc viên gần bạn',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppFontSizes.s17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.xs),
                Icon(Icons.location_on_outlined,
                    size: 16, color: AppColors.primary),
              ],
            ),
          ),
          HomeHoverButton(
            onTap: callbackAction1,
            child: const Text(
              'Xem thêm',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: AppFontSizes.s13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
}
