import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class HomeHeroCaregiverSearch extends StatelessWidget {
  const HomeHeroCaregiverSearch(
      {super.key,
      required this.isNarrow,
      required this.caregiverSearchController,
      required this.openCaregiverSearch,
      required this.callbackAction1});
  final bool isNarrow;
  final TextEditingController caregiverSearchController;
  final void Function([String?]) openCaregiverSearch;
  final void Function(PointerDownEvent) callbackAction1;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: isNarrow ? 44 : 48,
        child: TextField(
          controller: caregiverSearchController,
          textInputAction: TextInputAction.search,
          onSubmitted: openCaregiverSearch,
          onTapOutside: callbackAction1,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppFontSizes.s13,
          ),
          decoration: const InputDecoration(
            hintText: 'Tìm người chăm sóc, kỹ năng, địa chỉ...',
            hintStyle: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFontSizes.s13,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
            filled: true,
            fillColor: AppInputStyle.fillColor,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 13),
            enabledBorder: AppInputStyle.enabledBorder,
            focusedBorder: AppInputStyle.focusedBorder,
          ),
        ),
      );
}
