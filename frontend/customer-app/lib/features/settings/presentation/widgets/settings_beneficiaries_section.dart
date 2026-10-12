import 'package:caresitter_customer/features/settings/presentation/widgets/settings_beneficiary_list_link.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/settings_add_beneficiary_link.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/settings_beneficiary_title.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class SettingsBeneficiariesSection extends StatelessWidget {
  const SettingsBeneficiariesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsBeneficiaryTitle(),
        const SizedBox(height: AppSpacing.compact),
        SettingsBeneficiaryListLink(
            callbackAction1: () => context.push('/beneficiaries')),
        const SizedBox(height: AppSpacing.sm),
        SettingsAddBeneficiaryLink(
            callbackAction1: () => context.push('/beneficiaries/create')),
      ],
    );
  }
}
