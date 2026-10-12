import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class BookingDetailShowMoreOptionsCtxStatusContent extends StatelessWidget {
  const BookingDetailShowMoreOptionsCtxStatusContent(
      {super.key,
      required this.ctx,
      required this.status,
      required this.confirmCancel,
      required this.booking});
  final BuildContext ctx;
  final String status;
  final Future<void> Function(BookingModel) confirmCancel;
  final BookingModel booking;
  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading:
                    const Icon(Icons.share_outlined, color: AppColors.primary),
                title: const Text('Chia sẻ lịch hẹn'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Đã sao chép thông tin lịch hẹn')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.print_outlined,
                    color: AppColors.textSecondary),
                title: const Text('In hóa đơn'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Tính năng in hóa đơn sẽ sớm ra mắt')),
                  );
                },
              ),
              if (const {
                'pending',
                'pending_payment',
                'payment_reconciliation_pending',
                'needs_manual_review',
                'confirmed',
                'caregiver_accepted',
                'assigned',
                'caregiver_en_route',
              }.contains(status))
                ListTile(
                  leading:
                      const Icon(Icons.cancel_outlined, color: AppColors.error),
                  title: const Text('Hủy lịch hẹn',
                      style: TextStyle(color: AppColors.error)),
                  onTap: () {
                    Navigator.pop(ctx);
                    confirmCancel(booking);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.help_outline,
                    color: AppColors.textSecondary),
                title: const Text('Liên hệ hỗ trợ'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Đang kết nối với bộ phận hỗ trợ...')),
                  );
                },
              ),
            ],
          ),
        ),
      );
}
