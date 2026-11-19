import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class NotificationInboxLoading extends StatelessWidget {
  const NotificationInboxLoading({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Đang tải thông báo',
        liveRegion: true,
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, __) => Container(
            height: 96,
            padding: const EdgeInsets.all(AppSpacing.compact),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                    radius: 21, backgroundColor: AppColors.primaryContainer),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FractionallySizedBox(
                        widthFactor: .48,
                        child: ColoredBox(
                          color: AppColors.primaryContainer,
                          child: SizedBox(height: 12),
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      FractionallySizedBox(
                        widthFactor: .8,
                        child: ColoredBox(
                          color: AppColors.background,
                          child: SizedBox(height: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
