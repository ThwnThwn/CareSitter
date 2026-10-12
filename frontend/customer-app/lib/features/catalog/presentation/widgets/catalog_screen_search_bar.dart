import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class CatalogScreenSearchBar extends StatelessWidget {
  const CatalogScreenSearchBar(
      {super.key,
      required this.searchCtrl,
      required this.onChanged,
      required this.searchQuery});
  final TextEditingController searchCtrl;
  final ValueChanged<String> onChanged;
  final String searchQuery;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: TextField(
        controller: searchCtrl,
        onChanged: (v) => onChanged(v.trim()),
        style: const TextStyle(
          fontSize: AppFontSizes.s14,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Tìm kiếm dịch vụ...',
          hintStyle: const TextStyle(
              color: AppColors.textHint, fontSize: AppFontSizes.s14),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textHint,
            size: 20,
          ),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: AppColors.textHint),
                  onPressed: () {
                    searchCtrl.clear();
                    onChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}
