import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

enum _NutritionEntryStateKind { loading, error, empty }

class NutritionEntryState extends StatelessWidget {
  const NutritionEntryState.loading({super.key})
      : _kind = _NutritionEntryStateKind.loading,
        onAction = null;

  const NutritionEntryState.error({super.key, required this.onAction})
      : _kind = _NutritionEntryStateKind.error;

  const NutritionEntryState.empty({super.key, required this.onAction})
      : _kind = _NutritionEntryStateKind.empty;

  final _NutritionEntryStateKind _kind;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    if (_kind == _NutritionEntryStateKind.loading) {
      return const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Đang tải hồ sơ người thân',
        ),
      );
    }
    final isError = _kind == _NutritionEntryStateKind.error;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.comfortable),
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError
                    ? Icons.cloud_off_outlined
                    : Icons.restaurant_menu_rounded,
                size: 42,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              isError ? 'Chưa tải được hồ sơ' : 'Chưa có hồ sơ để lập thực đơn',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              isError
                  ? 'Kiểm tra kết nối rồi thử lại để chọn người lập thực đơn.'
                  : 'Tạo hồ sơ cho bạn hoặc người thân, sau đó bổ sung thông tin cần thiết để nhận gợi ý.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFontSizes.s13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (isError)
              OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              )
            else
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Tạo hồ sơ đầu tiên'),
              ),
          ],
        ),
      ),
    );
  }
}
