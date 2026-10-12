import 'package:flutter/material.dart';

class HomeHeroDescription extends StatelessWidget {
  const HomeHeroDescription({super.key, required this.isNarrow});
  final bool isNarrow;

  @override
  Widget build(BuildContext context) => Text(
        'Người bạn đồng hành tận tâm hỗ trợ sinh hoạt, trò chuyện & chăm sóc Cha Mẹ chu đáo khi bạn bận rộn.',
        maxLines: isNarrow ? 3 : 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: isNarrow ? 10.5 : 13,
          height: isNarrow ? 1.4 : 1.5,
        ),
      );
}
