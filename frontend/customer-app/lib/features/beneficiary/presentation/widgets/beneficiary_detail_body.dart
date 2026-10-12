import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_emergency_contact_tile.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_emergency_contacts.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';

class BeneficiaryDetailBody extends StatelessWidget {
  const BeneficiaryDetailBody({super.key, required this.b});
  final BeneficiaryModel b;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BeneficiaryEmergencyContacts(b: b),
            const SizedBox(height: AppSpacing.inset),
            ...b.emergencyContacts.asMap().entries.map((entry) {
              final i = entry.key;
              final c = entry.value;
              return Column(
                children: [
                  if (i > 0)
                    const Divider(height: 16, color: AppColors.divider),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: AppFontSizes.s14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.compact),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: const TextStyle(
                                fontSize: AppFontSizes.s14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.micro),
                            Text(
                              c.relationship,
                              style: const TextStyle(
                                fontSize: AppFontSizes.s12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      BeneficiaryEmergencyContactTile(c: c),
                    ],
                  ),
                ],
              );
            }),
          ],
        ),
      );
}
