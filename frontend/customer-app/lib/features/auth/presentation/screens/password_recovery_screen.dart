import 'package:caresitter_customer/features/auth/presentation/widgets/password_recovery_form.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../widgets/password_recovery_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/password_recovery_controller.dart';

class PasswordRecoveryScreen extends ConsumerStatefulWidget {
  const PasswordRecoveryScreen({super.key});
  @override
  ConsumerState<PasswordRecoveryScreen> createState() =>
      _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState
    extends ConsumerState<PasswordRecoveryScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _hidden = true;
  @override
  void dispose() {
    for (final controller in [_email, _code, _password, _confirmation]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startOver() {
    ref.read(passwordRecoveryControllerProvider.notifier).restart();
    _code.clear();
    _password.clear();
    _confirmation.clear();
  }

  Future<void> _request({bool resend = false}) async {
    if (!resend && !_form.currentState!.validate()) return;
    final changed = await ref
        .read(passwordRecoveryControllerProvider.notifier)
        .request(_email.text, resend: resend);
    if (mounted && changed) {
      _code.clear();
      _password.clear();
      _confirmation.clear();
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (ref.read(passwordRecoveryControllerProvider).step == 0) {
      await _request();
      return;
    }
    final changed = await ref
        .read(passwordRecoveryControllerProvider.notifier)
        .submit(
            code: _code.text,
            password: _password.text,
            confirmation: _confirmation.text);
    if (!mounted || !changed) return;
    _code.clear();
    if (ref.read(passwordRecoveryControllerProvider).step == 3) {
      _password.clear();
      _confirmation.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(passwordRecoveryControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PasswordRecoveryAppBar(flow: flow),
      body: PasswordRecoveryForm(
          form: _form,
          flow: flow,
          email: _email,
          code: _code,
          password: _password,
          confirmation: _confirmation,
          hidden: _hidden,
          onRequest: _request,
          onSubmit: _submit,
          onStartOver: _startOver,
          onTogglePassword: () => setState(() => _hidden = !_hidden),
          onSignIn: () => context.go(AppRoutes.login)),
    );
  }
}
