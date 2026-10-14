import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/data/models/booking_model.dart';
import 'shift_extension_form.dart';

Future<void> showShiftExtensionSheet(
    BuildContext context, BookingModel booking) async {
  final contactSupport = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
    builder: (_) => ShiftExtensionSheet(booking: booking),
  );
  if (contactSupport == true && context.mounted) {
    context.push('/settings/support');
  }
}

class ShiftExtensionSheet extends StatefulWidget {
  const ShiftExtensionSheet({super.key, required this.booking});
  final BookingModel booking;

  @override
  State<ShiftExtensionSheet> createState() => _ShiftExtensionSheetState();
}

class _ShiftExtensionSheetState extends State<ShiftExtensionSheet> {
  int _hours = 1;

  @override
  Widget build(BuildContext context) {
    final bookedHours = widget.booking.scheduledEnd
            .difference(widget.booking.scheduledStart)
            .inMinutes /
        60;
    final rate =
        bookedHours > 0 ? widget.booking.escrowAmount / bookedHours : 0.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.section, AppSpacing.section,
          AppSpacing.section, 32 + MediaQuery.viewInsetsOf(context).bottom),
      child: ShiftExtensionForm(
        selectedHours: _hours,
        effectiveHourlyRate: rate,
        onDecrease: () => setState(() => _hours--),
        onIncrease: () => setState(() => _hours++),
        onContactSupport: () => Navigator.pop(context, true),
      ),
    );
  }
}
