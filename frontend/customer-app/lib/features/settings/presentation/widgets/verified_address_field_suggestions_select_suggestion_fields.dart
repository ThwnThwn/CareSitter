import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/address_controller.dart';

class VerifiedAddressFieldSuggestionsSelectSuggestionFields
    extends StatelessWidget {
  const VerifiedAddressFieldSuggestionsSelectSuggestionFields(
      {super.key, required this.suggestions, required this.selectSuggestion});
  final List<PlaceSuggestionModel> suggestions;
  final Future<void> Function(PlaceSuggestionModel) selectSuggestion;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Material(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < suggestions.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, color: AppColors.divider),
                      ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.place_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        title: Text(
                          suggestions[i].mainText.isEmpty
                              ? suggestions[i].description
                              : suggestions[i].mainText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: AppFontSizes.s13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          suggestions[i].secondaryText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: AppFontSizes.s12,
                          ),
                        ),
                        onTap: () => selectSuggestion(suggestions[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ]);
}
