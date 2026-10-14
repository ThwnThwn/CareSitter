import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';
import '../controllers/registration_state.dart';
import 'register_screen_terms_row.dart';
import 'register_screen_register_button.dart';
import 'register_screen_login_link.dart';

class RegistrationActions extends StatelessWidget {
  const RegistrationActions({
    super.key,
    required this.state,
    required this.onAgreementChanged,
    required this.onSubmit,
  });
  final RegistrationState state;
  final ValueChanged<bool> onAgreementChanged;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) => Column(children: [
        FadeSlideStaggered(
          index: 7,
          child: RegisterScreenTermsRow(
            agreedToTerms: state.agreed,
            onChanged: onAgreementChanged,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FadeSlideStaggered(
          index: 8,
          child: RegisterScreenRegisterButton(
              isLoading: state.busy, register: onSubmit),
        ),
        const SizedBox(height: AppSpacing.section),
        const FadeSlideStaggered(index: 9, child: RegisterScreenLoginLink()),
      ]);
}
