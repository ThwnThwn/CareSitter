import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';
import '../../data/models/auth_models.dart';
import '../controllers/registration_controller.dart';
import 'register_screen_error_banner.dart';
import 'registration_actions.dart';
import 'registration_contact_fields.dart';
import 'registration_credentials.dart';

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
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final success = await ref.read(registrationControllerProvider.notifier).submit(
          RegisterRequest(
            fullName: _name.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            password: _password.text,
            confirmPassword: _confirmation.text,
          ),
        );
    if (mounted && success) widget.onRegistered();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registrationControllerProvider);
    return Form(
      key: _formKey,
      child: Column(children: [
        if (state.error case final error?) ...[
          FadeSlideStaggered(
              index: 2, child: RegisterScreenErrorBanner(message: error)),
          const SizedBox(height: AppSpacing.md),
        ],
        RegistrationContactFields(
            name: _name, email: _email, phone: _phone, enabled: !state.busy),
        const SizedBox(height: AppSpacing.inset),
        RegistrationCredentials(
          password: _password,
          confirmation: _confirmation,
          enabled: !state.busy,
          onSubmit: _submit,
        ),
        const SizedBox(height: AppSpacing.section),
        RegistrationActions(
          state: state,
          onAgreementChanged: (value) =>
              ref.read(registrationControllerProvider.notifier).setAgreement(value),
          onSubmit: _submit,
        ),
      ]),
    );
  }
}
