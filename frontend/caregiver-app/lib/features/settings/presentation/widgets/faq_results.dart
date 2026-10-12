import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/settings/data/models/faq_item.dart';

class FaqResults extends StatelessWidget {
  const FaqResults({super.key, required this.filteredItems});
  final List<FaqItem> filteredItems;

  @override
  Widget build(BuildContext context) => Expanded(
        child: filteredItems.isEmpty
            ? const Center(
                child: Text(
                  'Không tìm thấy câu hỏi phù hợp',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.compact),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: ExpansionTile(
                        title: Text(
                          item.question,
                          style: const TextStyle(
                            fontSize: AppFontSizes.s14Point5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        iconColor: AppColors.primary,
                        collapsedIconColor: AppColors.textSecondary,
                        childrenPadding: const EdgeInsets.fromLTRB(
                            AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                        children: [
                          const Divider(height: 1),
                          const SizedBox(height: AppSpacing.compact),
                          Text(
                            item.answer,
                            style: const TextStyle(
                              fontSize: AppFontSizes.s13Point5,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      );
}
