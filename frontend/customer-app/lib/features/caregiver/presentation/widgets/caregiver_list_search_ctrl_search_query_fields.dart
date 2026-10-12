import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_list_content.dart';
import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_list_filter_chip.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class CaregiverListSearchCtrlSearchQueryFields extends StatelessWidget {
  const CaregiverListSearchCtrlSearchQueryFields(
      {super.key,
      required this.ref,
      required this.searchCtrl,
      required this.searchQuery,
      required this.showAvailableOnly,
      required this.callbackAction1,
      required this.callbackAction2,
      required this.callbackAction3,
      required this.callbackAction4,
      required this.callbackAction5,
      required this.callbackAction6});
  final WidgetRef ref;
  final TextEditingController searchCtrl;
  final String searchQuery;
  final bool showAvailableOnly;
  final void Function() callbackAction1;
  final void Function(String) callbackAction2;
  final void Function(String) callbackAction3;
  final void Function() callbackAction4;
  final void Function() callbackAction5;
  final void Function() callbackAction6;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          CaregiverListContent(
              ref: ref, action1: callbackAction1, action2: callbackAction2),
          const SizedBox(height: AppSpacing.compact),
          // Search
          TextField(
            controller: searchCtrl,
            onChanged: callbackAction3,
            decoration: InputDecoration(
              hintText: 'Tìm theo tên hoặc Quận/Huyện...',
              prefixIcon: const Icon(Icons.search,
                  color: AppColors.textSecondary, size: 20),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          size: 18, color: AppColors.textHint),
                      onPressed: callbackAction4,
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surfaceVariant,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.inset, vertical: AppSpacing.compact),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
                borderSide: BorderSide.none,
              ),
              hintStyle: const TextStyle(
                  color: AppColors.textHint, fontSize: AppFontSizes.s14),
            ),
          ),
          const SizedBox(height: AppSpacing.control),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                CaregiverListFilterChip(
                  label: 'Tất cả trong khu vực',
                  isActive: !showAvailableOnly,
                  onTap: callbackAction5,
                ),
                const SizedBox(width: AppSpacing.sm),
                CaregiverListFilterChip(
                  label: 'Đang trực tuyến',
                  isActive: showAvailableOnly,
                  onTap: callbackAction6,
                ),
              ],
            ),
          ),
        ],
      );
}
