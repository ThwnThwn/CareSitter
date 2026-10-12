import 'beneficiary_edit_basic_fields.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_edit_app_bar.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_edit_save_button.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_edit_add_contact_button.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_edit_notes_field.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_form_controller.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_edit_avatar.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_edit_contact_notice.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_contact_entry.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/catalog/data/models/address_model.dart';

class BeneficiaryEditForm extends StatelessWidget {
  const BeneficiaryEditForm(
      {super.key,
      required this.formController,
      required this.save,
      required this.formKey,
      required this.pickImage,
      required this.buildSectionHeader,
      required this.buildLabel,
      required this.nameCtrl,
      required this.birthDateCtrl,
      required this.genders,
      required this.buildDropdown,
      required this.relations,
      required this.careLevels,
      required this.buildTagInput,
      required this.conditionCtrl,
      required this.notesCtrl,
      required this.contacts,
      required this.buildContactCard,
      required this.routeId,
      required this.action1,
      required this.action2,
      required this.action3,
      required this.action4,
      required this.action5,
      required this.action6,
      required this.action7});
  final BeneficiaryFormController formController;
  final Future<void> Function() save;
  final GlobalKey<FormState> formKey;
  final Future<void> Function() pickImage;
  final Widget Function(String) buildSectionHeader;
  final Widget Function(String) buildLabel;
  final TextEditingController nameCtrl;
  final TextEditingController birthDateCtrl;
  final Map<String, String> genders;
  final Widget Function(List<String>, String, void Function(String?))
      buildDropdown;
  final List<String> relations;
  final List<String> careLevels;
  final Widget Function(
      {required TextEditingController ctrl,
      required String hint,
      required String label,
      required Color tagColor,
      required List<String> tags}) buildTagInput;
  final TextEditingController conditionCtrl;
  final TextEditingController notesCtrl;
  final List<BeneficiaryContactEntry> contacts;
  final Widget Function(int, BeneficiaryContactEntry) buildContactCard;
  final String routeId;
  final bool Function() action1;
  final String? Function(String?) action2;
  final void Function(String?) action3;
  final void Function(String?) action4;
  final void Function(AddressModel) action5;
  final void Function(String) action6;
  final void Function() action7;
  @override
  Widget build(BuildContext context) => DiscardChangesGuard(
        hasChanges: action1,
        fallbackRoute: '/beneficiaries/$routeId',
        builder: (context, requestExit) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: BeneficiaryEditAppBar(
              routeId: routeId,
              requestExit: requestExit,
              formController: formController,
              save: save),
          body: Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // Avatar edit section
                BeneficiaryEditAvatar(
                    avatarPath: formController.avatarPath,
                    pickImage: pickImage),
                const SizedBox(height: AppSpacing.wide),

                // ── THÔNG TIN CƠ BẢN ─────────────────────────────────
                BeneficiaryEditBasicFields(
                    formController: formController,
                    buildSectionHeader: buildSectionHeader,
                    buildLabel: buildLabel,
                    nameCtrl: nameCtrl,
                    birthDateCtrl: birthDateCtrl,
                    genders: genders,
                    buildDropdown: buildDropdown,
                    relations: relations,
                    careLevels: careLevels,
                    action2: action2,
                    action3: action3,
                    action4: action4,
                    action5: action5,
                    action6: action6),
                // ── THÔNG TIN CẦN BIẾT ─────────────────────────────────────
                buildSectionHeader('📋 Thông tin cần biết'),

                buildTagInput(
                  label: 'Nhu cầu hỗ trợ / Lưu ý',
                  hint:
                      'VD: Hay quên, khó di chuyển, cần đồng hành... nhấn + để thêm',
                  ctrl: conditionCtrl,
                  tags: formController.value.conditions,
                  tagColor: AppColors.info,
                ),
                const SizedBox(height: AppSpacing.md),

                buildLabel('Ghi chú đặc biệt cho người chăm sóc'),
                BeneficiaryEditNotesField(notesCtrl: notesCtrl),
                const SizedBox(height: AppSpacing.wide),

                // ── LIÊN HỆ KHẨN CẤP (FR-CUS-04) ────────────────────
                buildSectionHeader('🚨 Liên hệ khẩn cấp'),

                const BeneficiaryEditContactNotice(),

                ...contacts
                    .asMap()
                    .entries
                    .map((e) => buildContactCard(e.key, e.value)),

                BeneficiaryEditAddContactButton(action7: action7),
                const SizedBox(height: AppSpacing.xl),

                BeneficiaryEditSaveButton(
                    formController: formController, save: save),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      );
}
