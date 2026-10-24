import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:go_router/go_router.dart';

/// Entry points for managing people who receive care.
class SettingsBeneficiariesSection extends StatelessWidget {
  const SettingsBeneficiariesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(),
        const SizedBox(height: 10),
        _BeneficiaryListLink(onTap: () => context.push(AppRoutes.beneficiaries)),
        const SizedBox(height: 10),
        _AddBeneficiaryButton(
          onTap: () => context.push(AppRoutes.beneficiaryNew),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            const Row(
              children: [
                _HeadingIcon(),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'NGƯỜI THÂN ĐƯỢC CHĂM SÓC',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppFontSizes.s12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDCF2EC)),
              ),
              child: const Text(
                'Thông tin chăm sóc',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: AppFontSizes.s11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

class _HeadingIcon extends StatelessWidget {
  const _HeadingIcon();

  @override
  Widget build(BuildContext context) => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFFDCF2EC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.volunteer_activism_outlined,
          size: 16,
          color: AppColors.primary,
        ),
      );
}

class _BeneficiaryListLink extends StatelessWidget {
  const _BeneficiaryListLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFF1F5F4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDCF2EC)),
                  ),
                  child: const Icon(
                    Icons.groups_outlined,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Xem danh sách người thân',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppFontSizes.s14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Quản lý thông tin sức khỏe & lưu ý chăm sóc',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppFontSizes.s12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textHint,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      );
}

class _AddBeneficiaryButton extends StatelessWidget {
  const _AddBeneficiaryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
        label: const Text('Thêm người thân mới'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: AppColors.primary,
          backgroundColor: const Color(0xFFF0F9F6),
          side: const BorderSide(color: Color(0xFF7ECBB9), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: AppFontSizes.s14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
