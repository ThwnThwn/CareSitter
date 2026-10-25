import 'package:caresitter_customer/features/auth/presentation/widgets/recovery_email_content.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/recovery_email_controller.dart';

class RecoveryEmailScreen extends ConsumerStatefulWidget {
  const RecoveryEmailScreen({super.key});
  @override
  ConsumerState<RecoveryEmailScreen> createState() =>
      _RecoveryEmailScreenState();
}

class _RecoveryEmailScreenState extends ConsumerState<RecoveryEmailScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _hidden = true;
  bool _emailSeeded = false;
  @override
  void initState() {
    super.initState();
    final auth = ref.read(authStateProvider.notifier);
    ref.listenManual(
        authStateProvider.select((session) => (
              session.valueOrNull?.userId,
              session.valueOrNull?.isAuthenticated,
              auth.sessionGeneration,
            )), (previous, next) {
      if (previous == next) return;
      _emailSeeded = false;
      _email.clear();
      _password.clear();
      _code.clear();
      _hidden = true;
    });
    ref.listenManual(recoveryEmailControllerProvider, (_, flow) {
      if (!_emailSeeded && !flow.loading && flow.currentEmail != null) {
        _email.text = flow.currentEmail!;
        _emailSeeded = true;
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    for (final controller in [_email, _password, _code]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() =>
      ref.read(recoveryEmailControllerProvider.notifier).load();
  Future<void> _request({bool resend = false}) async {
    if (!resend && !_form.currentState!.validate()) return;
    final changed = await ref
        .read(recoveryEmailControllerProvider.notifier)
        .request(_email.text, _password.text, resend: resend);
    if (mounted && changed) _code.clear();
  }

  Future<void> _confirm() async {
    if (!_form.currentState!.validate()) return;
    final result = await ref
        .read(recoveryEmailControllerProvider.notifier)
        .confirm(_code.text);
    if (!mounted || result == RecoveryEmailResult.ignored) return;
    _password.clear();
    _code.clear();
    if (result == RecoveryEmailResult.signIn) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(recoveryEmailControllerProvider);
    final changing = flow.currentEmail != null &&
        _email.text.trim().toLowerCase() != flow.currentEmail;
    return RecoveryEmailContent(
        flow: flow,
        onReload: _load,
        form: _form,
        email: _email,
        changing: changing,
        password: _password,
        hidden: _hidden,
        code: _code,
        onRequest: _request,
        onConfirm: _confirm,
        onEmailChanged: (_) => setState(() {
              ref
                  .read(recoveryEmailControllerProvider.notifier)
                  .dismissMessage();
            }),
        onTogglePassword: () => setState(() => _hidden = !_hidden));
  }
}
