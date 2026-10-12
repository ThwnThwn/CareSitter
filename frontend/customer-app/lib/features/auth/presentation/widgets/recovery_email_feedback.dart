import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/recovery_email_controller.dart';

class RecoveryEmailFeedback extends StatelessWidget {
  const RecoveryEmailFeedback({super.key, required this.flow});
  final RecoveryEmailState flow;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.md),
            Semantics(
                liveRegion: true,
                child: Text(flow.message!,
                    style: const TextStyle(color: AppColors.primary))),
          ]);
}
