import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/recovery_email_controller.dart';

class RecoveryEmailChangeAction extends ConsumerWidget {
  const RecoveryEmailChangeAction(
      {super.key, required this.flow, required this.code});
  final RecoveryEmailState flow;
  final TextEditingController code;

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton(
      onPressed: flow.busy
          ? null
          : () {
              ref.read(recoveryEmailControllerProvider.notifier).changeInfo();
              code.clear();
            },
      child: const Text('Đổi thông tin'));
}
