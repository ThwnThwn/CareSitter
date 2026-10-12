import 'package:caresitter_customer/features/settings/presentation/widgets/notification_settings_inset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/notification_preferences_controller.dart';

class NotificationSettingsPrefsToggleList extends StatelessWidget {
  const NotificationSettingsPrefsToggleList(
      {super.key,
      required this.buildSectionHeader,
      required this.buildTile,
      required this.ref,
      required this.prefs,
      required this.toggle});
  final Widget Function(String) buildSectionHeader;
  final Widget Function(BuildContext, WidgetRef, NotificationPrefs,
      {required IconData icon,
      required void Function(bool) onChanged,
      required String subtitle,
      required String title,
      required bool value}) buildTile;
  final WidgetRef ref;
  final NotificationPrefs prefs;
  final void Function(WidgetRef, NotificationPrefs) toggle;
  @override
  Widget build(BuildContext context) => ListView(
        children: [
          buildSectionHeader('Đặt lịch & Booking'),
          buildTile(
            context,
            ref,
            prefs,
            icon: Icons.calendar_today_outlined,
            title: 'Cập nhật booking',
            subtitle: 'Xác nhận, thay đổi, hủy lịch chăm sóc',
            value: prefs.bookingUpdates,
            onChanged: (v) => toggle(ref, prefs.copyWith(bookingUpdates: v)),
          ),
          buildTile(
            context,
            ref,
            prefs,
            icon: Icons.payments_outlined,
            title: 'Thông báo thanh toán',
            subtitle: 'Biên lai, hoàn tiền, hóa đơn',
            value: prefs.paymentUpdates,
            onChanged: (v) => toggle(ref, prefs.copyWith(paymentUpdates: v)),
          ),
          buildTile(
            context,
            ref,
            prefs,
            icon: Icons.directions_walk_outlined,
            title: 'Caregiver đang đến',
            subtitle: 'Nhắc khi caregiver cách bạn < 15 phút',
            value: prefs.caregiverArriving,
            onChanged: (v) => toggle(ref, prefs.copyWith(caregiverArriving: v)),
          ),
          buildTile(
            context,
            ref,
            prefs,
            icon: Icons.alarm_outlined,
            title: 'Nhắc lịch',
            subtitle: 'Nhắc 1 giờ trước khi lịch bắt đầu',
            value: prefs.scheduleReminder,
            onChanged: (v) => toggle(ref, prefs.copyWith(scheduleReminder: v)),
          ),
          const Divider(height: 1),
          buildSectionHeader('Tin nhắn & Khuyến mãi'),
          buildTile(
            context,
            ref,
            prefs,
            icon: Icons.chat_bubble_outline,
            title: 'Tin nhắn',
            subtitle: 'Tin nhắn từ caregiver trong lịch',
            value: prefs.chatMessage,
            onChanged: (v) => toggle(ref, prefs.copyWith(chatMessage: v)),
          ),
          buildTile(
            context,
            ref,
            prefs,
            icon: Icons.local_offer_outlined,
            title: 'Ưu đãi & Khuyến mãi',
            subtitle: 'Voucher, giảm giá, sự kiện',
            value: prefs.promotion,
            onChanged: (v) => toggle(ref, prefs.copyWith(promotion: v)),
          ),
          const SizedBox(height: AppSpacing.lg),
          const NotificationSettingsInset(),
          const SizedBox(height: AppSpacing.xl),
        ],
      );
}
