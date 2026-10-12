import 'package:flutter/material.dart';

class BookingListBookingCardBorderColorContent extends StatelessWidget {
  const BookingListBookingCardBorderColorContent(
      {super.key, required this.borderColor});
  final Color borderColor;

  @override
  Widget build(BuildContext context) => Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        child: Container(
          width: 4,
          decoration: BoxDecoration(
            color: borderColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              bottomLeft: Radius.circular(18),
            ),
          ),
        ),
      );
}
