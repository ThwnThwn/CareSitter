import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_form_controller.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BeneficiaryEditAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const BeneficiaryEditAppBar(
      {super.key,
      required this.routeId,
      required this.requestExit,
      required this.formController,
      required this.save});
  final String routeId;
  final void Function() requestExit;
  final BeneficiaryFormController formController;
  final Future<void> Function() save;
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) => AppBar(
        title: const Text('Chỉnh sửa hồ sơ'),
        leading: AppCloseButton(
          fallbackRoute: '/beneficiaries/$routeId',
          onPressed: requestExit,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: TextButton(
              onPressed: formController.value.saving ? null : save,
              child: formController.value.saving
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
