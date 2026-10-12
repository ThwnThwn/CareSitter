import 'package:caregiver_app/features/auth/presentation/widgets/registration_password_fields.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/registration_phone_field.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/registration_terms_choice.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/registration_name_field.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/registration_email_field.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/registration_intro.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/registration_submit_actions.dart';
import 'package:caregiver_app/core/router/navigation_helpers.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class RegistrationContent extends StatelessWidget {
  const RegistrationContent(
      {super.key,
      required this.formKey,
      required this.nameController,
      required this.requiredName,
      required this.emailController,
      required this.validEmail,
      required this.phoneController,
      required this.validPhone,
      required this.passwordField,
      required this.passwordController,
      required this.hidePassword,
      required this.validPassword,
      required this.confirmController,
      required this.hideConfirmation,
      required this.agreed,
      required this.submitting,
      required this.error,
      required this.register,
      required this.callbackAction2,
      required this.callbackAction3,
      required this.callbackAction7,
      required this.callbackAction8,
      required this.callbackAction9});
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final String? Function(String?) requiredName;
  final TextEditingController emailController;
  final String? Function(String?) validEmail;
  final TextEditingController phoneController;
  final String? Function(String?) validPhone;
  final Widget Function(
      {required TextEditingController controller,
      required bool hidden,
      required String label,
      void Function(String)? onSubmitted,
      required void Function() onToggle,
      required String? Function(String?) validator}) passwordField;
  final TextEditingController passwordController;
  final bool hidePassword;
  final String? Function(String?) validPassword;
  final TextEditingController confirmController;
  final bool hideConfirmation;
  final bool agreed;
  final bool submitting;
  final String? error;
  final Future<void> Function() register;
  final void Function() callbackAction2;
  final String? Function(String?) callbackAction3;
  final void Function() callbackAction7;
  final void Function(String) callbackAction8;
  final void Function(bool?) callbackAction9;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Đăng ký Caregiver'),
          leading: const AppBackButton(fallbackRoute: '/auth/phone'),
        ),
        body: SafeArea(
          top: false,
          child: Form(
            key: formKey,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                  AppSpacing.section, AppSpacing.lg, AppSpacing.xl),
              children: [
                const Icon(Icons.medical_services_rounded,
                    color: AppColors.primary, size: 44),
                const SizedBox(height: AppSpacing.compact),
                const RegistrationIntro(),
                const SizedBox(height: AppSpacing.tight),
                const Text(
                  'Tạo tài khoản trước, sau đó hoàn thiện hồ sơ và giấy tờ KYC.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: AppSpacing.lg),
                RegistrationNameField(
                    nameController: nameController, requiredName: requiredName),
                const SizedBox(height: AppSpacing.md),
                RegistrationEmailField(
                    emailController: emailController, validEmail: validEmail),
                const SizedBox(height: AppSpacing.md),
                RegistrationPhoneField(
                    phoneController: phoneController, validPhone: validPhone),
                const SizedBox(height: AppSpacing.md),
                passwordField(
                  controller: passwordController,
                  label: 'Mật khẩu',
                  hidden: hidePassword,
                  validator: validPassword,
                  onToggle: callbackAction2,
                ),
                const SizedBox(height: AppSpacing.md),
                RegistrationPasswordFields(
                    passwordField: passwordField,
                    confirmController: confirmController,
                    hideConfirmation: hideConfirmation,
                    callbackAction4: callbackAction3,
                    callbackAction5: callbackAction7,
                    callbackAction6: callbackAction8),
                const SizedBox(height: AppSpacing.md),
                RegistrationTermsChoice(
                    agreed: agreed,
                    submitting: submitting,
                    callbackAction1: callbackAction9),
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error!,
                      style:
                          const TextStyle(color: AppColors.error, height: 1.4),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.section),
                RegistrationSubmitActions(
                    submitting: submitting, onSubmit: register),
              ],
            ),
          ),
        ),
      );
}
