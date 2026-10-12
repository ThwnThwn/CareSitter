import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class HomeHeroCaregiverCount extends StatelessWidget {
  const HomeHeroCaregiverCount({super.key, required this.isNarrow});
  final bool isNarrow;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Hơn 250+ điều dưỡng & hộ lý\ncao tuổi sẵn sàng',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: isNarrow ? 10 : 12,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
}
