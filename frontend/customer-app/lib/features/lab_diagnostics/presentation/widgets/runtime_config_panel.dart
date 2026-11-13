import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/runtime_config/runtime_config_controller.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class RuntimeConfigPanel extends ConsumerWidget {
  const RuntimeConfigPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(runtimeConfigControllerProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Divider(),
      Text('Remote Config', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.sm),
      Text(
          'Banner danh mục: ${state.config.catalogBannerEnabled ? 'bật' : 'tắt'}'),
      Text('Dịch vụ mỗi trang: ${state.config.catalogPageSize}'),
      Text('Nguồn đang dùng: ${state.config.source}'),
      if (state.error != null) Text(state.error!),
      const SizedBox(height: AppSpacing.sm),
      OutlinedButton(
          onPressed: state.fetching
              ? null
              : () =>
                  ref.read(runtimeConfigControllerProvider.notifier).refresh(),
          child:
              Text(state.fetching ? 'Đang tải…' : 'Tải và áp dụng cấu hình')),
      const Text(
          'Bản debug tải tối đa mỗi 30 giây; bản release tối thiểu 12 giờ. '
          'Mở danh mục để quan sát thay đổi banner và phân trang.'),
    ]);
  }
}
