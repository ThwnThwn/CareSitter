import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../controllers/beneficiary_form_controller.dart';
import 'beneficiary_form_fields.dart';
import 'beneficiary_profile_app_bar.dart';
import 'beneficiary_form_avatar.dart';
import 'beneficiary_basic_information.dart';
import 'beneficiary_care_information.dart';
import 'beneficiary_emergency_contacts_editor.dart';

class BeneficiaryProfileForm extends ConsumerWidget {
  const BeneficiaryProfileForm({
    super.key,
    this.profileId,
    required this.fields,
    required this.formKey,
    required this.hasChanges,
    required this.onPickAvatar,
    required this.onSave,
  });
  final String? profileId;
  final BeneficiaryFormFields fields;
  final GlobalKey<FormState> formKey;
  final bool Function() hasChanges;
  final Future<void> Function() onPickAvatar, onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(beneficiaryFormControllerProvider(profileId));
    return DiscardChangesGuard(
      hasChanges: hasChanges,
      fallbackRoute: profileId == null
          ? AppRoutes.beneficiaries
          : AppRoutes.beneficiaryDetail(profileId!),
      builder: (context, requestExit) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: BeneficiaryProfileAppBar(
          profileId: profileId,
          saving: draft.saving,
          onExit: requestExit,
          onSave: onSave,
        ),
        body: AbsorbPointer(
          absorbing: draft.saving,
          child: Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                BeneficiaryFormAvatar(
                    avatarPath: draft.avatarPath,
                    pickImage: onPickAvatar,
                    editing: profileId != null),
                const SizedBox(height: AppSpacing.wide),
                BeneficiaryBasicInformation(
                    profileId: profileId, fields: fields),
                BeneficiaryCareInformation(
                    profileId: profileId, fields: fields),
                BeneficiaryEmergencyContactsEditor(contacts: fields.contacts),
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  onPressed: draft.saving ? null : onSave,
                  style:
                      ElevatedButton.styleFrom(minimumSize: const Size(0, 52)),
                  child: draft.saving
                      ? const CircularProgressIndicator()
                      : Text(profileId == null
                          ? 'Thêm người được chăm sóc'
                          : 'Lưu thay đổi'),
                ),
                const SizedBox(height: AppSpacing.formBottom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
