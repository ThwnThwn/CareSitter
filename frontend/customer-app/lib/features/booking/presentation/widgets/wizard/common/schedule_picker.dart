import 'package:caresitter_customer/core/utils/date_formatter.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../controllers/booking_wizard_controller.dart';
import '../../../controllers/booking_wizard_state.dart';
import '../../../controllers/booking_wizard_selectors.dart';

/// SchedulePicker theo Stitch design:
/// Card trắng bo 18px, icon trong khung màu, label uppercase, chevron right.
class SchedulePicker extends ConsumerWidget {
  const SchedulePicker({super.key, required this.args});
  final BookingWizardArgs args;

  Future<void> _date(BuildContext context, WidgetRef ref) async {
    final selected = ref.read(bookingWizardProvider(args)).date;
    final now = DateTime.now();
    final value = await showDatePicker(
        context: context,
        initialDate: selected ?? now,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: now.add(const Duration(days: 90)));
    if (context.mounted && value != null) {
      ref.read(bookingWizardProvider(args).notifier).selectDate(value);
    }
  }

  Future<void> _time(BuildContext context, WidgetRef ref) async {
    final selected =
        ref.read(bookingWizardProvider(args)).startMinutes ?? 480;
    final value = await showTimePicker(
        context: context,
        initialTime:
            TimeOfDay(hour: selected ~/ 60, minute: selected % 60));
    if (context.mounted && value != null) {
      ref
          .read(bookingWizardProvider(args).notifier)
          .selectTime(value.hour * 60 + value.minute);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(
        bookingWizardProvider(args).select((s) => (s.date, s.startMinutes)));
    final date = choice.$1, minutes = choice.$2;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Section header
      Text(
        'Chọn thời gian',
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      ),
      const SizedBox(height: 2),
      Text(
        'Chọn ngày và giờ bắt đầu ca chăm sóc',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: AppSpacing.md),
      // Ngày chăm sóc card
      _SchedulePickerCard(
        onTap: () => _date(context, ref),
        selected: date != null,
        iconBg: const Color(0xFFECFDF5),
        iconColor: AppColors.primary,
        icon: Icons.calendar_today_rounded,
        label: 'NGÀY CHĂM SÓC',
        value: date == null ? 'Chọn ngày' : formatDate(date),
        hasValue: date != null,
      ),
      const SizedBox(height: AppSpacing.control),
      // Giờ bắt đầu card
      _SchedulePickerCard(
        onTap: date == null ? null : () => _time(context, ref),
        selected: minutes != null,
        iconBg: const Color(0xFFFFFBEB),
        iconColor: const Color(0xFFB45309),
        icon: Icons.access_time_rounded,
        label: 'GIỜ BẮT ĐẦU',
        value: minutes == null
            ? (date == null ? 'Chọn ngày trước' : 'Chọn giờ bắt đầu')
            : TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60)
                .format(context),
        hasValue: minutes != null,
      ),
      if (date != null &&
          minutes != null &&
          !ref.watch(wizardScheduleValidProvider(args)))
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.compact),
          child: Text(
            'Thời gian bắt đầu phải sau hiện tại ít nhất 30 phút.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.error),
          ),
        ),
    ]);
  }
}

class _SchedulePickerCard extends StatelessWidget {
  const _SchedulePickerCard({
    required this.onTap,
    required this.selected,
    required this.iconBg,
    required this.iconColor,
    required this.icon,
    required this.label,
    required this.value,
    required this.hasValue,
  });

  final VoidCallback? onTap;
  final bool selected;
  final Color iconBg;
  final Color iconColor;
  final IconData icon;
  final String label;
  final String value;
  final bool hasValue;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(AppRadius.card),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.inset,
            vertical: AppSpacing.md,
          ),
          child: Row(children: [
            // Icon container
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: AppSpacing.compact),
            // Label + value
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textHint,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: hasValue
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            // Chevron
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textHint,
              size: 20,
            ),
          ]),
        ),
      ),
    );
  }
}
