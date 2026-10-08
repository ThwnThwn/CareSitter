import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/data/repositories/recovery_repository.dart';

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
  RecoveryChallenge? _challenge;
  RecoveryGrant? _grant;
  DateTime? _resendAt, _codeExpiresAt, _grantExpiresAt;
  Timer? _timer;
  int _step = 0;
  bool _busy = false, _hidden = true;
  String? _error;
  int get _remaining => _resendAt == null
      ? 0
      : (_resendAt!.difference(DateTime.now()).inMilliseconds / 1000)
          .ceil()
          .clamp(0, 3600);
  bool get _expired =>
      _codeExpiresAt != null && !DateTime.now().isBefore(_codeExpiresAt!);
  @override
  void dispose() {
    _timer?.cancel();
    _grant = null;
    for (final controller in [_email, _code, _password, _confirmation]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startOver() {
    _timer?.cancel();
    setState(() {
      _step = 0;
      _error = null;
      _challenge = null;
      _grant = null;
      _code.clear();
      _password.clear();
      _confirmation.clear();
    });
  }

  Future<void> _request({bool resend = false}) async {
    if (_busy || (resend && _remaining > 0)) return;
    if (!resend && !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final challenge =
          await ref.read(recoveryRepositoryProvider).request(_email.text);
      if (!mounted) return;
      _timer?.cancel();
      setState(() {
        _challenge = challenge;
        _step = 1;
        _code.clear();
        _grant = null;
        _resendAt =
            DateTime.now().add(Duration(seconds: challenge.resendAfter));
        _codeExpiresAt =
            DateTime.now().add(Duration(seconds: challenge.expiresIn));
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } catch (error) {
      if (mounted) setState(() => _error = recoveryError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_step == 0) {
      await _request();
      return;
    }
    if (_step == 1 && _expired) {
      setState(() => _error = 'Mã đã hết hạn. Hãy gửi lại mã.');
      return;
    }
    if (_step == 2 && !DateTime.now().isBefore(_grantExpiresAt!)) {
      setState(
          () => _error = 'Thời gian đặt mật khẩu đã hết. Hãy bắt đầu lại.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = ref.read(recoveryRepositoryProvider);
      if (_step == 1) {
        final grant =
            await repository.verify(_challenge!.id, _code.text.trim());
        if (!mounted) return;
        setState(() {
          _grant = grant;
          _grantExpiresAt =
              DateTime.now().add(Duration(seconds: grant.expiresIn));
          _step = 2;
          _code.clear();
        });
      } else {
        await repository.reset(
            _grant!.token, _password.text, _confirmation.text);
        if (!mounted) return;
        _timer?.cancel();
        setState(() {
          _step = 3;
          _grant = null;
          _password.clear();
          _confirmation.clear();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = recoveryError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
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
    final title = [
      'Quên mật khẩu',
      'Xác minh email',
      'Đặt mật khẩu mới',
      'Đã đổi mật khẩu'
    ][_step];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          title: const Text('Khôi phục mật khẩu'),
          leading: IconButton(
              tooltip: 'Về đăng nhập',
              icon: const Icon(Icons.arrow_back),
              onPressed: _busy
                  ? null
                  : () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/auth/login');
                      }
                    })),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: AutofillGroup(
                    child: Form(
                        key: _form,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_step < 3) ...[
                                Text('Bước ${_step + 1} / 3',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary)),
                                const SizedBox(height: 12),
                              ],
                              Text(title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 12),
                              if (_step == 0) ...[
                                const Text(
                                    'Nhập email đã xác minh với CareSitter để nhận mã khôi phục.'),
                                const SizedBox(height: 24),
                                TextFormField(
                                    key: const ValueKey('recovery-email'),
                                    controller: _email,
                                    enabled: !_busy,
                                    keyboardType: TextInputType.emailAddress,
                                    autofillHints: const [AutofillHints.email],
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _submit(),
                                    decoration: const InputDecoration(
                                        labelText: 'Email khôi phục',
                                        prefixIcon: Icon(Icons.email_outlined)),
                                    validator: (value) => value != null &&
                                            RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                                .hasMatch(value.trim())
                                        ? null
                                        : 'Vui lòng nhập email hợp lệ.'),
                                const SizedBox(height: 16),
                                const Text(
                                    'Chưa xác minh email? Đăng nhập bằng mã email trước để xác minh. Nếu mất quyền truy cập email, cần liên hệ đơn vị hỗ trợ.',
                                    style: TextStyle(
                                        color: AppColors.textSecondary)),
                                TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => context.go('/auth/email'),
                                    child:
                                        const Text('Đăng nhập bằng mã email')),
                              ],
                              if (_step == 1) ...[
                                Text(_challenge!.message),
                                const SizedBox(height: 8),
                                Text(_email.text.trim(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 24),
                                TextFormField(
                                    key: const ValueKey('recovery-code'),
                                    controller: _code,
                                    enabled: !_busy && !_expired,
                                    keyboardType: TextInputType.number,
                                    autofillHints: const [
                                      AutofillHints.oneTimeCode
                                    ],
                                    maxLength: 6,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    decoration: const InputDecoration(
                                        labelText: 'Mã gồm 6 chữ số'),
                                    onFieldSubmitted: (_) => _submit(),
                                    validator: (value) => value?.length == 6
                                        ? null
                                        : 'Nhập đủ 6 chữ số.'),
                                Text(
                                    _expired
                                        ? 'Mã đã hết hạn. Hãy gửi lại mã.'
                                        : 'Mã có hiệu lực ${(_challenge!.expiresIn / 60).ceil()} phút.',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary)),
                                TextButton(
                                    onPressed: _busy || _remaining > 0
                                        ? null
                                        : () => _request(resend: true),
                                    child: Text(_remaining > 0
                                        ? 'Gửi lại sau ${_remaining}s'
                                        : 'Gửi lại mã')),
                              ],
                              if (_step == 2) ...[
                                const Text(
                                    'Mật khẩu mới cần ít nhất 8 ký tự, một chữ hoa và một chữ số. Mọi thiết bị sẽ cần đăng nhập lại.'),
                                const SizedBox(height: 24),
                                TextFormField(
                                    key: const ValueKey('recovery-password'),
                                    controller: _password,
                                    enabled: !_busy,
                                    obscureText: _hidden,
                                    autofillHints: const [
                                      AutofillHints.newPassword
                                    ],
                                    validator: _validatePassword,
                                    decoration: InputDecoration(
                                        labelText: 'Mật khẩu mới',
                                        suffixIcon: IconButton(
                                            tooltip: _hidden
                                                ? 'Hiện mật khẩu'
                                                : 'Ẩn mật khẩu',
                                            onPressed: () => setState(
                                                () => _hidden = !_hidden),
                                            icon: Icon(_hidden
                                                ? Icons.visibility_outlined
                                                : Icons
                                                    .visibility_off_outlined)))),
                                const SizedBox(height: 16),
                                TextFormField(
                                    key:
                                        const ValueKey('recovery-confirmation'),
                                    controller: _confirmation,
                                    enabled: !_busy,
                                    obscureText: _hidden,
                                    textInputAction: TextInputAction.done,
                                    autofillHints: const [
                                      AutofillHints.newPassword
                                    ],
                                    decoration: const InputDecoration(
                                        labelText: 'Xác nhận mật khẩu mới'),
                                    validator: (value) =>
                                        value == _password.text
                                            ? null
                                            : 'Mật khẩu xác nhận chưa khớp.',
                                    onFieldSubmitted: (_) => _submit()),
                              ],
                              if (_step == 3) ...[
                                const Icon(Icons.check_circle_outline,
                                    size: 56, color: AppColors.primary),
                                const SizedBox(height: 16),
                                const Text(
                                    'Mật khẩu đã được thay đổi và mọi phiên đăng nhập cũ đã bị thu hồi. Hãy đăng nhập bằng mật khẩu mới.'),
                                const SizedBox(height: 24),
                                FilledButton(
                                    onPressed: () => context.go('/auth/login'),
                                    child: const Text('Về đăng nhập')),
                              ],
                              if (_error != null) ...[
                                const SizedBox(height: 16),
                                Semantics(
                                    liveRegion: true,
                                    child: Text(_error!,
                                        style: const TextStyle(
                                            color: AppColors.error))),
                              ],
                              if (_step < 3) ...[
                                const SizedBox(height: 24),
                                FilledButton(
                                    onPressed: _busy || (_step == 1 && _expired)
                                        ? null
                                        : _submit,
                                    child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        child: _busy
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white))
                                            : Text([
                                                'Gửi mã khôi phục',
                                                'Xác minh mã',
                                                'Đặt mật khẩu mới'
                                              ][_step]))),
                                if (_step > 0)
                                  TextButton(
                                      onPressed: _busy ? null : _startOver,
                                      child: Text(_step == 1
                                          ? 'Đổi email'
                                          : 'Bắt đầu lại')),
                                const SizedBox(height: 16),
                                const Text(
                                    'Đổi mật khẩu không mở khóa tài khoản bị admin khóa.',
                                    style: TextStyle(
                                        color: AppColors.textSecondary)),
                              ],
                            ]))),
              )),
        ),
      ),
    );
  }
}
