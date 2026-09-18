import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:caregiver_app/core/theme/shift_status_style.dart';

class ShiftStatusBadge extends StatelessWidget {
  final String status;

  const ShiftStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final style = ShiftStatusStyle.of(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        style.label,
        style: GoogleFonts.beVietnamPro(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: style.color,
        ),
      ),
    );
  }
}
