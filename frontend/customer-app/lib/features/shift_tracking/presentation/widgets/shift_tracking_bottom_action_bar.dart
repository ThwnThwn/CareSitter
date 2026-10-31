import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_bottom_action_bar_fields.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_bottom_action_bar_fields_body.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_bottom_action_bar_fields_inner.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/app_toast.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_bottom_action_barconfirm_complete_booking_fields.dart';

class ShiftTrackingBottomActionBar extends ConsumerWidget {
  final BookingModel bk;
  final String bookingId;
  const ShiftTrackingBottomActionBar(
      {super.key, required this.bk, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    if (bk.status == 'checkout_pending_review') {
      return Container(
        padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.compact,
            AppSpacing.md, 12 + bottomPad * 0.5),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4))
          ],
        ),
        child: ShiftTrackingBottomActionBarFieldsBody(
            callbackAction1: () => _confirmComplete(context, ref, bk),
            callbackAction2: () =>
                context.push(AppRoutes.bookingDispute(bookingId))),
      );
    }

    if (bk.status == 'in_progress') {
      return Container(
        padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.control,
            AppSpacing.md, 10 + bottomPad * 0.5),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -3))
          ],
        ),
        child: const ShiftTrackingBottomActionBarFieldsInner(),
      );
    }

    if (bk.status == 'caregiver_en_route') {
      return Container(
        padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.compact,
            AppSpacing.md, 12 + bottomPad * 0.5),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ShiftTrackingBottomActionBarFields(
            callbackAction1: () =>
                context.push(AppRoutes.bookingChat(bookingId)),
            callbackAction2: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('⚠️ Đang kết nối tổng đài giám sát viên 24/7...'),
                    backgroundColor: AppColors.error,
                    duration: Duration(seconds: 2),
                  ),
                )),
      );
    }

    return const SizedBox.shrink();
  }

  void _confirmComplete(BuildContext context, WidgetRef ref, BookingModel bk) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline,
                color: AppColors.success, size: 26),
            SizedBox(width: AppSpacing.control),
            Text('Xác nhận hoàn thành',
                style: TextStyle(fontSize: AppFontSizes.s17)),
          ],
        ),
        content:
            ShiftTrackingBottomActionBarconfirmCompleteBookingFields(bk: bk),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Chưa',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () async {
              Navigator.pop(dCtx);
              AppToast.loading(context, 'Đang xác nhận hoàn tất ca…');
              try {
                await ref
                    .read(bookingStoreProvider.notifier)
                    .confirmCompleted(bk.id);
                if (!context.mounted) return;
                AppToast.success(
                    context, 'Ca chăm sóc đã được xác nhận hoàn tất.');
                popOrGo(context, fallbackRoute: AppRoutes.bookings);
              } catch (_) {
                if (!context.mounted) return;
                AppToast.error(
                    context, 'Không thể xác nhận lúc này. Vui lòng thử lại.');
              }
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }
}
