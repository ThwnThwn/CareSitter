import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class SupportChatLoading extends StatelessWidget {
  const SupportChatLoading({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Đang tải cuộc trò chuyện',
        child: const ExcludeSemantics(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                _LoadingBubble(alignment: Alignment.centerLeft, width: 220),
                SizedBox(height: AppSpacing.lg),
                _LoadingBubble(alignment: Alignment.centerRight, width: 180),
                SizedBox(height: AppSpacing.lg),
                _LoadingBubble(alignment: Alignment.centerLeft, width: 200),
              ],
            ),
          ),
        ),
      );
}

class _LoadingBubble extends StatelessWidget {
  const _LoadingBubble({required this.alignment, required this.width});
  final Alignment alignment;
  final double width;

  @override
  Widget build(BuildContext context) => Align(
        alignment: alignment,
        child: Container(
          width: width,
          height: AppSpacing.hero,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      );
}
