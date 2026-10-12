import 'package:caresitter_customer/features/auth/presentation/widgets/registration_confirm_field.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/registration_name_field.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/registration_email_field.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/registration_password_field.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/registration_phone_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';

class RegistrationFormFields extends StatelessWidget {
  const RegistrationFormFields(
      {super.key,
      required this.buildField,
      required this.nameCtrl,
      required this.validateName,
      required this.emailCtrl,
      required this.validateEmail,
      required this.phoneCtrl,
      required this.validatePhone,
      required this.buildPasswordField,
      required this.passCtrl,
      required this.obscurePass,
      required this.callbackAction1,
      required this.validatePassword,
      required this.confirmPassCtrl,
      required this.obscureConfirm,
      required this.callbackAction2,
      required this.validateConfirmPassword,
      required this.callbackAction3,
      required this.buildTermsRow,
      required this.buildRegisterButton,
      required this.buildLoginLink});
  final Widget Function(
      {required TextEditingController controller,
      required String hint,
      required IconData icon,
      List<TextInputFormatter>? inputFormatters,
      TextInputType? keyboardType,
      required String label,
      Widget? prefixWidget,
      TextCapitalization textCapitalization,
      TextInputAction? textInputAction,
      String? Function(String?)? validator}) buildField;
  final TextEditingController nameCtrl;
  final String? Function(String?) validateName;
  final TextEditingController emailCtrl;
  final String? Function(String?) validateEmail;
  final TextEditingController phoneCtrl;
  final String? Function(String?) validatePhone;
  final Widget Function(
      {required TextEditingController controller,
      required String label,
      required bool obscure,
      void Function(String)? onSubmitted,
      required void Function() onToggle,
      TextInputAction? textInputAction,
      String? Function(String?)? validator}) buildPasswordField;
  final TextEditingController passCtrl;
  final bool obscurePass;
  final void Function() callbackAction1;
  final String? Function(String?) validatePassword;
  final TextEditingController confirmPassCtrl;
  final bool obscureConfirm;
  final void Function() callbackAction2;
  final String? Function(String?) validateConfirmPassword;
  final void Function(String) callbackAction3;
  final Widget Function() buildTermsRow;
  final Widget Function() buildRegisterButton;
  final Widget Function() buildLoginLink;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          // Full Name
          RegistrationNameField(
              buildField: buildField,
              nameCtrl: nameCtrl,
              validateName: validateName),
          const SizedBox(height: AppSpacing.inset),

          // Email
          RegistrationEmailField(
              buildField: buildField,
              emailCtrl: emailCtrl,
              validateEmail: validateEmail),
          const SizedBox(height: AppSpacing.inset),

          // Phone
          RegistrationPhoneField(
              buildField: buildField,
              phoneCtrl: phoneCtrl,
              validatePhone: validatePhone),
          const SizedBox(height: AppSpacing.inset),

          // Password
          RegistrationPasswordField(
              buildPasswordField: buildPasswordField,
              passCtrl: passCtrl,
              obscurePass: obscurePass,
              callbackAction1: callbackAction1,
              validatePassword: validatePassword),
          const SizedBox(height: AppSpacing.inset),

          // Confirm Password
          RegistrationConfirmField(
              buildPasswordField: buildPasswordField,
              confirmPassCtrl: confirmPassCtrl,
              obscureConfirm: obscureConfirm,
              callbackAction2: callbackAction2,
              validateConfirmPassword: validateConfirmPassword,
              callbackAction3: callbackAction3),
          const SizedBox(height: AppSpacing.section),

          // Terms checkbox
          FadeSlideStaggered(
            index: 7,
            child: buildTermsRow(),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Register Button
          FadeSlideStaggered(
            index: 8,
            child: buildRegisterButton(),
          ),
          const SizedBox(height: AppSpacing.section),

          // Login Link
          FadeSlideStaggered(
            index: 9,
            child: buildLoginLink(),
          ),
        ],
      );
}
