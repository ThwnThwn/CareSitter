import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_list_has_location_all_caregivers_content.dart';
import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_list_unread_count_content.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class CaregiverListTopPaddingHasLocationPanel extends StatelessWidget {
  const CaregiverListTopPaddingHasLocationPanel(
      {super.key,
      required this.topPadding,
      required this.hasLocation,
      required this.allCaregivers,
      required this.unreadCount});
  final double topPadding;
  final bool hasLocation;
  final List<CaregiverModel> allCaregivers;
  final int unreadCount;
  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        padding: EdgeInsets.only(
          top: topPadding + 16,
          left: AppSpacing.section,
          right: AppSpacing.md,
          bottom: 0,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CaregiverListHasLocationAllCaregiversContent(
                hasLocation: hasLocation, allCaregivers: allCaregivers),
            CaregiverListUnreadCountContent(unreadCount: unreadCount),
          ],
        ),
      );
}
