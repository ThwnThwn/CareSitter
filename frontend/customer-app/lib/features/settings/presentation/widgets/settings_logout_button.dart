import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/auth_session_controller.dart';

class SettingsLogoutButton extends ConsumerWidget {
  const SettingsLogoutButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Đăng xuất'),
              content: const Text('Bạn có chắc muốn đăng xuất khỏi tài khoản?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Hủy')),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await ref.read(authSessionControllerProvider).logout();
                    if (context.mounted) context.go('/auth/login');
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      minimumSize: const Size(80, 40)),
                  child: const Text('Đăng xuất'),
                ),
              ],
            ),
          );
        },
        icon: const Icon(Icons.logout_rounded,
            color: AppColors.legacyError, size: 18),
        label: const Text('Đăng xuất',
            style: TextStyle(
                color: AppColors.legacyError,
                fontSize: AppFontSizes.s15,
                fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.legacyError, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.control)),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.inset),
        ),
      ),
    );
  }
}
