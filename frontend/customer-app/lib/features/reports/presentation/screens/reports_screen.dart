import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../controllers/reports_controller.dart';
import '../widgets/report_actions.dart';
import '../widgets/report_history.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key, required this.bookingId});
  final String bookingId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportsControllerProvider(bookingId));
    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo lịch hẹn')),
      body: SafeArea(
          child:
              ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
        Text('Tổng hợp thông tin lịch hẹn',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        const Text(
            'Tạo bản PDF để xem và lưu riêng tư. Chủ tài khoản và Admin có quyền đọc báo cáo.'),
        const SizedBox(height: AppSpacing.lg),
        ReportActions(bookingId: bookingId, state: state),
        const SizedBox(height: AppSpacing.lg),
        ReportHistory(bookingId: bookingId),
      ])),
    );
  }
}
