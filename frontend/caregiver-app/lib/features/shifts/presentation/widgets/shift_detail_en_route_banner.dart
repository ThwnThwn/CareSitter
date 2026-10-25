import 'package:caregiver_app/features/shifts/presentation/widgets/shift_en_route_check_in_button.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_en_route_heading.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_en_route_status.dart';
import 'package:caregiver_app/core/error/app_exception.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/live_tracking_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/widgets/app_toast.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';

class ShiftDetailEnRouteBanner extends ConsumerStatefulWidget {
  const ShiftDetailEnRouteBanner({super.key, required this.booking});
  final ShiftModel booking;

  @override
  ConsumerState<ShiftDetailEnRouteBanner> createState() =>
      _ShiftDetailEnRouteBannerState();
}

class _ShiftDetailEnRouteBannerState
    extends ConsumerState<ShiftDetailEnRouteBanner> {
  bool _checkingIn = false;

  @override
  Widget build(BuildContext context) {
    final tracking = ref.watch(liveTrackingProvider);
    final isThisBooking = tracking.bookingId == widget.booking.id;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShiftEnRouteHeading(),
          const SizedBox(height: AppSpacing.tight),
          ShiftEnRouteStatus(isThisBooking: isThisBooking, tracking: tracking),
          const Text(
            'Vị trí chỉ chia sẻ với gia đình khi mở ứng dụng và dừng khi check-in.',
            style: TextStyle(
              fontSize: AppFontSizes.s13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (!isThisBooking || !tracking.sending)
            TextButton.icon(
              onPressed: () => ref
                  .read(liveTrackingProvider.notifier)
                  .start(widget.booking.id),
              icon: const Icon(Icons.my_location),
              label: const Text('Bật / thử lại chia sẻ vị trí'),
            ),
          const SizedBox(height: AppSpacing.inset),
          ShiftEnRouteCheckInButton(
            isBusy: _checkingIn,
            callbackAction1: _checkIn,
          ),
        ],
      ),
    );
  }

  Future<void> _checkIn() async {
    if (_checkingIn) return;
    setState(() => _checkingIn = true);
    AppToast.info(
      context,
      'Đang lấy vị trí GPS để check-in. Vui lòng giữ ứng dụng mở.',
      title: 'Đang xác thực vị trí',
    );

    Object? failure;
    try {
      await ref.read(shiftsProvider.notifier).checkIn(widget.booking.id);
    } catch (error) {
      failure = error;
    }

    if (!mounted) return;
    setState(() => _checkingIn = false);
    if (failure != null) {
      final message =
          failure is AppException ? failure.message : failure.toString();
      AppToast.error(
        context,
        message,
        title: 'Check-in chưa thành công',
      );
      return;
    }

    context.pushReplacement('/shifts/${widget.booking.id}/active');
    AppToast.success(context, 'Check-in thành công');
  }
}
