import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../controllers/reports_controller.dart';

class ReportActions extends ConsumerWidget {
  const ReportActions(
      {super.key, required this.bookingId, required this.state});
  final String bookingId;
  final ReportState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(reportsControllerProvider(bookingId).notifier);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (state.busy) ...[
        LinearProgressIndicator(
            value: state.phase == ReportPhase.uploading ? state.progress : null,
            semanticsLabel: 'Tiến độ xử lý báo cáo'),
        const SizedBox(height: AppSpacing.sm),
        Semantics(liveRegion: true, child: Text(_status)),
        const SizedBox(height: AppSpacing.md),
      ],
      if (state.error != null) ...[
        Semantics(
            liveRegion: true,
            child: Text(state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: AppSpacing.md),
      ],
      if (state.reportId != null) ...[
        const Text('Đã lưu báo cáo thành công.'),
        const SizedBox(height: AppSpacing.md),
      ],
      FilledButton.icon(
          key: const ValueKey('generate-report'),
          onPressed: state.busy || state.uncertain ? null : controller.generate,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label:
              Text(state.hasDocument ? 'Tạo bản PDF mới' : 'Tạo báo cáo PDF')),
      if (state.hasDocument) ...[
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
            onPressed: state.busy ? null : () => controller.preview(),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Xem bản PDF')),
        const SizedBox(height: AppSpacing.sm),
        FilledButton.icon(
            key: const ValueKey('upload-report'),
            onPressed:
                state.busy || state.reportId != null ? null : controller.upload,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: Text(state.uncertain
                ? 'Kiểm tra và thử lại cùng tệp'
                : 'Lưu báo cáo lên đám mây')),
      ],
    ]);
  }

  String get _status => switch (state.phase) {
        ReportPhase.loading => 'Đang đọc bản PDF đã lưu…',
        ReportPhase.generating => 'Đang tạo báo cáo PDF…',
        ReportPhase.uploading =>
          'Đang gửi tệp ${(state.progress * 100).round()}%…',
        ReportPhase.processing => 'Đã gửi tệp. Máy chủ đang lưu báo cáo…',
        ReportPhase.previewing => 'Đang mở báo cáo…',
        ReportPhase.idle => '',
      };
}
