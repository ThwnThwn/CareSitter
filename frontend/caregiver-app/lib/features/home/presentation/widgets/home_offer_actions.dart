import 'package:caregiver_app/features/home/presentation/widgets/home_offer_decline_action.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_offer_accept_action.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class HomeOfferActions extends StatelessWidget {
  const HomeOfferActions(
      {super.key,
      required this.isExpired,
      required this.isProcessing,
      required this.onDecline,
      required this.onAccept});
  final bool isExpired;
  final bool isProcessing;
  final Future<void> Function() onDecline, onAccept;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          HomeOfferDeclineAction(
              isExpired: isExpired,
              isProcessing: isProcessing,
              onDecline: onDecline),
          const SizedBox(width: AppSpacing.compact),
          HomeOfferAcceptAction(
              isExpired: isExpired,
              isProcessing: isProcessing,
              onAccept: onAccept),
        ],
      );
}
