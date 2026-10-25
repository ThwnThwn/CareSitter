import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BeneficiaryProfileAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const BeneficiaryProfileAppBar({
    super.key,
    this.profileId,
    required this.saving,
    required this.onExit,
    required this.onSave,
  });
  final String? profileId;
  final bool saving;
  final VoidCallback onExit;
  final Future<void> Function() onSave;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
        title: Text(
            profileId == null ? 'Thêm người được hỗ trợ' : 'Chỉnh sửa hồ sơ'),
        leading: AppCloseButton(
          fallbackRoute: profileId == null
              ? AppRoutes.beneficiaries
              : AppRoutes.beneficiaryDetail(profileId!),
          onPressed: onExit,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: TextButton(
              onPressed: saving ? null : onSave,
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Lưu'),
            ),
          ),
        ],
      );
}
