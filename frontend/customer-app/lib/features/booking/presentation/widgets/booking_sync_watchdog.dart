import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

/// Widget wrapping tree để quản lý vòng đời sync booking:
/// - Polling 30s khi app foreground
/// - Trigger sync ngay khi app resume từ background
/// - Dừng polling khi app inactive/paused/detached
///
/// Đặt bao ngoài widget tree trong home hoặc scaffold chính của app,
/// chỉ khi user đã authenticated.
///
/// ```dart
/// home: BookingSyncWatchdog(child: HomeScreen()),
/// ```
class BookingSyncWatchdog extends ConsumerStatefulWidget {
  const BookingSyncWatchdog({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BookingSyncWatchdog> createState() =>
      _BookingSyncWatchdogState();
}

class _BookingSyncWatchdogState extends ConsumerState<BookingSyncWatchdog>
    with WidgetsBindingObserver {
  Timer? _pollTimer;

  /// Khoảng thời gian polling khi app foreground.
  static const _pollInterval = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Delay nhỏ để đảm bảo provider tree đã sẵn sàng trước khi sync lần đầu.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _startPolling();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    switch (lifecycleState) {
      case AppLifecycleState.resumed:
        // Sync ngay khi quay lại app — bù đắp khoảng thời gian background.
        _triggerSyncIfAuth();
        _startPolling();

      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _stopPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      _triggerSyncIfAuth();
    });
  }

  void _stopPolling() => _pollTimer?.cancel();

  void _triggerSyncIfAuth() {
    final isAuth = ref.read(authStateProvider).value?.isAuthenticated ?? false;
    if (!isAuth) return;
    // Gọi requestSync — mutex trong BookingStore đảm bảo không có request trùng.
    ref.read(bookingStoreProvider.notifier).requestSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
