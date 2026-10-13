import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import '../controllers/registration_controller.dart';
import 'registration_intro.dart';
import 'registration_contact_fields.dart';
import 'registration_credentials.dart';
import 'registration_terms_choice.dart';
import 'registration_submit_actions.dart';

class RegistrationForm extends ConsumerStatefulWidget {
  const RegistrationForm({super.key, required this.onRegistered});
  final VoidCallback onRegistered;

  @override
  ConsumerState<RegistrationForm> createState() => _RegistrationFormState();
}

class _RegistrationFormState extends ConsumerState<RegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    for (final controller in [_name, _email, _phone, _password, _confirmation]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final success = await ref.read(registrationControllerProvider.notifier).submit(
          fullName: _name.text,
          email: _email.text,
          phone: _phone.text,
          password: _password.text,
          confirmPassword: _confirmation.text,
        );
    if (mounted && success) widget.onRegistered();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registrationControllerProvider);
    return Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.section, AppSpacing.lg, AppSpacing.xl),
          children: [
            const Icon(Icons.medical_services_rounded,
                color: AppColors.primary, size: 44),
            const SizedBox(height: AppSpacing.compact),
            const RegistrationIntro(),
            const SizedBox(height: AppSpacing.tight),
            const Text(
                'Tạo tài khoản trước, sau đó hoàn thiện hồ sơ và giấy tờ KYC.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
            const SizedBox(height: AppSpacing.lg),
            RegistrationContactFields(
                name: _name, email: _email, phone: _phone, enabled: !state.busy),
            const SizedBox(height: AppSpacing.md),
            RegistrationCredentials(
                password: _password,
                confirmation: _confirmation,
                enabled: !state.busy,
                onSubmit: _submit),
            const SizedBox(height: AppSpacing.md),
            RegistrationTermsChoice(
                agreed: state.agreed,
                submitting: state.busy,
                onChanged: (value) => ref
                    .read(registrationControllerProvider.notifier)
                    .setAgreement(value ?? false)),
            if (state.error case final error?) ...[
              const SizedBox(height: AppSpacing.xs),
              Semantics(
                  liveRegion: true,
                  child: Text(error,
                      style: const TextStyle(color: AppColors.error, height: 1.4))),
            ],
            const SizedBox(height: AppSpacing.section),
            RegistrationSubmitActions(submitting: state.busy, onSubmit: _submit),
          ],
        ));
  }
}
