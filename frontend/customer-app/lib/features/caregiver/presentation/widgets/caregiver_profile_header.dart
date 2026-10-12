import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_profile_header_caregiver_content.dart';
import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_profile_header_button.dart';
import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_profile_favorite_button.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class CaregiverProfileHeader extends StatelessWidget {
  const CaregiverProfileHeader({super.key, required this.caregiver});
  final CaregiverModel caregiver;
  @override
  Widget build(BuildContext context) {
    final textScale =
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8).toDouble();
    final expandedHeight = 280 + ((textScale - 1) * 300);

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      leading: const AppBackButton(
        fallbackRoute: '/caregivers',
        color: Colors.white,
      ),
      actions: [
        CaregiverProfileFavoriteButton(caregiverName: caregiver.displayName),
        CaregiverProfileHeaderButton(callbackAction1: () {
          SharePlus.instance.share(
            ShareParams(
              text:
                  'Xem hồ sơ chăm sóc viên ${caregiver.displayName} trên CareSitter!\n'
                  'Đánh giá: ${caregiver.ratingAvg.toStringAsFixed(1)}/5 ⭐',
              subject: 'Hồ sơ Chăm sóc viên - ${caregiver.displayName}',
            ),
          );
        }),
      ],
      flexibleSpace:
          CaregiverProfileHeaderCaregiverContent(caregiver: caregiver),
    );
  }
}
