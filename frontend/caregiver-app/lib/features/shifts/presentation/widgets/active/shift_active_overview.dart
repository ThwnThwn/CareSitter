import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/core/widgets/beneficiary_avatar.dart';

class ShiftActiveOverview extends StatelessWidget {
  const ShiftActiveOverview({super.key, required this.booking});

  final ShiftModel booking;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.compact),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.subtle,
        ),
        child: Row(
          children: [
            BeneficiaryAvatar(
              name: booking.beneficiaryName,
              age: booking.beneficiaryAge,
              gender: booking.beneficiaryGender,
              avatarUrl: booking.beneficiaryAvatarUrl,
              radius: 22,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _BeneficiaryIdentity(booking: booking)),
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              tooltip: 'Liên hệ gia đình',
              style: IconButton.styleFrom(
                minimumSize: const Size.square(44),
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.compact),
                ),
              ),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (sheetContext) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.section),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Liên hệ gia đình',
                          style: TextStyle(
                            fontSize: AppFontSizes.s18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'Ca này chưa có số điện thoại người nhà. Bạn có thể nhắn tin cho khách hàng.',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            context.push('/shifts/${booking.id}/chat');
                          },
                          icon: const Icon(Icons.chat_outlined),
                          label: const Text('Nhắn tin với khách hàng'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              icon: const Icon(Icons.call_outlined),
            ),
          ],
        ),
      );
}

class _BeneficiaryIdentity extends StatelessWidget {
  const _BeneficiaryIdentity({required this.booking});

  final ShiftModel booking;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                booking.beneficiaryName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppFontSizes.s14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (booking.beneficiaryAge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.tight,
                    vertical: AppSpacing.micro,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    '${booking.beneficiaryAge} tuổi',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: AppFontSizes.s11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (booking.address.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Row(
              children: [
                const Icon(Icons.location_on,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.xxs),
                Expanded(
                  child: Text(
                    booking.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppFontSizes.s11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
}
