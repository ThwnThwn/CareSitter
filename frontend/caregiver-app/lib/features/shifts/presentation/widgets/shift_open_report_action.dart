import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:caregiver_app/core/theme/app_theme.dart';

class ShiftOpenReportAction extends StatelessWidget {
  const ShiftOpenReportAction({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        minimum: const EdgeInsets.all(AppSpacing.md),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => context.push('/shifts/$bookingId/summary'),
            child: const Text('Xem tổng kết ca'),
          ),
        ),
      );
}
