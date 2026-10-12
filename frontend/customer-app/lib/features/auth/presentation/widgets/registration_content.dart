import 'package:caresitter_customer/features/auth/presentation/widgets/registration_form_fields.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/registration_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';

class RegistrationContent extends StatelessWidget {
  const RegistrationContent(
      {super.key,
      required this.buildAppBar,
      required this.buildTitle,
      required this.ref,
      required this.buildErrorBanner,
      required this.formKey,
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
      required this.validatePassword,
      required this.confirmPassCtrl,
      required this.obscureConfirm,
      required this.validateConfirmPassword,
      required this.buildTermsRow,
      required this.buildRegisterButton,
      required this.buildLoginLink,
      required this.callbackAction1,
      required this.callbackAction2,
      required this.callbackAction3});
  final Widget Function() buildAppBar;
  final Widget Function() buildTitle;
  final WidgetRef ref;
  final Widget Function(String) buildErrorBanner;
  final GlobalKey<FormState> formKey;
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
  final String? Function(String?) validatePassword;
  final TextEditingController confirmPassCtrl;
  final bool obscureConfirm;
  final String? Function(String?) validateConfirmPassword;
  final Widget Function() buildTermsRow;
  final Widget Function() buildRegisterButton;
  final Widget Function() buildLoginLink;
  final void Function() callbackAction1;
  final void Function() callbackAction2;
  final void Function(String) callbackAction3;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── App Bar ──────────────────────────────────
              SliverToBoxAdapter(
                child: FadeSlideStaggered(
                  index: 0,
                  slideFromTop: true,
                  child: buildAppBar(),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.section, 0, AppSpacing.section, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Title
                    FadeSlideStaggered(
                      index: 1,
                      child: buildTitle(),
                    ),

                    // Error Banner
                    if (ref.watch(registrationControllerProvider).error !=
                        null) ...[
                      FadeSlideStaggered(
                        index: 2,
                        child: buildErrorBanner(
                            ref.watch(registrationControllerProvider).error!),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    Form(
                      key: formKey,
                      child: RegistrationFormFields(
                          buildField: buildField,
                          nameCtrl: nameCtrl,
                          validateName: validateName,
                          emailCtrl: emailCtrl,
                          validateEmail: validateEmail,
                          phoneCtrl: phoneCtrl,
                          validatePhone: validatePhone,
                          buildPasswordField: buildPasswordField,
                          passCtrl: passCtrl,
                          obscurePass: obscurePass,
                          callbackAction1: callbackAction1,
                          validatePassword: validatePassword,
                          confirmPassCtrl: confirmPassCtrl,
                          obscureConfirm: obscureConfirm,
                          callbackAction2: callbackAction2,
                          validateConfirmPassword: validateConfirmPassword,
                          callbackAction3: callbackAction3,
                          buildTermsRow: buildTermsRow,
                          buildRegisterButton: buildRegisterButton,
                          buildLoginLink: buildLoginLink),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      );
}
