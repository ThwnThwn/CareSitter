import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import '../controllers/shift_tracking_controller.dart';
import '../models/shift_status_presentation.dart';
import '../widgets/shift_tracking_content.dart';
import '../widgets/shift_tracking_missing_state.dart';
import '../widgets/shift_tracking_screen_not_live_scaffold.dart';
import '../widgets/shift_extension_sheet.dart';

class ShiftTrackingScreen extends ConsumerStatefulWidget {
  final String bookingId;
  const ShiftTrackingScreen({super.key, required this.bookingId});

  @override
  ConsumerState<ShiftTrackingScreen> createState() =>
      _ShiftTrackingScreenState();
}

class _ShiftTrackingScreenState extends ConsumerState<ShiftTrackingScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = ModalRoute.of(context)?.isCurrent ?? true;
    Future.microtask(() {
      if (mounted) {
        ref
            .read(shiftTrackingControllerProvider(widget.bookingId).notifier)
            .setVisible(visible);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref
        .read(shiftTrackingControllerProvider(widget.bookingId).notifier)
        .setForeground(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location =
        ref.watch(shiftTrackingControllerProvider(widget.bookingId));
    final bookingId = widget.bookingId;
    final matches =
        ref.watch(bookingStoreProvider).where((b) => b.id == bookingId);
    if (matches.isEmpty) {
      return const ShiftTrackingMissingState();
    }
    final bk = matches.first;
    final now = DateTime.now();
    final presentationStatus = bk.presentationStatusAt(now);

    // Màn theo dõi trực tiếp mở cho cả caregiver_en_route (caregiver đang di chuyển) và
    // in_progress / checkout_pending_review (ca đang diễn ra). Các trạng thái khác
    // vẫn hiển thị trang thông báo rõ ràng.
    const liveStatuses = {
      'caregiver_en_route',
      'in_progress',
      'checkout_pending_review'
    };
    if (!liveStatuses.contains(presentationStatus)) {
      return ShiftTrackingScreenNotLiveScaffold(
          notLiveInfo: shiftNotLiveInfo,
          presentationStatus: presentationStatus,
          bk: bk);
    }

    return ShiftTrackingContent(
      bk: bk,
      location: location,
      onViewTimeline: () => context.push('/bookings/$bookingId/timeline'),
      onExtendShift: () => showShiftExtensionSheet(context, bk),
    );
  }
}
