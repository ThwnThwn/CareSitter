import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:caregiver_app/core/router/navigation_helpers.dart';
import 'package:caregiver_app/core/utils/date_formatter.dart';
import '../controllers/shift_report_provider.dart';
import '../widgets/shift_read_state.dart';
import 'shift_customer_report_screen.dart';
import 'shift_summary_screen.dart';

class ShiftReportPage extends ConsumerWidget {
  const ShiftReportPage(
      {super.key, required this.id, this.customerReport = false});

  final String id;
  final bool customerReport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(shiftReportProvider(id));
    final report =
        result.isLoading || result.hasError ? null : result.valueOrNull;
    if (report == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Tổng kết ca'),
          leading: const AppBackButton(fallbackRoute: '/shifts'),
        ),
        body: result is AsyncData<ShiftReport?> && !result.isLoading
            ? Center(
                child: TextButton(
                  onPressed: () => context.go('/shifts/$id'),
                  child: const Text('Ca chưa có tổng kết. Xem chi tiết ca'),
                ),
              )
            : ShiftReadState(
                error: result.error,
                onRetry: () => ref.invalidate(shiftReportProvider(id)),
              ),
      );
    }
    final booking = report.booking;
    final start = booking.actualStart;
    final end = booking.checkoutRequestedAt;
    final duration = start == null || end == null || end.isBefore(start)
        ? 'Chưa có thời lượng'
        : _durationLabel(end.difference(start));
    final completed = booking.tasks.where((task) => task.isCompleted).length;
    if (customerReport) {
      return ShiftCustomerReportScreen(
        bookingId: id,
        beneficiaryName: booking.beneficiaryName,
        caregiverName: booking.caregiverName,
        caregiverEarning: booking.caregiverEarning,
        completedTasks: completed,
        totalTasks: booking.tasks.length,
        duration: duration,
        checkInTime: start == null ? 'Chưa có' : formatClock(start),
        checkOutTime: end == null ? 'Chưa có' : formatClock(end),
        caregiverNote: report.note,
        taskPhotos:
            booking.tasks.expand((task) => task.photoUrls).toSet().toList(),
      );
    }
    return ShiftSummaryScreen(
      bookingId: id,
      beneficiaryName: booking.beneficiaryName,
      caregiverEarning: booking.caregiverEarning,
      completedTasks: completed,
      totalTasks: booking.tasks.length,
      duration: duration,
      checkoutPendingReview: booking.status == 'checkout_pending_review',
    );
  }

  static String _durationLabel(Duration duration) {
    final minutes = duration.inMinutes % 60;
    if (duration.inHours == 0) return '$minutes phút';
    if (minutes == 0) return '${duration.inHours} giờ';
    return '${duration.inHours} giờ $minutes phút';
  }
}
