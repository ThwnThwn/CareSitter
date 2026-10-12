import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class FaqSearchField extends StatelessWidget {
  const FaqSearchField(
      {super.key,
      required this.searchController,
      required this.filterSearch,
      required this.callbackAction1});
  final TextEditingController searchController;
  final void Function(String) filterSearch;
  final void Function() callbackAction1;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: TextField(
          controller: searchController,
          onChanged: filterSearch,
          decoration: InputDecoration(
            hintText: 'Tìm kiếm câu hỏi...',
            prefixIcon:
                const Icon(Icons.search, color: AppColors.textSecondary),
            suffixIcon: searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: callbackAction1,
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      );
}
