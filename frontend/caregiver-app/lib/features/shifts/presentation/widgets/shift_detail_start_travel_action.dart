import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/widgets/app_toast.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';

class ShiftDetailStartTravelAction extends ConsumerWidget {
  const ShiftDetailStartTravelAction({super.key, required this.booking});
  final ShiftModel booking;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.compact,
          AppSpacing.md, 12 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            'Khi bắt đầu đi, vị trí được chia sẻ với gia đình của ca này khi bạn mở app. Chia sẻ dừng khi check-in; vị trí được xóa khi ca kết thúc.',
            style: TextStyle(
                fontSize: AppFontSizes.s12, color: AppColors.textSecondary),
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () async {
              try {
                await ref
                    .read(shiftsProvider.notifier)
                    .startEnRoute(booking.id);
                if (!context.mounted) return;
                AppToast.success(
                    context, 'Đã chuyển trạng thái sang đang di chuyển.');
              } catch (error) {
                if (!context.mounted) return;
                AppToast.error(context, 'Chưa thể bắt đầu di chuyển: $error');
              }
            },
            icon: const Icon(Icons.directions_car_rounded,
                color: Colors.white, size: 20),
            label: const Text(
              'Bắt đầu đi và chia sẻ vị trí',
              style: TextStyle(
                  fontSize: AppFontSizes.s15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              elevation: 0,
            ),
          ),
        ),
      ]),
    );
  }
}
