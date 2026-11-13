import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/utils/date_formatter.dart';
import '../controllers/reports_controller.dart';

class ReportHistory extends ConsumerWidget {
  const ReportHistory({super.key, required this.bookingId});
  final String bookingId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(reportHistoryProvider(bookingId));
    final state = ref.watch(reportsControllerProvider(bookingId));
    final controller = ref.read(reportsControllerProvider(bookingId).notifier);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
            child: Text('Báo cáo đã gửi',
                style: Theme.of(context).textTheme.titleMedium)),
        IconButton(
            tooltip: 'Tải lại danh sách',
            onPressed: controller.refreshHistory,
            icon: const Icon(Icons.refresh)),
      ]),
      history.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text(
              'Chưa tải được danh sách. Nhấn tải lại để kiểm tra kết quả.'),
          data: (items) => Column(children: [
                if (items.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Text(
                          'Chưa có báo cáo ở trang này. Tạo PDF và lưu để bắt đầu.')),
                for (final item in items)
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(item.completed
                          ? Icons.description_outlined
                          : Icons.hourglass_top),
                      title: Text(item.completed
                          ? 'Báo cáo PDF'
                          : 'Đang đối soát upload'),
                      subtitle: Text(
                          '${formatDate(item.createdAt.toLocal())} • ${(item.sizeBytes / 1024).ceil()} KB'),
                      trailing: item.completed
                          ? IconButton(
                              tooltip: 'Mở báo cáo đã lưu',
                              onPressed: state.busy
                                  ? null
                                  : () => controller.preview(reportId: item.id),
                              icon: const Icon(Icons.visibility_outlined))
                          : null),
                Wrap(
                    spacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      TextButton(
                          onPressed: state.page > 1 && !state.busy
                              ? () => controller.changePage(state.page - 1)
                              : null,
                          child: const Text('Trang trước')),
                      Text('Trang ${state.page}'),
                      TextButton(
                          onPressed: items.length == 20 && !state.busy
                              ? () => controller.changePage(state.page + 1)
                              : null,
                          child: const Text('Trang sau')),
                    ]),
              ])),
    ]);
  }
}
