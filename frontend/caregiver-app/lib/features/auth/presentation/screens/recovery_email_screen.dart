import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/auth/data/repositories/recovery_repository.dart';

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
  String? _currentEmail, _error, _message;
  bool _verified = false,
      _hasPassword = false,
      _loading = true,
      _busy = false,
      _hidden = true;
  RecoveryChallenge? _challenge;
  DateTime? _resendAt, _expiresAt;
  Timer? _timer;
  int get _remaining => _resendAt == null
      ? 0
      : (_resendAt!.difference(DateTime.now()).inMilliseconds / 1000)
          .ceil()
          .clamp(0, 3600);
  bool get _changing =>
      _currentEmail != null &&
      _email.text.trim().toLowerCase() != _currentEmail;
  bool get _expired =>
      _expiresAt != null && !DateTime.now().isBefore(_expiresAt!);
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in [_email, _password, _code]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await ref.read(recoveryRepositoryProvider).profile();
      if (!mounted) return;
      setState(() {
        _currentEmail = profile['email'] as String;
        _email.text = _currentEmail!;
        _verified = profile['emailVerifiedAt'] != null;
        _hasPassword = profile['hasPassword'] == true;
      });
    } catch (error) {
      if (mounted) setState(() => _error = recoveryError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _request({bool resend = false}) async {
    if (_busy || (resend && _remaining > 0)) return;
    if (!resend && !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final challenge = await ref
          .read(recoveryRepositoryProvider)
          .requestEmail(_email.text, _changing ? _password.text : null);
      if (!mounted) return;
      _timer?.cancel();
      setState(() {
        _challenge = challenge;
        _code.clear();
        _resendAt =
            DateTime.now().add(Duration(seconds: challenge.resendAfter));
        _expiresAt = DateTime.now().add(Duration(seconds: challenge.expiresIn));
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

  Future<void> _confirm() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_expired) {
      setState(() => _error = 'Mã đã hết hạn. Hãy gửi lại mã.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(recoveryRepositoryProvider)
          .confirmEmail(_challenge!.id, _code.text);
      if (!mounted) return;
      _timer?.cancel();
      _password.clear();
      _code.clear();
      if (response['sessionsRevoked'] == true) {
        await ref.read(authStateProvider.notifier).logout();
        if (mounted) context.go('/auth/phone');
        return;
      }
      setState(() {
        _currentEmail = response['email'] as String;
        _verified = true;
        _challenge = null;
        _message =
            'Email đã được xác minh. Bạn có thể dùng email này để khôi phục mật khẩu.';
      });
    } catch (error) {
      if (mounted) setState(() => _error = recoveryError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
            title: const Text('Email khôi phục'),
            leading: IconButton(
                tooltip: 'Về cài đặt',
                icon: const Icon(Icons.arrow_back),
                onPressed: _busy
                    ? null
                    : () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/settings');
                        }
                      })),
        body: SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: _loading
                          ? const LinearProgressIndicator()
                          : _currentEmail == null
                              ? Column(children: [
                                  Text(_error ?? 'Chưa tải được email.'),
                                  TextButton(
                                      onPressed: _load,
                                      child: const Text('Tải lại')),
                                ])
                              : Form(
                                  key: _form,
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text('Bảo vệ quyền đăng nhập',
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineSmall
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w700)),
                                        const SizedBox(height: 12),
                                        const Text(
                                            'Xác minh email để có thể nhận mã khi quên mật khẩu. Email đăng nhập cũng là email khôi phục.'),
                                        const SizedBox(height: 20),
                                        Text(_currentEmail!,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Text(
                                            _verified
                                                ? 'Đã xác minh'
                                                : 'Chưa xác minh',
                                            style: TextStyle(
                                                color: _verified
                                                    ? AppColors.primary
                                                    : AppColors.textSecondary)),
                                        const SizedBox(height: 24),
                                        if (_challenge == null) ...[
                                          TextFormField(
                                              key: const ValueKey(
                                                  'profile-recovery-email'),
                                              controller: _email,
                                              enabled: !_busy,
                                              readOnly: !_hasPassword,
                                              onChanged: (_) => setState(() {
                                                    _message = null;
                                                  }),
                                              keyboardType:
                                                  TextInputType.emailAddress,
                                              decoration: const InputDecoration(
                                                  labelText:
                                                      'Email cần xác minh'),
                                              validator: (value) => value !=
                                                          null &&
                                                      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                                          .hasMatch(
                                                              value.trim())
                                                  ? null
                                                  : 'Vui lòng nhập email hợp lệ.'),
                                          if (_changing) ...[
                                            const SizedBox(height: 16),
                                            TextFormField(
                                                controller: _password,
                                                enabled: !_busy,
                                                obscureText: _hidden,
                                                decoration: InputDecoration(
                                                    labelText:
                                                        'Mật khẩu hiện tại',
                                                    suffixIcon: IconButton(
                                                        tooltip: _hidden
                                                            ? 'Hiện mật khẩu'
                                                            : 'Ẩn mật khẩu',
                                                        onPressed: () =>
                                                            setState(() =>
                                                                _hidden =
                                                                    !_hidden),
                                                        icon: Icon(_hidden
                                                            ? Icons
                                                                .visibility_outlined
                                                            : Icons
                                                                .visibility_off_outlined))),
                                                validator: (value) => value ==
                                                            null ||
                                                        value.isEmpty
                                                    ? 'Nhập mật khẩu hiện tại để đổi email.'
                                                    : null),
                                            const SizedBox(height: 12),
                                            const Text(
                                                'Email chỉ thay đổi sau khi nhập đúng mã gửi tới email mới. Sau đó mọi phiên sẽ bị thu hồi và bạn cần đăng nhập lại.'),
                                          ],
                                          if (!_hasPassword) ...[
                                            const SizedBox(height: 12),
                                            const Text(
                                                'Tài khoản chỉ dùng Google/OTP có thể xác minh email hiện tại. Việc đổi email cần liên hệ đơn vị hỗ trợ.',
                                                style: TextStyle(
                                                    color: AppColors
                                                        .textSecondary)),
                                          ],
                                        ] else ...[
                                          Text(
                                              'Mã đã được yêu cầu gửi tới ${_email.text.trim()}.'),
                                          const SizedBox(height: 16),
                                          TextFormField(
                                              key: const ValueKey(
                                                  'profile-email-code'),
                                              controller: _code,
                                              enabled: !_busy && !_expired,
                                              keyboardType:
                                                  TextInputType.number,
                                              maxLength: 6,
                                              autofillHints: const [
                                                AutofillHints.oneTimeCode
                                              ],
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly
                                              ],
                                              decoration: const InputDecoration(
                                                  labelText: 'Mã gồm 6 chữ số'),
                                              validator: (value) =>
                                                  value?.length == 6
                                                      ? null
                                                      : 'Nhập đủ 6 chữ số.'),
                                          if (_expired)
                                            const Text(
                                                'Mã đã hết hạn. Hãy gửi lại mã.'),
                                          TextButton(
                                              onPressed: _busy || _remaining > 0
                                                  ? null
                                                  : () =>
                                                      _request(resend: true),
                                              child: Text(_remaining > 0
                                                  ? 'Gửi lại sau ${_remaining}s'
                                                  : 'Gửi lại mã')),
                                          TextButton(
                                              onPressed: _busy
                                                  ? null
                                                  : () {
                                                      _timer?.cancel();
                                                      setState(() {
                                                        _challenge = null;
                                                        _code.clear();
                                                        _error = null;
                                                      });
                                                    },
                                              child:
                                                  const Text('Đổi thông tin')),
                                        ],
                                        if (_error != null) ...[
                                          const SizedBox(height: 16),
                                          Semantics(
                                              liveRegion: true,
                                              child: Text(_error!,
                                                  style: const TextStyle(
                                                      color: AppColors.error))),
                                        ],
                                        if (_message != null) ...[
                                          const SizedBox(height: 16),
                                          Semantics(
                                              liveRegion: true,
                                              child: Text(_message!,
                                                  style: const TextStyle(
                                                      color:
                                                          AppColors.primary))),
                                        ],
                                        const SizedBox(height: 24),
                                        FilledButton(
                                            onPressed: _busy ||
                                                    (_challenge != null &&
                                                        _expired)
                                                ? null
                                                : _challenge == null
                                                    ? _request
                                                    : _confirm,
                                            child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 14),
                                                child: _busy
                                                    ? const SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child:
                                                            CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                                color: Colors
                                                                    .white))
                                                    : Text(_challenge == null
                                                        ? 'Gửi mã xác minh'
                                                        : 'Xác minh email'))),
                                      ])),
                    )))),
      );
}
