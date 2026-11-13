import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/diagnostics/crash_reporter.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/confirm_action_dialog.dart';
import '../controllers/lab_diagnostics_controller.dart';

class CrashDemoPanel extends ConsumerWidget {
  const CrashDemoPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(labDiagnosticsControllerProvider);
    final ready = ref.watch(crashReporterProvider).available;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Crashlytics trên thiết bị thật',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.md),
      Text(ready
          ? 'SDK đã khởi tạo. Sau crash, mở lại app và chờ báo cáo trên Firebase và web Admin.'
          : 'Crashlytics chưa sẵn sàng. Kiểm tra cấu hình Firebase native và bản build.'),
      const SizedBox(height: AppSpacing.lg),
      OutlinedButton(
          onPressed: ready && !state.isLoading
              ? () => ref
                  .read(labDiagnosticsControllerProvider.notifier)
                  .trigger(fatal: false)
              : null,
          child: const Text('Ghi lỗi nonfatal thử nghiệm')),
      const SizedBox(height: AppSpacing.md),
      FilledButton(
          onPressed: ready && !state.isLoading
              ? () async {
                  final confirmed = await showConfirmActionDialog(context,
                      title: 'Tạo crash thật?',
                      message:
                          'Ứng dụng sẽ đóng ngay. Hãy hoàn tất thao tác đang làm trước khi tiếp tục.',
                      confirmLabel: 'Tạo crash');
                  if (!confirmed || !context.mounted) return;
                  await ref
                      .read(labDiagnosticsControllerProvider.notifier)
                      .trigger(fatal: true);
                }
              : null,
          child: const Text('Tạo crash thật')),
      if (state.isLoading) const LinearProgressIndicator(),
      if (state.hasError)
        const Text(
            'Chưa gửi được thao tác thử nghiệm. Vui lòng kiểm tra cấu hình và thử lại.'),
      if (state.valueOrNull != null) ...[
        const SizedBox(height: AppSpacing.md),
        const Text(
            'SDK đã ghi nhận thao tác. Chờ đối chiếu báo cáo Firebase bằng mã lần thử.'),
        SelectableText(state.valueOrNull!),
      ],
    ]);
  }
}
