import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme/app_theme.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class NotificationPrefs {
  final bool bookingUpdates;
  final bool paymentUpdates;
  final bool caregiverArriving;
  final bool scheduleReminder;
  final bool chatMessage;
  final bool promotion;

  const NotificationPrefs({
    this.bookingUpdates = true,
    this.paymentUpdates = true,
    this.caregiverArriving = true,
    this.scheduleReminder = true,
    this.chatMessage = true,
    this.promotion = false,
  });

  factory NotificationPrefs.fromJson(Map<String, dynamic> json) {
    return NotificationPrefs(
      bookingUpdates:
          (json['bookingUpdates'] ?? json['BookingUpdates'] ?? true) == true,
      paymentUpdates:
          (json['paymentUpdates'] ?? json['PaymentUpdates'] ?? true) == true,
      caregiverArriving:
          (json['caregiverArriving'] ?? json['CaregiverArriving'] ?? true) ==
              true,
      scheduleReminder:
          (json['scheduleReminder'] ?? json['ScheduleReminder'] ?? true) ==
              true,
      chatMessage:
          (json['chatMessage'] ?? json['ChatMessage'] ?? true) == true,
      promotion: (json['promotion'] ?? json['Promotion'] ?? false) == true,
    );
  }

  NotificationPrefs copyWith({
    bool? bookingUpdates,
    bool? paymentUpdates,
    bool? caregiverArriving,
    bool? scheduleReminder,
    bool? chatMessage,
    bool? promotion,
  }) =>
      NotificationPrefs(
        bookingUpdates: bookingUpdates ?? this.bookingUpdates,
        paymentUpdates: paymentUpdates ?? this.paymentUpdates,
        caregiverArriving: caregiverArriving ?? this.caregiverArriving,
        scheduleReminder: scheduleReminder ?? this.scheduleReminder,
        chatMessage: chatMessage ?? this.chatMessage,
        promotion: promotion ?? this.promotion,
      );
}

// ── Provider ──────────────────────────────────────────────────────────────────

final notificationPrefsProvider =
    StateNotifierProvider<NotificationPrefsNotifier, AsyncValue<NotificationPrefs>>(
        (ref) => NotificationPrefsNotifier(ref));

class NotificationPrefsNotifier
    extends StateNotifier<AsyncValue<NotificationPrefs>> {
  final Ref _ref;
  Timer? _debounce;

  NotificationPrefsNotifier(this._ref)
      : super(const AsyncLoading()) {
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final dio = _ref.read(dioClientProvider);
      final resp = await dio.get<Map<String, dynamic>>(
          '/profile/notification-preferences');
      if (resp.data != null) {
        state = AsyncData(NotificationPrefs.fromJson(resp.data!));
      } else {
        state = const AsyncData(NotificationPrefs());
      }
    } catch (_) {
      state = const AsyncData(NotificationPrefs()); // fallback to defaults
    }
  }

  void toggle(NotificationPrefs updated) {
    state = AsyncData(updated);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _save(updated));
  }

  Future<void> _save(NotificationPrefs prefs) async {
    try {
      final dio = _ref.read(dioClientProvider);
      await dio.put<void>('/profile/notification-preferences', data: {
        'bookingUpdates': prefs.bookingUpdates,
        'paymentUpdates': prefs.paymentUpdates,
        'caregiverArriving': prefs.caregiverArriving,
        'scheduleReminder': prefs.scheduleReminder,
        'chatMessage': prefs.chatMessage,
        'promotion': prefs.promotion,
      });
    } catch (_) {
      // Lỗi auto-save — không rollback UI (UX tốt hơn)
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(notificationPrefsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cài đặt thông báo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              const Text('Không tải được cài đặt.'),
              TextButton(
                onPressed: () => ref.invalidate(notificationPrefsProvider),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
        data: (prefs) => ListView(
          children: [
            _buildSectionHeader('Đặt lịch & Booking'),
            _buildTile(
              context,
              ref,
              prefs,
              icon: Icons.calendar_today_outlined,
              title: 'Cập nhật booking',
              subtitle: 'Xác nhận, thay đổi, hủy lịch chăm sóc',
              value: prefs.bookingUpdates,
              onChanged: (v) => _toggle(ref, prefs.copyWith(bookingUpdates: v)),
            ),
            _buildTile(
              context,
              ref,
              prefs,
              icon: Icons.payments_outlined,
              title: 'Thông báo thanh toán',
              subtitle: 'Biên lai, hoàn tiền, hóa đơn',
              value: prefs.paymentUpdates,
              onChanged: (v) => _toggle(ref, prefs.copyWith(paymentUpdates: v)),
            ),
            _buildTile(
              context,
              ref,
              prefs,
              icon: Icons.directions_walk_outlined,
              title: 'Caregiver đang đến',
              subtitle: 'Nhắc khi caregiver cách bạn < 15 phút',
              value: prefs.caregiverArriving,
              onChanged: (v) =>
                  _toggle(ref, prefs.copyWith(caregiverArriving: v)),
            ),
            _buildTile(
              context,
              ref,
              prefs,
              icon: Icons.alarm_outlined,
              title: 'Nhắc lịch',
              subtitle: 'Nhắc 1 giờ trước khi lịch bắt đầu',
              value: prefs.scheduleReminder,
              onChanged: (v) =>
                  _toggle(ref, prefs.copyWith(scheduleReminder: v)),
            ),
            const Divider(height: 1),
            _buildSectionHeader('Tin nhắn & Khuyến mãi'),
            _buildTile(
              context,
              ref,
              prefs,
              icon: Icons.chat_bubble_outline,
              title: 'Tin nhắn',
              subtitle: 'Tin nhắn từ caregiver trong lịch',
              value: prefs.chatMessage,
              onChanged: (v) => _toggle(ref, prefs.copyWith(chatMessage: v)),
            ),
            _buildTile(
              context,
              ref,
              prefs,
              icon: Icons.local_offer_outlined,
              title: 'Ưu đãi & Khuyến mãi',
              subtitle: 'Voucher, giảm giá, sự kiện',
              value: prefs.promotion,
              onChanged: (v) => _toggle(ref, prefs.copyWith(promotion: v)),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Thay đổi được tự động lưu. Bạn vẫn có thể nhận thông báo hệ thống bắt buộc (OTP, bảo mật).',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.5),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _toggle(WidgetRef ref, NotificationPrefs updated) {
    ref.read(notificationPrefsProvider.notifier).toggle(updated);
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    WidgetRef ref,
    NotificationPrefs prefs, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      secondary: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: value ? AppColors.primaryLight : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            size: 20, color: value ? AppColors.primary : AppColors.textSecondary),
      ),
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w500, fontSize: 14, color: AppColors.textPrimary)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
    );
  }
}
