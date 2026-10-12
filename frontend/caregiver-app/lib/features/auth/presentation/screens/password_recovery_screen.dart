import 'package:caregiver_app/features/auth/presentation/widgets/password_recovery_content.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/password_recovery_controller.dart';

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
  void initState() {
    super.initState();
    ref.listenManual(
        authStateProvider.select((session) => (
              session.value?.userId,
              session.value?.isAuthenticated
            )), (previous, next) {
      if (previous == next) return;
      for (final controller in [_email, _code, _password, _confirmation]) {
        controller.clear();
      }
    });
  }

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

  String? _validatePassword(String? value) {
    if (value == null ||
        value.length < 8 ||
        value.toLowerCase() == value ||
        !RegExp(r'[0-9]').hasMatch(value)) {
      return 'Cần ít nhất 8 ký tự, một chữ hoa và một chữ số.';
    }
    if (utf8.encode(value).length > 72) {
      return 'Mật khẩu quá dài (tối đa 72 byte).';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(passwordRecoveryControllerProvider);
    final title = [
      'Quên mật khẩu',
      'Xác minh email',
      'Đặt mật khẩu mới',
      'Đã đổi mật khẩu'
    ][flow.step];
    return PasswordRecoveryContent(
        flow: flow,
        form: _form,
        title: title,
        email: _email,
        code: _code,
        request: _request,
        password: _password,
        hidden: _hidden,
        validatePassword: _validatePassword,
        confirmation: _confirmation,
        submit: _submit,
        startOver: _startOver,
        callbackAction1: (_) => _submit(),
        callbackAction2: (value) => value != null &&
                RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
            ? null
            : 'Vui lòng nhập email hợp lệ.',
        callbackAction6: (_) => _submit(),
        callbackAction7: (value) =>
            value?.length == 6 ? null : 'Nhập đủ 6 chữ số.',
        callbackAction8: () => setState(() => _hidden = !_hidden),
        callbackAction9: (value) =>
            value == _password.text ? null : 'Mật khẩu xác nhận chưa khớp.',
        callbackAction10: (_) => _submit(),
        callbackAction11: () => context.go('/auth/phone'));
  }
}
