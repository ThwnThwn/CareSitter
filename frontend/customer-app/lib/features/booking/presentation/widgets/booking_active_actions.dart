import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BookingActiveActions extends StatelessWidget {
  const BookingActiveActions(
      {super.key, required this.action4, required this.action5});
  final void Function() action4;
  final void Function() action5;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: action4,
              icon: const Icon(Icons.location_on_outlined),
              label: const Text('Theo dõi ca chăm sóc'),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52)),
            ),
            const SizedBox(height: AppSpacing.control),
            OutlinedButton.icon(
              onPressed: action5,
              icon: const Icon(Icons.add_alarm),
              label: const Text('Gia hạn ca chăm sóc'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ]);
}
