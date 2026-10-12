import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/widgets/app_widgets.dart';

class RegistrationSubmitActions extends StatelessWidget {
  const RegistrationSubmitActions(
      {super.key, required this.submitting, required this.onSubmit});
  final bool submitting;
  final VoidCallback onSubmit;
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton(
              label: 'Tạo tài khoản Caregiver',
              icon: Icons.person_add_alt_1_rounded,
              isLoading: submitting,
              onPressed: submitting ? null : onSubmit),
          const SizedBox(height: AppSpacing.compact),
          TextButton(
              onPressed: submitting ? null : () => context.go('/auth/phone'),
              child: const Text('Đã có tài khoản? Đăng nhập')),
        ],
      );
}
