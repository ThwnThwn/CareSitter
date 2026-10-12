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
          decoration: InputDecoration(
            hintText: 'Tìm người chăm sóc, kỹ năng, địa chỉ...',
            hintStyle: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFontSizes.s13,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
            suffixIcon: IconButton(
              tooltip: 'Mở bộ lọc chăm sóc viên',
              onPressed: openCaregiverSearch,
              icon: const Icon(
                Icons.tune_rounded,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(
                color: AppColors.primaryLight,
                width: 1.5,
              ),
            ),
          ),
        ),
      );
}
