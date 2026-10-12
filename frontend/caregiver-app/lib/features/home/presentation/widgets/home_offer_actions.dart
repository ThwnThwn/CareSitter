import 'package:caregiver_app/features/home/presentation/widgets/home_offer_decline_action.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_offer_accept_action.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';

class HomeOfferActions extends StatelessWidget {
  const HomeOfferActions(
      {super.key,
      required this.isExpired,
      required this.isProcessing,
      required this.runOfferAction,
      required this.booking,
      required this.callbackAction2,
      required this.callbackAction3});
  final bool isExpired;
  final bool isProcessing;
  final Future<void> Function(BuildContext, String,
      {required Future<void> Function() action,
      required String successMessage}) runOfferAction;
  final ShiftModel booking;
  final Future<void> Function() callbackAction2;
  final Future<void> Function() callbackAction3;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          HomeOfferDeclineAction(
              isExpired: isExpired,
              isProcessing: isProcessing,
              callbackAction1: callbackAction2),
          const SizedBox(width: AppSpacing.compact),
          HomeOfferAcceptAction(
              isExpired: isExpired,
              isProcessing: isProcessing,
              runOfferAction: runOfferAction,
              booking: booking,
              callbackAction1: callbackAction3),
        ],
      );
}
