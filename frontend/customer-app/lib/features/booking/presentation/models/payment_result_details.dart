import 'package:flutter/material.dart';
import 'package:caresitter_customer/features/booking/presentation/models/payment_result_highlight.dart';

class PaymentResultDetails {
  const PaymentResultDetails({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.message,
    required this.label,
    required this.labelColor,
    required this.labelBackground,
    required this.highlights,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String message;
  final String label;
  final Color labelColor;
  final Color labelBackground;
  final List<PaymentResultHighlight> highlights;
}
