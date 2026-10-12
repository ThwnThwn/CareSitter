import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import '../../data/models/notification_preferences.dart';
import 'notification_settings_inset.dart';

class NotificationSettingsPrefsToggleList extends StatelessWidget {
  const NotificationSettingsPrefsToggleList(
      {super.key, required this.prefs, required this.onChanged});
  final NotificationPrefs prefs;
  final ValueChanged<NotificationPrefs> onChanged;

  @override
  Widget build(BuildContext context) => ListView(children: [
        const _SectionTitle('Đặt lịch & Booking'),
        _PreferenceTile(
            icon: Icons.calendar_today_outlined,
            title: 'Cập nhật booking',
            subtitle: 'Xác nhận, thay đổi, hủy lịch chăm sóc',
            value: prefs.bookingUpdates,
            onChanged: (value) => onChanged(prefs.copyWith(bookingUpdates: value))),
        _PreferenceTile(
            icon: Icons.payments_outlined,
            title: 'Thông báo thanh toán',
            subtitle: 'Biên lai, hoàn tiền, hóa đơn',
            value: prefs.paymentUpdates,
            onChanged: (value) => onChanged(prefs.copyWith(paymentUpdates: value))),
        _PreferenceTile(
            icon: Icons.directions_walk_outlined,
            title: 'Caregiver đang đến',
            subtitle: 'Nhắc khi caregiver cách bạn < 15 phút',
            value: prefs.caregiverArriving,
            onChanged: (value) =>
                onChanged(prefs.copyWith(caregiverArriving: value))),
        _PreferenceTile(
            icon: Icons.alarm_outlined,
            title: 'Nhắc lịch',
            subtitle: 'Nhắc 1 giờ trước khi lịch bắt đầu',
            value: prefs.scheduleReminder,
            onChanged: (value) =>
                onChanged(prefs.copyWith(scheduleReminder: value))),
        const Divider(height: 1),
        const _SectionTitle('Tin nhắn & Khuyến mãi'),
        _PreferenceTile(
            icon: Icons.chat_bubble_outline,
            title: 'Tin nhắn',
            subtitle: 'Tin nhắn từ caregiver trong lịch',
            value: prefs.chatMessage,
            onChanged: (value) => onChanged(prefs.copyWith(chatMessage: value))),
        _PreferenceTile(
            icon: Icons.local_offer_outlined,
            title: 'Ưu đãi & Khuyến mãi',
            subtitle: 'Voucher, giảm giá, sự kiện',
            value: prefs.promotion,
            onChanged: (value) => onChanged(prefs.copyWith(promotion: value))),
        const SizedBox(height: AppSpacing.lg),
        const NotificationSettingsInset(),
        const SizedBox(height: AppSpacing.xl),
      ]);
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.section, AppSpacing.md, AppSpacing.xs),
        child: Text(title,
            style: const TextStyle(
                fontSize: AppFontSizes.s12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 0.5)),
      );
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.value,
      required this.onChanged});
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
        secondary: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: value ? AppColors.primaryContainer : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.compact)),
            child: Icon(icon,
                size: 20,
                color: value ? AppColors.primary : AppColors.textSecondary)),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: AppFontSizes.s14,
                color: AppColors.textPrimary)),
        subtitle: Text(subtitle,
            style: const TextStyle(
                fontSize: AppFontSizes.s12, color: AppColors.textSecondary)),
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
      );
}
