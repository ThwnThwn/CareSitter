import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BeneficiaryCreateAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  const BeneficiaryCreateAppBar(
      {super.key,
      required this.requestExit,
      required this.isSaving,
      required this.save});
  final void Function() requestExit;
  final bool isSaving;
  final Future<void> Function() save;
  @override
  Widget build(BuildContext context) => AppBar(
        title: const Text('Thêm người được hỗ trợ'),
        leading: AppCloseButton(
          fallbackRoute: '/beneficiaries',
          onPressed: requestExit,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: TextButton(
              onPressed: isSaving ? null : save,
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Lưu',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: AppFontSizes.s15),
                    ),
            ),
          ),
        ],
      );
}
