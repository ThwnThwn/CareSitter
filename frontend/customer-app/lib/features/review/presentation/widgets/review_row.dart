import 'package:flutter/material.dart';

class ReviewRow extends StatelessWidget {
  const ReviewRow({super.key, required this.action1});
  final GestureDetector Function(int) action1;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, action1),
      );
}
