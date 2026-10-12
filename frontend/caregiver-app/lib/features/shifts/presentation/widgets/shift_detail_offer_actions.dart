import 'package:caregiver_app/features/shifts/presentation/widgets/shift_decline_button.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_accept_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/widgets/app_toast.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';

class ShiftDetailOfferActions extends StatelessWidget {
  const ShiftDetailOfferActions(
      {super.key, required this.ref, required this.bookingId});
  final WidgetRef ref;
  final String bookingId;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ShiftDeclineButton(callbackAction1: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Từ chối ca?'),
              content:
                  const Text('Bạn có chắc muốn từ chối ca làm việc này không?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Không')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style:
                        TextButton.styleFrom(foregroundColor: AppColors.error),
                    child: const Text('Từ chối')),
              ],
            ),
          );
          if (confirmed != true) return;
          try {
            await ref.read(shiftsProvider.notifier).declineBooking(bookingId);
            if (context.mounted) {
              context.pop();
              AppToast.success(context, 'Đã từ chối ca làm việc này.');
            }
          } catch (e) {
            if (context.mounted) {
              AppToast.error(context, 'Chưa từ chối được ca: $e');
            }
          }
        }),
        const SizedBox(width: AppSpacing.compact),
        ShiftAcceptButton(callbackAction1: () async {
          try {
            await ref.read(shiftsProvider.notifier).acceptBooking(bookingId);
            if (context.mounted) {
              context.pop();
              AppToast.success(context,
                  '✅ Đã nhận ca thành công! Ca nằm trong Tab Sắp tới.');
            }
          } catch (e) {
            if (context.mounted) {
              AppToast.error(context, 'Lỗi nhận ca: $e');
            }
          }
        }),
      ],
    );
  }
}
