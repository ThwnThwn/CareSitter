import 'package:flutter/material.dart';

class HomeHeroTitle extends StatelessWidget {
  const HomeHeroTitle({super.key, required this.isNarrow});
  final bool isNarrow;

  @override
  Widget build(BuildContext context) => Text(
        'Trao gửi yêu thương,\nan tâm mỗi ngày',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: isNarrow ? 20 : 26,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
      );
}
