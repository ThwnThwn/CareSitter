import 'package:caresitter_customer/features/auth/presentation/widgets/recovery_email_input_fields.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/recovery_email_code_step.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/recovery_email_feedback.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/recovery_email_submit_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/recovery_email_controller.dart';

class RecoveryEmailForm extends StatelessWidget {
  const RecoveryEmailForm(
      {super.key,
      required this.flow,
      required this.load,
      required this.form,
      required this.email,
      required this.callbackAction1,
      required this.changing,
      required this.password,
      required this.hidden,
      required this.callbackAction2,
      required this.callbackAction3,
      required this.code,
      required this.request,
      required this.ref,
      required this.confirm});
  final RecoveryEmailState flow;
  final Future<void> Function() load;
  final GlobalKey<FormState> form;
  final TextEditingController email;
  final void Function(String) callbackAction1;
  final bool changing;
  final TextEditingController password;
  final bool hidden;
  final void Function() callbackAction2;
  final String? Function(String?) callbackAction3;
  final TextEditingController code;
  final Future<void> Function({bool resend}) request;
  final WidgetRef ref;
  final Future<void> Function() confirm;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: flow.loading
                ? const LinearProgressIndicator()
                : flow.currentEmail == null
                    ? Column(children: [
                        Text(flow.error ?? 'Chưa tải được email.'),
                        TextButton(
                            onPressed: load, child: const Text('Tải lại')),
                      ])
                    : Form(
                        key: form,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Bảo vệ quyền đăng nhập',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: AppSpacing.compact),
                              const Text(
                                  'Xác minh email để có thể nhận mã khi quên mật khẩu. Email đăng nhập cũng là email khôi phục.'),
                              const SizedBox(height: AppSpacing.section),
                              Text(flow.currentEmail!,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                  flow.verified
                                      ? 'Đã xác minh'
                                      : 'Chưa xác minh',
                                  style: TextStyle(
                                      color: flow.verified
                                          ? AppColors.primary
                                          : AppColors.textSecondary)),
                              const SizedBox(height: AppSpacing.lg),
                              if (flow.challengeId == null)
                                RecoveryEmailInputFields(
                                    email: email,
                                    flow: flow,
                                    callbackAction1: callbackAction1,
                                    changing: changing,
                                    password: password,
                                    hidden: hidden,
                                    callbackAction2: callbackAction2,
                                    callbackAction3: callbackAction3)
                              else
                                RecoveryEmailCodeStep(
                                    email: email,
                                    code: code,
                                    flow: flow,
                                    request: request,
                                    ref: ref),
                              if (flow.error != null) ...[
                                const SizedBox(height: AppSpacing.md),
                                Semantics(
                                    liveRegion: true,
                                    child: Text(flow.error!,
                                        style: const TextStyle(
                                            color: AppColors.error))),
                              ],
                              if (flow.message != null)
                                RecoveryEmailFeedback(flow: flow),
                              const SizedBox(height: AppSpacing.lg),
                              RecoveryEmailSubmitButton(
                                  busy: flow.busy,
                                  challenge: flow.challengeId,
                                  expired: flow.expired,
                                  request: request,
                                  confirm: confirm),
                            ])),
          )));
}
