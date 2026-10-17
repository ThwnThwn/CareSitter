import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/widgets/app_widgets.dart';
import '../../data/models/shift_model.dart';
import '../controllers/shift_action_policy.dart';
import '../controllers/shift_list_controller.dart';
import '../widgets/shift_detail_app_bar.dart';
import '../widgets/shift_detail_missing_app_bar.dart';
import '../widgets/shift_detail_body.dart';
import '../widgets/shift_detail_start_travel_action.dart';

class ShiftDetailScreen extends ConsumerWidget {
  const ShiftDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shifts = ref.watch(shiftsProvider);
    ShiftModel? booking;
    for (final shift in shifts) {
      if (shift.id == id) {
        booking = shift;
        break;
      }
    }
    if (booking == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        appBar: ShiftDetailMissingAppBar(),
        body: AppEmptyState(
          icon: Icons.search_off_rounded,
          title: 'Không tìm thấy ca làm việc',
          message: 'Ca này có thể đã bị huỷ hoặc không còn tồn tại.',
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ShiftDetailAppBar(),
      body: Column(children: [
        Expanded(child: ShiftDetailBody(booking: booking)),
        if (booking.canStartEnRoute)
          ShiftDetailStartTravelAction(booking: booking),
        if (booking.statusType.index >= ShiftStatus.confirmed.index &&
            booking.statusType != ShiftStatus.completed &&
            booking.statusType != ShiftStatus.cancelled)
          _ChatButton(bookingId: booking.id),
      ]),
    );
  }
}
