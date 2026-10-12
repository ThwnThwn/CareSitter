import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ShiftCardOfferActions extends StatelessWidget {
  const ShiftCardOfferActions(
      {super.key, required this.onViewOffer, required this.callbackAction1});
  final void Function()? onViewOffer;
  final Future<void> Function() callbackAction1;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: callbackAction1,
              child: const Text('Từ chối'),
            ),
          ),
          const SizedBox(width: AppSpacing.compact),
          Expanded(
            child: ElevatedButton(
              onPressed: onViewOffer,
              child: const Text('Xem & Nhận ca'),
            ),
          ),
        ],
      );
}
