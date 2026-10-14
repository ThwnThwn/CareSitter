import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class LoginMethodToggle extends StatelessWidget {
  const LoginMethodToggle({
    super.key,
    required this.usePassword,
    required this.onChanged,
  });
  final bool usePassword;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(true),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.control),
                decoration: BoxDecoration(
                  color: usePassword ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.compact),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Mật khẩu',
                  style: TextStyle(
                    fontSize: AppFontSizes.s13,
                    fontWeight: FontWeight.w600,
                    color: usePassword ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(false),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.control),
                decoration: BoxDecoration(
                  color: !usePassword ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.compact),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Mã OTP',
                  style: TextStyle(
                    fontSize: AppFontSizes.s13,
                    fontWeight: FontWeight.w600,
                    color:
                        !usePassword ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}
