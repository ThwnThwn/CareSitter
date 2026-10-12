import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';

class HomeGreeting extends StatelessWidget {
  const HomeGreeting({super.key, required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              profile.name.isNotEmpty ? profile.name : 'CareSitter',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFontSizes.s17,
                fontWeight: FontWeight.w800,
                height: 1.2,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: AppSpacing.micro),
            const Text(
              'Chăm sóc tận tâm cho người thân',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFontSizes.s11,
                fontWeight: FontWeight.w400,
                height: 1.3,
              ),
            ),
          ],
        ),
      );
}
